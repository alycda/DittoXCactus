import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import '../models/study_note.dart';
import '../prompts/flashcard_gen.dart';
import 'cactus_service.dart';
import 'ditto_service.dart';

/// A scored retrieval result: a study note and its cosine similarity vs the
/// query topic.
class RetrievedNote {
  final StudyNote note;
  final double score;

  const RetrievedNote(this.note, this.score);
}

/// Discriminated union over the events the flashcard pipeline can emit.
/// U8 listens on this stream to render the loading state and the final stack.
class FlashcardEvent {
  final List<RetrievedNote>? retrieved;
  final String? partial;
  final List<Flashcard>? cards;
  final bool isDone;

  const FlashcardEvent._({
    this.retrieved,
    this.partial,
    this.cards,
    this.isDone = false,
  });

  const FlashcardEvent.retrieved(List<RetrievedNote> r) : this._(retrieved: r);
  const FlashcardEvent.partial(String chunk) : this._(partial: chunk);
  const FlashcardEvent.cards(List<Flashcard> c) : this._(cards: c);
  const FlashcardEvent.done() : this._(isDone: true);
}

/// Cosine top-k over a flat float32 array materialized from Ditto. Stage 0 is
/// brute-force on purpose: ≤5k notes × 384 dims = 7.7 MB, so exact-recall
/// brute force is sub-millisecond and the CRDT-merged note set has no index
/// state to keep in sync.
class RetrievalService {
  RetrievalService._();
  static final RetrievalService instance = RetrievalService._();

  /// Default k for Stage 0; the flashcard prompt expects ~3-5 notes.
  static const int defaultK = 5;

  /// Default number of flashcards to generate per request. Tuned down from
  /// 5 to 3 because 1.5B Qwen on a Pixel 6a in debug mode decodes at ~6
  /// chars/s; 3 cards in Q/A line format fit in ~25 lines and decode in
  /// roughly half the time 5 JSON cards took.
  static const int defaultN = 3;

  /// Token budget per card. Q/A plain-text format is more compact than the
  /// old JSON shape, so 160 tokens covers a reasonable Q + A + NOTES block.
  /// Add a reasoning-leak slush so `<think>` blocks (Qwen 2.5 emits them
  /// despite the `/no_think` directive being Qwen3-only) don't starve the
  /// real output of tokens. Total = thinkBudget + n × maxTokensPerCard.
  static const int maxTokensPerCard = 160;
  static const int thinkBudget = 512;

  /// Encode a study note as the short text we hand to `cactus_embed`.
  /// Keeps it short on purpose — embedding context budgets are tight, and
  /// the topic + first 200 chars of body is enough signal for cosine.
  String _noteText(StudyNote n) {
    final body = n.body.length > 200 ? n.body.substring(0, 200) : n.body;
    return '${n.topic}. $body';
  }

  /// Embed missing rows and persist the embedding column back to Ditto.
  /// Idempotent: rows that already have a non-empty embedding are skipped.
  /// Returns the number of rows newly embedded.
  Future<int> ensureEmbeddings() async {
    final missing = await DittoService.instance.queryMissingEmbedding();
    var n = 0;
    for (final note in missing) {
      final emb = await CactusService.instance.embed(_noteText(note));
      await DittoService.instance.setEmbedding(note.id, emb);
      n++;
    }
    return n;
  }

  /// Convenience wrapper around `CactusService.embed` that returns a
  /// `Float32List` ready for the cosine loop.
  Future<Float32List> embedQuery(String query) async {
    final raw = await CactusService.instance.embed(query);
    return Float32List.fromList(raw.map((d) => d.toDouble()).toList());
  }

  /// Compute cosine-top-k over the embedded corpus. Returns up to `k`
  /// `RetrievedNote`s in descending score order.
  ///
  /// Cactus output is typically L2-normalized; we still normalize on both
  /// sides so the score stays in [-1, 1] regardless of model quirks.
  Future<List<RetrievedNote>> topK(String topic, {int k = defaultK}) async {
    final qVec = normalize(await embedQuery(topic));
    final corpus = await DittoService.instance.queryWithEmbedding();
    if (corpus.isEmpty) return const [];

    final scored = <RetrievedNote>[];
    for (final note in corpus) {
      final docVec = normalize(Float32List.fromList(note.embedding.map((d) => d.toDouble()).toList()));
      if (docVec.length != qVec.length) continue;
      scored.add(RetrievedNote(note, dot(qVec, docVec)));
    }

    scored.sort((a, b) {
      final s = b.score.compareTo(a.score);
      return s != 0 ? s : a.note.id.compareTo(b.note.id); // tie-break by _id
    });
    return scored.take(k).toList();
  }

  /// End-to-end flashcard pipeline: embed topic → top-k notes → prompt →
  /// streaming completion → parse JSON → emit cards. Yields the top-k
  /// retrieval marker first (so U8 can render the attribution footer
  /// while the LLM is still streaming), then per-chunk partial markers
  /// (for a "generating…" indicator), then the parsed cards on completion.
  Stream<FlashcardEvent> generateFlashcards(
    String topic, {
    int k = defaultK,
    int n = defaultN,
    List<Flashcard> savedExamples = const [],
  }) async* {
    final retrieved = await topK(topic, k: k);
    yield FlashcardEvent.retrieved(retrieved);
    debugPrint(
      '[flashcards] topic="$topic" n=$n k=$k retrieved=${retrieved.length} '
      'maxTokens=${maxTokensPerCard * n}',
    );

    final messages = FlashcardGenPrompt.build(
      topic: topic,
      n: n,
      retrieved: retrieved,
    );
    final buffer = StringBuffer();
    var chunkCount = 0;
    final decodeStart = DateTime.now();
    await for (final chunk in CactusService.instance.complete(
      messages,
      maxTokens: thinkBudget + maxTokensPerCard * n,
    )) {
      buffer.write(chunk);
      chunkCount++;
      // Heartbeat every 32 chunks so a stuck decode is obvious in the log.
      if (chunkCount % 32 == 0) {
        final elapsed = DateTime.now().difference(decodeStart).inSeconds;
        debugPrint(
          '[flashcards] decode tick: $chunkCount chunks, '
          '${buffer.length} chars, ${elapsed}s elapsed',
        );
      }
      yield FlashcardEvent.partial(chunk);
    }
    final raw = buffer.toString();
    final elapsedSec = DateTime.now().difference(decodeStart).inSeconds;
    debugPrint(
      '[flashcards] decode done: $chunkCount chunks, '
      '${raw.length} chars, ${elapsedSec}s',
    );
    debugPrint(
      '[flashcards] === raw completion (${raw.length} chars) ===\n'
      '$raw\n'
      '[flashcards] === end raw completion ===',
    );

    final cards = FlashcardGenPrompt.parse(raw);
    debugPrint('[flashcards] parsed ${cards.length} card(s)');
    yield FlashcardEvent.cards(cards);
    yield const FlashcardEvent.done();
  }

  // ---------------------------------------------------------------------------
  // pure-math helpers — tested in retrieval_service_test.dart

  static Float32List normalize(Float32List v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final n = math.sqrt(sum);
    if (n == 0) return v;
    final out = Float32List(v.length);
    for (var i = 0; i < v.length; i++) {
      out[i] = v[i] / n;
    }
    return out;
  }

  static double dot(Float32List a, Float32List b) {
    var s = 0.0;
    for (var i = 0; i < a.length; i++) {
      s += a[i] * b[i];
    }
    return s;
  }
}
