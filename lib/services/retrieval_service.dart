/// Singleton owning the retrieval hot path: backfill embeddings, embed a
/// query, brute-force cosine top-k over the materialized Ditto snapshot,
/// and (in Stage 1) stream flashcard generation.
///
/// The retrieval design is deliberately minimal — the U9 spec hangs three
/// loud commitments on it:
///
/// 1. **Pure function over the CRDT-merged set (R9).** `topK` materializes
///    the full `notes` collection on each call, normalizes, and ranks.
///    No persisted index, no cached `Float32List`. The mesh-RAG thesis
///    rides on this — `topK(corpus_A ∪ corpus_B)` produces the same result
///    regardless of which device runs it, because the union is associative
///    and retrieval has no hidden state. Future revisions can hang an
///    observer-cached buffer in front when the corpus grows past ~5k rows.
///
/// 2. **Deterministic tie-break (R2 / R3).** `(score desc, _id asc)`.
///    UUIDv5 strings sort lex-asc — U7's namespace pin makes that
///    bitwise-stable across devices. Already-verified property at the
///    determinism-harness level (U1); re-asserted here.
///
/// 3. **Mid-corpus model swap is contained at the query boundary.** Notes
///    whose `embedding.length` differs from the current query embedding
///    are silently dropped from `topK`. A backfill doesn't re-embed
///    non-empty embeddings, so a stale-length row survives until the
///    embedding column is explicitly cleared (planned for a future
///    cleanup-on-startup pass, out of scope for Stage 0).
library mesh_rag.services.retrieval_service;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/study_note.dart';
import 'cactus_service.dart';
import 'ditto_service.dart';

/// One ranked retrieval result.
class RetrievedNote {
  final StudyNote note;
  final double score;
  const RetrievedNote({required this.note, required this.score});

  @override
  String toString() =>
      'RetrievedNote(${note.id} ${note.topic} score=${score.toStringAsFixed(4)})';
}

/// A single parsed Q/A flashcard with source attribution.
///
/// U11 enriches the authoring path (`FlashcardGenPrompt` + parser); this
/// data class is the contract both U9 (which emits `FlashcardEvent.cards`)
/// and U10 (which renders the swipeable stack) agree on. Pinning the
/// shape here means U11 can land its parser without re-routing the type
/// across services.
class Flashcard {
  final String question;
  final String answer;
  final List<String> sourceNoteIds;
  const Flashcard({
    required this.question,
    required this.answer,
    required this.sourceNoteIds,
  });
}

/// Discriminated stream of events produced by [RetrievalService.generateFlashcards].
///
/// Sealed so `switch` exhaustiveness is enforced at the call site — adding
/// a new event variant requires updating every consumer.
sealed class FlashcardEvent {
  const FlashcardEvent();
}

/// Top-k retrieval has run; downstream UI can show the cited note ids
/// even before the LLM stream starts.
class FlashcardEventRetrieved extends FlashcardEvent {
  final List<RetrievedNote> retrieved;
  const FlashcardEventRetrieved(this.retrieved);
}

/// A streaming token chunk from Cactus' `complete` stream. Concatenate
/// across events to reconstruct the raw LLM output for parsing.
class FlashcardEventPartial extends FlashcardEvent {
  final String chunk;
  const FlashcardEventPartial(this.chunk);
}

/// All cards parsed for this generation. Fires once at end-of-stream.
class FlashcardEventCards extends FlashcardEvent {
  final List<Flashcard> cards;
  const FlashcardEventCards(this.cards);
}

/// Stream terminator. Lets the UI commit "generating finished" state
/// independent of how many cards came through.
class FlashcardEventDone extends FlashcardEvent {
  const FlashcardEventDone();
}

class RetrievalService {
  RetrievalService._();
  static final RetrievalService instance = RetrievalService._();

  /// Top-k default — small enough to fit comfortably in U6's 2048 context
  /// window with the U3 corpus body lengths.
  static const int defaultK = 5;

  /// Flashcard-count default. U11 §Approach: 3 cards halves wall-clock
  /// vs. 5 on the slowest target (Pixel 6a debug, ~6 chars/s decode).
  static const int defaultN = 3;

  // ───── ensureEmbeddings (U8's phase-2) ────────────────────────────────

  /// Backfill embeddings for every note with `embedding.isEmpty`. Returns
  /// the count actually embedded — `0` on subsequent boots (the property
  /// that lets U8's preload survive force-close + relaunch without
  /// re-embedding).
  ///
  /// `onProgress(int done, int total)` (if supplied) fires per-note so
  /// `BootScreen` can render `'embedded 3/5 notes'` during the cold load.
  Future<int> ensureEmbeddings({
    void Function(int done, int total)? onProgress,
  }) async {
    final missing = await DittoService.instance.queryMissingEmbedding();
    final total = missing.length;
    var done = 0;
    onProgress?.call(0, total);
    for (final note in missing) {
      final text = _embeddingInputFor(note);
      final embedding = await CactusService.instance.embed(text);
      await DittoService.instance.setEmbedding(note.id, embedding);
      done++;
      onProgress?.call(done, total);
    }
    return done;
  }

  /// Build the embedding input from a note. Combine topic + first ~200
  /// chars of the body — picks up the topical hook plus the most
  /// information-dense leading sentence. Mirrors U8's documented prompt
  /// shape.
  static String _embeddingInputFor(StudyNote note) {
    final body = note.body;
    final preview =
        body.length > 200 ? body.substring(0, 200) : body;
    return '${note.topic}. $preview';
  }

  // ───── embedQuery + topK ──────────────────────────────────────────────

  /// Embed a free-text query as `Float32List`.
  Future<Float32List> embedQuery(String query) async {
    return CactusService.instance.embedF32(query);
  }

  /// Brute-force cosine top-k over the materialized Ditto corpus.
  ///
  /// Re-runs the DQL `SELECT * FROM notes` on every call (acceptable at
  /// Stage 0's ≤10 rows; future-work cache on observer).
  Future<List<RetrievedNote>> topK(String topic, {int k = defaultK}) async {
    if (topic.isEmpty) return const [];
    final qVecRaw = await embedQuery(topic);
    final qVec = normalize(qVecRaw);
    final notes = await DittoService.instance.queryWithEmbedding();
    return rankTopK(queryVec: qVec, notes: notes, k: k);
  }

  /// Pure-math top-k. Testable directly — the math is the part that has
  /// to be right; the I/O wrapper around it is mechanical. Tie-break:
  /// `(score desc, id asc)` — UUIDv5 strings sort lex-asc → R2 stable.
  ///
  /// Notes whose embedding-length differs from `queryVec.length` are
  /// silently dropped (mid-corpus model swap guard).
  @visibleForTesting
  static List<RetrievedNote> rankTopK({
    required Float32List queryVec,
    required List<StudyNote> notes,
    required int k,
  }) {
    final scored = <RetrievedNote>[];
    for (final note in notes) {
      if (note.embedding.length != queryVec.length) continue;
      final docVec = normalize(Float32List.fromList(note.embedding));
      final score = dot(queryVec, docVec);
      scored.add(RetrievedNote(note: note, score: score));
    }
    scored.sort((a, b) {
      final c = b.score.compareTo(a.score); // desc
      if (c != 0) return c;
      return a.note.id.compareTo(b.note.id); // asc (lex-stable UUIDv5)
    });
    if (scored.length > k) scored.length = k;
    return scored;
  }

  // ───── generateFlashcards stub — U11 lands the body ───────────────────

  /// Stream the flashcard generation for `topic`. U9 lands the API shape
  /// + retrieval phase so U10's `FlashcardsTab` can build against a
  /// concrete stream type; U11 lands the prompt assembly, Cactus
  /// streaming call, and the tolerant parser.
  Stream<FlashcardEvent> generateFlashcards(
    String topic, {
    int k = defaultK,
    int n = defaultN,
    List<Flashcard> savedExamples = const [],
  }) async* {
    final retrieved = await topK(topic, k: k);
    yield FlashcardEventRetrieved(retrieved);
    // TODO(U11): build FlashcardGenPrompt, stream CactusService.complete,
    // emit FlashcardEventPartial(chunk) per chunk, then parse the joined
    // text on stream end and emit FlashcardEventCards(cards).
    yield const FlashcardEventDone();
  }

  // ───── Pure-math helpers (static, tested directly) ────────────────────

  /// L2-normalize. Returns the input unchanged on the zero vector — "no
  /// direction" is treated as "leave it alone" rather than producing
  /// NaNs that would poison cosine scoring.
  static Float32List normalize(Float32List v) {
    var sumSq = 0.0;
    for (var i = 0; i < v.length; i++) {
      sumSq += v[i] * v[i];
    }
    final norm = math.sqrt(sumSq);
    if (norm == 0.0) return v;
    final out = Float32List(v.length);
    for (var i = 0; i < v.length; i++) {
      out[i] = v[i] / norm;
    }
    return out;
  }

  /// Dot product. Asserts equal-length in debug; production callers
  /// guard length matching at the [rankTopK] boundary so the production
  /// path never reaches a mismatch.
  static double dot(Float32List a, Float32List b) {
    assert(a.length == b.length,
        'dot: length mismatch (${a.length} vs ${b.length})');
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }
}
