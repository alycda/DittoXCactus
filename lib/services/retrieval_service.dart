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

import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;

import '../models/study_note.dart';
import '../prompts/flashcard_gen.dart';
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

  /// Token slush reserved for Qwen 2.5's `<think>` chain-of-thought leak.
  /// `/no_think` is Qwen3-only — we can't silence it at the model, so
  /// the parser strips it and the token budget pre-allocates space so
  /// the visible cards don't get starved.
  static const int _kThinkBudget = 512;

  /// Per-card token allowance. The Q + A + SOURCE lines average ~100
  /// tokens; 220 leaves a margin for verbose answers, the trailing
  /// blank-line separator the model emits between cards, AND a margin
  /// for the model overshooting the "under 30 words" rule by 40-60%.
  ///
  /// **Experiment 2026-05-25:** bumped 160 → 220 to address the
  /// atmosphere dry-run where the model produced only 1 of 2 requested
  /// cards because a verbose Venus answer ate the full budget before
  /// Mercury could be generated. Alternative experiment in the sibling
  /// commit tightens the prompt instead — keep whichever produces more
  /// usable cards on-device.
  static const int _kMaxTokensPerCard = 220;

  /// Minimum cosine similarity for a note to count as a retrieved
  /// result. Notes scoring below this are dropped from `topK` even if
  /// fewer than k notes remain.
  ///
  /// Why: with no threshold, `topK` always returns up to k notes
  /// regardless of how poorly they match. On phone-a with 5
  /// inner-planet notes and a "Saturn" query, all 5 come back at low
  /// scores (~0.1-0.25). The LLM then tries to make Saturn cards
  /// from Mercury/Venus notes, can't, and burns the entire token
  /// budget reasoning. The right gate is here: weak retrievals →
  /// empty result → grounding gate fires → LLM never called → UI
  /// shows "no notes match this topic" within milliseconds instead
  /// of ~10s.
  ///
  /// **Default is a rough guess (0.3).** Empirical tuning against
  /// real on-device cosine traces from the demo corpus is queued —
  /// see `_docs/dry-run-findings.md`. Too high gates legitimate
  /// semantic matches (e.g. "what has rings?" → Saturn); too low
  /// lets garbage through (today's failure mode). 0.3 is a starting
  /// point; bump up if Saturn-on-phone-a still gets through.
  static const double defaultMinScore = 0.3;

  // ───── Entity-overlap grounding (paired with the cosine threshold) ───
  //
  // Cosine is the topical filter (drops weak retrievals).
  // Entity overlap is the hallucination backstop (catches the case where
  // cosine lies — e.g. Jupiter notes scoring high for a Saturn query
  // because the embedding model thinks "outer planet" is close enough).
  //
  // The two gates fail in different ways, so running them in series
  // catches strictly more than either alone:
  //
  //   topK applies cosine (semantic similarity)
  //   filterByEntityMention then drops anything that doesn't actually
  //   mention the topic anywhere in topic/body/tags
  //
  // The check is intentionally a lowercase substring scan, not full NER.
  // Stage 0/1 demo queries are single-topic ("Saturn", "Jupiter") so the
  // free-tier match works directly on the structured `topic` field
  // before any LLM is involved. For compositional queries ("compare
  // Saturn and Jupiter") a future revision would want token-level NER +
  // per-entity coverage; flag with a TODO if that surface ever lands.

  /// True iff `topic` appears (case-insensitively) anywhere in this
  /// note's structured surface: `topic`, `body`, or any `tag`.
  ///
  /// Used as the grounding-gate-side companion to [defaultMinScore]:
  /// `topK` first drops weak cosines, then `filterByEntityMention`
  /// drops semantically-similar-but-wrong-entity matches.
  ///
  /// Empty `topic` returns true — defer to cosine alone for the
  /// degenerate "no query" case rather than refusing everything.
  @visibleForTesting
  static bool mentionsEntity(StudyNote note, String topic) {
    if (topic.isEmpty) return true;
    final needle = topic.toLowerCase();
    if (note.topic.toLowerCase().contains(needle)) return true;
    if (note.body.toLowerCase().contains(needle)) return true;
    for (final tag in note.tags) {
      if (tag.toLowerCase().contains(needle)) return true;
    }
    return false;
  }

  /// Returns the input list filtered to retrievals whose underlying note
  /// passes [mentionsEntity] for `topic`. Order is preserved so the
  /// caller still gets cosine-rank ordering.
  ///
  /// Empty `topic` returns the input unchanged (see [mentionsEntity]).
  @visibleForTesting
  static List<RetrievedNote> filterByEntityMention(
    List<RetrievedNote> retrieved,
    String topic,
  ) {
    if (topic.isEmpty) return retrieved;
    return retrieved.where((r) => mentionsEntity(r.note, topic)).toList();
  }

  // ───── Generation-side contract enforcement ──────────────────────────
  //
  // The prompt asks for exactly N flashcards, each on-topic, each with
  // a SOURCE: line. A small model can produce drafts that don't match
  // that contract — duplicated cards across multiple "Final Answer"
  // sections, uncited claims inside reasoning prose, verbose drift
  // past N, off-topic facts when retrieval is thin, AND answers that
  // leak reasoning into the A field ("Mars has two smallest moons;
  // Phoebus (or Phoebus)... Wait but original note says 'Phobos'...").
  //
  // cleanCards is the post-parse cleanup pipeline. Six stages, run in
  // this order:
  //   1. On-topic — card's Q or A must mention `topic` as a substring
  //      (case-insensitive). Drops the off-topic fact-padding case.
  //   2. Reasoning-leak — drop cards whose A contains markers like
  //      "Wait,", "Hmm,", "Actually,", "Let me check", "perhaps i",
  //      "but maybe". These are dead giveaways the model is reasoning
  //      in the answer field instead of stating an answer.
  //   3. Answer-length — drop cards whose A is longer than
  //      [_kMaxAnswerChars]. Real flashcard answers are one sentence
  //      (~30 words). A long A is the model rambling — usually
  //      hallucinated, frequently still under-cited.
  //   4. Citations required. Cards without `SOURCE` are dropped —
  //      uncited factual sentences are the model's most likely
  //      fabrication path; the cited subset is verifiable.
  //   5. Unique questions. Same Q across multiple draft passes
  //      collapses to one card; the user-perceived UI is a stack of
  //      distinct facts, not the same fact thrice.
  //   6. Cap at N. Verbose drift past the requested count is dropped
  //      after dedupe + cite-filter, so we never show more than
  //      asked.
  //
  // Order matters in three places:
  //   - On-topic runs first because the cheapest filter should run
  //     first (no need to validate answers we're about to drop).
  //   - Reasoning-leak + length checks run before cite-filter so a
  //     rambling but cited card still drops.
  //   - Cite-filter runs before dedupe: if the model writes an
  //     uncited Q1 followed by the same Q1 with a SOURCE, dedupe-
  //     first would pick the uncited one (first occurrence) and
  //     throw away the cited duplicate.
  //
  // Empty `topic` skips the on-topic stage — defer to upstream
  // (`generateFlashcards` already refuses an empty-topic call before
  // ever invoking this pipeline; this is just the degenerate guard).

  /// Maximum chars allowed in a card's answer. Above this, the model
  /// is rambling — not answering. Real flashcard answers are one
  /// sentence (~30 words ≈ 200 chars); 300 leaves headroom for
  /// dense scientific definitions without admitting reasoning rambles.
  static const int _kMaxAnswerChars = 300;

  /// Substrings (lowercase) that mark the model leaked reasoning into
  /// the answer field. Pinned by tests so additions are deliberate.
  /// Tuned against the on-device 2026-05-25 Mars-moons leak; expand
  /// when new failure shapes surface.
  static const Set<String> _reasoningMarkers = {
    'wait, ',
    'wait but ',
    ', wait ',
    'wait,',
    'let me check',
    'let me think',
    'hmm,',
    ' hmm ',
    'actually,',
    'but maybe',
    'perhaps i ',
    'i think ',
    'i believe ',
    'however, in reality',
  };

  /// True iff `answer` contains a reasoning-prose marker, suggesting
  /// the model is thinking in the answer field instead of stating a
  /// fact.
  @visibleForTesting
  static bool answerLooksLikeReasoning(String answer) {
    final lower = answer.toLowerCase();
    for (final marker in _reasoningMarkers) {
      if (lower.contains(marker)) return true;
    }
    return false;
  }

  /// Backfill the SOURCE attribution on cards the model emitted without
  /// a SOURCE line. Two cases:
  ///
  ///   - `retrieved.length == 1` — unambiguous. Attribute the uncited
  ///     card to that single note regardless of content.
  ///   - `retrieved.length >= 2` — disambiguate by content. For each
  ///     uncited card, attribute to retrieved notes whose `topic`
  ///     substring appears (case-insensitively) in the card's Q+A.
  ///     A card that doesn't mention any retrieved note's topic is
  ///     left uncited — [cleanCards]'s cite-required stage drops it.
  ///
  /// Both 2026-05-25 dry-runs surfaced the same shape: model produced
  /// clean Q+A but truncated or omitted SOURCE.
  ///   - Mars-moons: 1 retrieved Mars note → single-retrieval branch.
  ///   - Atmosphere: 2 retrieved notes (Mercury, Venus) → content-
  ///     matching branch attributes each card by name.
  ///
  /// Cards that already had a SOURCE from the model are left untouched
  /// (no overwriting model attribution).
  @visibleForTesting
  static List<Flashcard> backfillCardSources(
    List<Flashcard> cards,
    List<RetrievedNote> retrieved,
  ) {
    if (retrieved.isEmpty) return cards;
    if (retrieved.length == 1) {
      final onlyId = retrieved.single.note.id;
      return cards.map((c) {
        if (c.sourceNoteIds.isNotEmpty) return c;
        return Flashcard(
          question: c.question,
          answer: c.answer,
          sourceNoteIds: [onlyId],
        );
      }).toList();
    }
    return cards.map((c) {
      if (c.sourceNoteIds.isNotEmpty) return c;
      final cardText = '${c.question} ${c.answer}'.toLowerCase();
      final matches = <String>[];
      for (final r in retrieved) {
        final topic = r.note.topic.toLowerCase();
        if (topic.isEmpty) continue;
        if (cardText.contains(topic)) matches.add(r.note.id);
      }
      if (matches.isEmpty) return c;
      return Flashcard(
        question: c.question,
        answer: c.answer,
        sourceNoteIds: matches,
      );
    }).toList();
  }

  /// Post-parse cleanup for cards emitted by [generateFlashcards].
  /// Drops off-topic cards, then uncited cards, then deduplicates by
  /// normalized question, then caps at `n`. See the section comment
  /// above for the rationale and ordering invariants.
  @visibleForTesting
  static List<Flashcard> cleanCards(
    List<Flashcard> cards,
    int n,
    String topic,
  ) {
    if (n <= 0) return const [];
    final needle = topic.toLowerCase();
    final out = <Flashcard>[];
    final seenQuestions = <String>{};
    for (final card in cards) {
      // 1. On-topic — Q or A must mention topic.
      if (needle.isNotEmpty) {
        final hayQ = card.question.toLowerCase();
        final hayA = card.answer.toLowerCase();
        if (!hayQ.contains(needle) && !hayA.contains(needle)) continue;
      }
      // 2. Reasoning-leak — drop cards whose A reads like the model is
      //    thinking instead of answering.
      if (answerLooksLikeReasoning(card.answer)) continue;
      // 3. Answer-length — drop cards whose A overflows what a real
      //    flashcard answer should be.
      if (card.answer.length > _kMaxAnswerChars) continue;
      // 4. Citations required.
      if (card.sourceNoteIds.isEmpty) continue;
      // 5. Dedupe by normalized question (case-insensitive,
      //    whitespace-collapsed).
      final key = card.question
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (key.isEmpty) continue;
      if (seenQuestions.contains(key)) continue;
      seenQuestions.add(key);
      out.add(card);
      // 6. Cap at n.
      if (out.length >= n) break;
    }
    return out;
  }

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
  ///
  /// Notes scoring below `minScore` are filtered out — the empty-list
  /// result then triggers `generateFlashcards`'s grounding gate, the
  /// right place to catch "topic doesn't match corpus".
  Future<List<RetrievedNote>> topK(
    String topic, {
    int k = defaultK,
    double minScore = defaultMinScore,
  }) async {
    if (topic.isEmpty) return const [];
    final qVecRaw = await embedQuery(topic);
    final qVec = normalize(qVecRaw);
    final notes = await DittoService.instance.queryWithEmbedding();
    final ranked =
        rankTopK(queryVec: qVec, notes: notes, k: k, minScore: minScore);
    if (kDebugMode) {
      // Diagnostic shape so on-device weirdness ('retrieved=0 with 5 notes
      // visible in the Notes tab') is debuggable from logcat. The
      // dim-distribution surfaces the mid-corpus model-swap case (U9
      // §3): notes embedded with a different model produce vectors of a
      // different length and are silently dropped at the rankTopK
      // dimension guard. If `noteDims` contains anything other than
      // `queryDim`, the guard ate them.
      final noteDims = <int, int>{};
      for (final n in notes) {
        noteDims[n.embedding.length] = (noteDims[n.embedding.length] ?? 0) + 1;
      }
      // Compute pre-threshold ranking too so logcat shows what the
      // threshold dropped — invaluable for tuning `minScore`.
      final preThreshold = rankTopK(
        queryVec: qVec,
        notes: notes,
        k: k,
        minScore: -1.0,
      );
      final preScores = preThreshold
          .map((r) => r.score.toStringAsFixed(3))
          .join(', ');
      debugPrint(
        '[topK] topic="$topic" k=$k minScore=$minScore '
        'totalEmbedded=${notes.length} '
        'queryDim=${qVec.length} '
        'noteDims=$noteDims '
        'survivedDimFilter=${notes.where((n) => n.embedding.length == qVec.length).length} '
        'preThresholdScores=[$preScores] '
        'ranked=${ranked.length}',
      );
    }
    return ranked;
  }

  /// Pure-math top-k. Testable directly — the math is the part that has
  /// to be right; the I/O wrapper around it is mechanical. Tie-break:
  /// `(score desc, id asc)` — UUIDv5 strings sort lex-asc → R2 stable.
  ///
  /// Notes whose embedding-length differs from `queryVec.length` are
  /// silently dropped (mid-corpus model swap guard).
  ///
  /// Notes scoring below `minScore` are filtered out. Use `-1.0` to
  /// disable the threshold (cosine is bounded `[-1, 1]`, so a -1.0
  /// floor accepts every result).
  @visibleForTesting
  static List<RetrievedNote> rankTopK({
    required Float32List queryVec,
    required List<StudyNote> notes,
    required int k,
    double minScore = defaultMinScore,
  }) {
    final scored = <RetrievedNote>[];
    for (final note in notes) {
      if (note.embedding.length != queryVec.length) continue;
      final docVec = normalize(Float32List.fromList(note.embedding));
      final score = dot(queryVec, docVec);
      if (score < minScore) continue;
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

  // ───── generateFlashcards — Stage 1 (U11) ─────────────────────────────

  /// Stream the flashcard generation for `topic`:
  ///   1. `topK(topic)` → emit [FlashcardEventRetrieved]
  ///   2. build [FlashcardGenPrompt] messages
  ///   3. open [CactusService.complete] stream → emit
  ///      [FlashcardEventPartial] per chunk
  ///   4. on stream end, parse the joined raw via [FlashcardGenPrompt.parse]
  ///      → emit [FlashcardEventCards]
  ///   5. emit [FlashcardEventDone]
  ///
  /// On stream error the exception propagates through the returned
  /// stream — `FlashcardsTab._onStreamError` (U10) renders the error
  /// banner and the prior generation history stays intact.
  ///
  /// Token budget: `kThinkBudget (512) + kMaxTokensPerCard (160) × n`.
  /// The `<think>` slush exists because Qwen 2.5 leaks chain-of-thought
  /// even when told not to; the parser strips those, but the visible
  /// cards need pre-allocated room to land within `maxTokens`.
  Stream<FlashcardEvent> generateFlashcards(
    String topic, {
    int k = defaultK,
    int n = defaultN,
    List<Flashcard> savedExamples = const [],
  }) async* {
    final cosineRetrieved = await topK(topic, k: k);
    // Second grounding layer (CLAUDE.md `feedback_structural_gates`):
    // cosine alone lets through semantically-adjacent-but-wrong-entity
    // matches (Jupiter notes scoring high for "Saturn"). The substring
    // entity check on topic/body/tags catches that exact failure mode
    // before the LLM is called. Cosine = topical filter; entity check =
    // hallucination backstop; they fail in different ways.
    final retrieved = filterByEntityMention(cosineRetrieved, topic);
    if (kDebugMode && retrieved.length < cosineRetrieved.length) {
      debugPrint(
        '[generateFlashcards] entity-filter dropped '
        '${cosineRetrieved.length - retrieved.length} of '
        '${cosineRetrieved.length} cosine-ranked note(s) that did not '
        'mention "$topic" in topic/body/tags',
      );
    }
    yield FlashcardEventRetrieved(retrieved);

    // Gate-on-empty (CLAUDE.md `feedback_llm_grounding`): if retrieval
    // returned nothing — either cosine dropped everything below
    // defaultMinScore, or the entity filter dropped what remained — do
    // NOT call the LLM. A 1.5B model under-honors the "(no notes
    // available — output nothing)" instruction in the prompt and
    // confabulates cards from training data, which tanks the demo's
    // grounding claim. Short-circuit to an empty result; the UI
    // surfaces a "no notes match this topic" message keyed off
    // `retrieved.isEmpty` in the generation block.
    if (retrieved.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[generateFlashcards] topic="$topic" retrieved=0 — '
          'skipping LLM call (grounding gate)',
        );
      }
      yield const FlashcardEventCards([]);
      yield const FlashcardEventDone();
      return;
    }

    // Scale the requested card count to retrieval reality. With only
    // 1 retrieved note and n=3 default, Qwen pads with off-topic facts
    // from the same note (Olympus Mons / Valles Marineris / day-length
    // when topic was "moons"). Asking for fewer cards lets the model
    // commit to the on-topic subset honestly.
    final effectiveN = retrieved.length < n ? retrieved.length : n;
    final messages = FlashcardGenPrompt.build(
      topic: topic,
      n: effectiveN,
      retrieved: retrieved,
      savedExamples: savedExamples,
    );
    final maxTokens = _kThinkBudget + _kMaxTokensPerCard * effectiveN;

    final buffer = StringBuffer();
    // Per-line buffer for log readability. Cactus emits one chunk per
    // token, which makes logcat unreadable when each token is its own
    // line ('let', "'", 's', ' see', ...). Accumulate until we see a
    // newline, then flush the whole line at once — one logcat entry per
    // actual line of model output.
    final lineBuffer = StringBuffer();
    if (kDebugMode) {
      debugPrint(
        '[generateFlashcards] topic="$topic" k=$k n=$n '
        'effectiveN=$effectiveN retrieved=${retrieved.length} '
        'maxTokens=$maxTokens',
      );
      debugPrint('[generateFlashcards] --- raw stream begin ---');
    }
    await for (final chunk in CactusService.instance.complete(
      messages,
      maxTokens: maxTokens,
    )) {
      buffer.write(chunk);
      yield FlashcardEventPartial(chunk);
      if (kDebugMode) {
        lineBuffer.write(chunk);
        if (chunk.contains('\n')) {
          final parts = lineBuffer.toString().split('\n');
          // Everything but the last segment is a complete line — flush.
          // The last segment is an incomplete line — keep buffering.
          for (var i = 0; i < parts.length - 1; i++) {
            debugPrint('  | ${parts[i]}', wrapWidth: 1024);
          }
          lineBuffer
            ..clear()
            ..write(parts.last);
        }
      }
    }
    if (kDebugMode) {
      if (lineBuffer.isNotEmpty) {
        debugPrint('  | ${lineBuffer.toString()}', wrapWidth: 1024);
      }
      debugPrint('[generateFlashcards] --- raw stream end '
          '(${buffer.length} chars) ---');
    }

    final rawCards = FlashcardGenPrompt.parse(buffer.toString());
    final attributed = backfillCardSources(rawCards, retrieved);
    final cards = cleanCards(attributed, effectiveN, topic);
    if (kDebugMode) {
      final backfilledCount =
          attributed.where((c) => c.sourceNoteIds.isNotEmpty).length -
              rawCards.where((c) => c.sourceNoteIds.isNotEmpty).length;
      if (backfilledCount > 0) {
        debugPrint(
          '[generateFlashcards] backfilled SOURCE for $backfilledCount '
          'card(s) (model omitted SOURCE; attributed by '
          '${retrieved.length == 1 ? "single retrieval" : "content matching"})',
        );
      }
      if (rawCards.length != cards.length) {
        debugPrint(
          '[generateFlashcards] parsed ${rawCards.length} raw card(s); '
          'kept ${cards.length} after on-topic + reasoning-leak + '
          'answer-length + drop-uncited + dedupe + cap(n=$effectiveN)',
        );
      } else {
        debugPrint('[generateFlashcards] parsed ${cards.length} card(s)');
      }
    }
    yield FlashcardEventCards(cards);
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
