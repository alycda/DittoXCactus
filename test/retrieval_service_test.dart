// Tests for RetrievalService (U9).
//
// The I/O-shaped methods (ensureEmbeddings, embedQuery, topK, the
// generateFlashcards stub) need Cactus + Ditto live; those are exercised
// on real devices. What's testable here without a Flutter binding is the
// pure-math layer:
//   - `normalize` (L2 norm, zero-vector identity)
//   - `dot` (parallel / orthogonal / 384-dim sanity)
//   - `rankTopK` (tie-break, k > N, dimension mismatch, empty corpus)
//
// rankTopK is the load-bearing piece — it's the function that, when
// applied to the materialized CRDT-merged note set, makes mesh-RAG's
// "retrieval is a pure function over the union" thesis true in code.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/models/study_note.dart';
import 'package:mesh_rag/services/retrieval_service.dart';

void main() {
  group('RetrievalService.normalize', () {
    test('produces a unit vector on a non-zero input', () {
      final v = Float32List.fromList([3.0, 4.0]); // length 5
      final u = RetrievalService.normalize(v);
      expect(u[0], closeTo(0.6, 1e-6));
      expect(u[1], closeTo(0.8, 1e-6));
      final norm = math.sqrt(u[0] * u[0] + u[1] * u[1]);
      expect(norm, closeTo(1.0, 1e-6));
    });

    test('is identity on the zero vector (no NaN poisoning)', () {
      final zero = Float32List.fromList([0.0, 0.0, 0.0]);
      final u = RetrievalService.normalize(zero);
      expect(u[0], 0.0);
      expect(u[1], 0.0);
      expect(u[2], 0.0);
      // Critically: no NaN. A zero vector through a naive normalize
      // becomes [NaN, NaN, NaN], which then poisons every downstream
      // cosine score. R2's stability guarantee depends on this guard.
      for (final x in u) {
        expect(x.isNaN, isFalse);
      }
    });
  });

  group('RetrievalService.dot', () {
    test('parallel normalized vectors → 1.0', () {
      final a = RetrievalService.normalize(Float32List.fromList([1.0, 1.0]));
      final b = RetrievalService.normalize(Float32List.fromList([2.0, 2.0]));
      expect(RetrievalService.dot(a, b), closeTo(1.0, 1e-6));
    });

    test('antiparallel normalized vectors → -1.0', () {
      final a = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final b = RetrievalService.normalize(Float32List.fromList([-1.0, 0.0]));
      expect(RetrievalService.dot(a, b), closeTo(-1.0, 1e-6));
    });

    test('orthogonal normalized vectors → 0.0', () {
      final a = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final b = RetrievalService.normalize(Float32List.fromList([0.0, 1.0]));
      expect(RetrievalService.dot(a, b), closeTo(0.0, 1e-6));
    });

    test('384-dim parallel sanity', () {
      // Cactus's embedding-head dimensionality is 1024 in practice (U6),
      // but historical literature pins on 384 (MiniLM / EmbeddingGemma
      // small Matryoshka tier) — the plan's test scenario names 384, so
      // the test honors it. The point is: the math is linear-time and
      // works at any dimension.
      const dim = 384;
      final a = Float32List(dim);
      final b = Float32List(dim);
      for (var i = 0; i < dim; i++) {
        a[i] = (i + 1).toDouble();
        b[i] = (i + 1).toDouble();
      }
      final aN = RetrievalService.normalize(a);
      final bN = RetrievalService.normalize(b);
      expect(RetrievalService.dot(aN, bN), closeTo(1.0, 1e-6));
    });
  });

  group('RetrievalService.rankTopK', () {
    // Hand-crafted Float32 fixtures with known cosine relationships.
    // Each test note has the same dim (2) so the dimension-match path
    // doesn't filter them out — the dim-mismatch case lives in its own
    // test.
    StudyNote note(String id, double x, double y, {String topic = 't'}) {
      // Construct a StudyNote directly (not via .seed) so we can pin
      // the id to a sortable token and the embedding to a known shape.
      return StudyNote(
        id: id,
        topic: topic,
        contributor: 'phone-a',
        body: 'b',
        tags: const [],
        embedding: List<double>.unmodifiable([x, y]),
        createdAt: DateTime.utc(2026, 5, 22),
      );
    }

    test('happy path: ranks by descending cosine', () {
      final q = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final notes = [
        note('B', 0.0, 1.0), // orthogonal → score 0
        note('A', 1.0, 0.0), // parallel → score 1
        note('C', 0.5, 0.5), // 45° → ~0.707
      ];
      // Tests the pure ranking math — disable the minScore threshold
      // with -1.0 so the orthogonal note isn't filtered out.
      final ranked = RetrievalService.rankTopK(
        queryVec: q,
        notes: notes,
        k: 5,
        minScore: -1.0,
      );
      expect(ranked.map((r) => r.note.id).toList(), ['A', 'C', 'B']);
      expect(ranked[0].score, closeTo(1.0, 1e-6));
      expect(ranked[1].score, closeTo(math.sqrt(0.5), 1e-6));
    });

    test('returns at most k results', () {
      final q = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final notes = [
        for (var i = 0; i < 10; i++) note('id_$i', 1.0 - i * 0.01, 0.0),
      ];
      final ranked = RetrievalService.rankTopK(
        queryVec: q,
        notes: notes,
        k: 3,
        minScore: -1.0,
      );
      expect(ranked.length, 3);
    });

    test('k > N returns all N results in correct order', () {
      final q = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final notes = [
        note('A', 0.5, 0.5),
        note('B', 1.0, 0.0),
      ];
      final ranked = RetrievalService.rankTopK(
        queryVec: q,
        notes: notes,
        k: 10,
        minScore: -1.0,
      );
      expect(ranked.length, 2);
      expect(ranked.first.note.id, 'B');
      expect(ranked.last.note.id, 'A');
    });

    test('minScore threshold drops weak retrievals', () {
      final q = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final notes = [
        note('strong', 1.0, 0.0), // score = 1.0
        note('medium', 0.5, 0.5), // score ≈ 0.707
        note('weak', 0.0, 1.0), // score = 0.0 (orthogonal)
      ];
      // With minScore=0.3 (default), the orthogonal note drops.
      final ranked = RetrievalService.rankTopK(
        queryVec: q,
        notes: notes,
        k: 5,
      );
      expect(ranked.map((r) => r.note.id).toList(), ['strong', 'medium']);
      // With minScore higher, even the 45° note drops.
      final tight = RetrievalService.rankTopK(
        queryVec: q,
        notes: notes,
        k: 5,
        minScore: 0.8,
      );
      expect(tight.map((r) => r.note.id).toList(), ['strong']);
    });

    test('minScore higher than any score → empty result '
        '(grounding gate fires)', () {
      final q = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final notes = [
        note('weak1', 0.1, 1.0), // low cosine
        note('weak2', 0.05, 1.0),
      ];
      final ranked = RetrievalService.rankTopK(
        queryVec: q,
        notes: notes,
        k: 5,
        minScore: 0.5,
      );
      expect(ranked, isEmpty);
    });

    test('empty corpus returns []', () {
      final q = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final ranked = RetrievalService.rankTopK(
        queryVec: q,
        notes: const [],
        k: 5,
      );
      expect(ranked, isEmpty);
    });

    test('tied cosines tie-break by _id (lex-asc)', () {
      // Two notes with identical cosine → R2 invariant: lower id wins.
      // UUIDv5 strings sort lex-asc so this is meaningful across devices.
      final q = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final notes = [
        note('zzz', 1.0, 0.0),
        note('aaa', 1.0, 0.0),
        note('mmm', 1.0, 0.0),
      ];
      final ranked =
          RetrievalService.rankTopK(queryVec: q, notes: notes, k: 5);
      expect(ranked.map((r) => r.note.id).toList(), ['aaa', 'mmm', 'zzz']);
    });

    test('drops notes whose embedding length mismatches the query', () {
      // The mid-corpus model-swap guard. If the embedding head changes
      // partway through the corpus (e.g. a slug swap), old notes survive
      // in storage but are dropped from topK until re-embedded.
      final q = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final wrongDim = StudyNote(
        id: 'wrong',
        topic: 't',
        contributor: 'phone-a',
        body: 'b',
        tags: const [],
        embedding: const [1.0, 0.0, 0.0], // 3-dim, query is 2-dim
        createdAt: DateTime.utc(2026, 5, 22),
      );
      final notes = [wrongDim, note('right', 1.0, 0.0)];
      final ranked =
          RetrievalService.rankTopK(queryVec: q, notes: notes, k: 5);
      expect(ranked.length, 1);
      expect(ranked.single.note.id, 'right');
    });

    test('notes with empty embedding are dropped (length mismatch)', () {
      // Fresh-seeded notes have `embedding == []`. Length mismatch with
      // the query (which is non-empty) means they're skipped — they'll
      // be picked up by the next ensureEmbeddings pass.
      final q = RetrievalService.normalize(Float32List.fromList([1.0, 0.0]));
      final unembedded = StudyNote(
        id: 'unembedded',
        topic: 't',
        contributor: 'phone-a',
        body: 'b',
        tags: const [],
        embedding: const [],
        createdAt: DateTime.utc(2026, 5, 22),
      );
      final ranked = RetrievalService.rankTopK(
        queryVec: q,
        notes: [unembedded, note('embedded', 1.0, 0.0)],
        k: 5,
      );
      expect(ranked.length, 1);
      expect(ranked.single.note.id, 'embedded');
    });

    test('5,000-note synthetic corpus: top-5 lands obvious neighbors first',
        () {
      // Stage 0 is well below this scale, but the plan calls out a
      // sub-5ms target at 5k rows on mid-range Android. We don't
      // benchmark on the host (timing on dev machines is meaningless for
      // mobile claims) — we just verify the math survives the size.
      final rng = math.Random(42);
      const dim = 16;
      const n = 5000;

      Float32List rand() {
        final v = Float32List(dim);
        for (var i = 0; i < dim; i++) {
          v[i] = rng.nextDouble() * 2 - 1;
        }
        return v;
      }

      final query = RetrievalService.normalize(rand());
      // Plant 3 specific notes deliberately close to query, then fill
      // with random.
      List<double> nearQuery(double scale) {
        final v = Float32List(dim);
        for (var i = 0; i < dim; i++) {
          v[i] = query[i] * scale + (rng.nextDouble() * 0.01);
        }
        return List<double>.unmodifiable(v);
      }

      final notes = <StudyNote>[
        StudyNote(
          id: 'near_1.0',
          topic: 't',
          contributor: 'phone-a',
          body: 'b',
          tags: const [],
          embedding: nearQuery(1.0),
          createdAt: DateTime.utc(2026, 5, 22),
        ),
        StudyNote(
          id: 'near_0.9',
          topic: 't',
          contributor: 'phone-a',
          body: 'b',
          tags: const [],
          embedding: nearQuery(0.9),
          createdAt: DateTime.utc(2026, 5, 22),
        ),
        StudyNote(
          id: 'near_0.8',
          topic: 't',
          contributor: 'phone-a',
          body: 'b',
          tags: const [],
          embedding: nearQuery(0.8),
          createdAt: DateTime.utc(2026, 5, 22),
        ),
      ];
      for (var i = 0; i < n - 3; i++) {
        notes.add(StudyNote(
          id: 'rand_$i',
          topic: 't',
          contributor: 'phone-a',
          body: 'b',
          tags: const [],
          embedding: List<double>.unmodifiable(rand()),
          createdAt: DateTime.utc(2026, 5, 22),
        ));
      }

      final ranked = RetrievalService.rankTopK(
        queryVec: query,
        notes: notes,
        k: 5,
        // Disable threshold; this test is about the ranking math
        // surviving 5k rows, not the threshold semantics.
        minScore: -1.0,
      );
      expect(ranked.length, 5);
      // The 3 planted notes must dominate the top of the ranking.
      final topIds = ranked.take(3).map((r) => r.note.id).toSet();
      expect(topIds, containsAll(['near_1.0', 'near_0.9', 'near_0.8']));
    });
  });

  group('RetrievalService.defaultK / defaultN', () {
    test('plan-locked defaults', () {
      // defaultK=10 (Stage 0 merged corpus = 5+5). Sized to cover the
      // full corpus so the entity-overlap filter downstream sees every
      // candidate, not just the cosine top-5 (the 2026-05-25 mesh dry-run
      // bug where A's inner-planet notes outranked B's Saturn note).
      expect(RetrievalService.defaultK, 10);
      expect(RetrievalService.defaultN, 3);
    });
  });

  group('RetrievalService.mentionsEntity', () {
    // Entity-overlap is the hallucination backstop on top of the cosine
    // threshold. Pure substring scan over topic/body/tags — Stage 0/1
    // queries are single-topic so this is sufficient. The cases below
    // pin the on-device failure mode (Saturn-on-phone-a, Jupiter notes
    // ranking high) we built this for.

    StudyNote note({
      String topic = 'Saturn',
      String body = 'The sixth planet.',
      List<String> tags = const [],
    }) {
      return StudyNote(
        id: 'note-test',
        topic: topic,
        contributor: 'phone-a',
        body: body,
        tags: List<String>.unmodifiable(tags),
        embedding: const [],
        createdAt: DateTime.utc(2026, 5, 25),
      );
    }

    test('matches when topic appears in the note topic (case-insensitive)', () {
      expect(
          RetrievalService.mentionsEntity(note(topic: 'Saturn'), 'saturn'),
          isTrue);
      expect(
          RetrievalService.mentionsEntity(note(topic: 'saturn'), 'Saturn'),
          isTrue);
    });

    test('matches when topic appears in the note body', () {
      final n = note(
          topic: 'planets',
          body: 'Saturn has the most pronounced ring system.');
      expect(RetrievalService.mentionsEntity(n, 'Saturn'), isTrue);
    });

    test('matches when topic appears in any tag', () {
      final n = note(topic: 'planets', body: 'orbital mechanics', tags: const [
        'gas-giant',
        'saturn',
        'cassini',
      ]);
      expect(RetrievalService.mentionsEntity(n, 'Saturn'), isTrue);
    });

    test('substring match — "Earth" hits "Earth\'s atmosphere"', () {
      // Single-token query as a substring of a longer phrase is fine.
      // This is the property that makes cheap matching work on the
      // Stage 1 corpus.
      final n = note(topic: "Earth's atmosphere", body: 'layers and gases');
      expect(RetrievalService.mentionsEntity(n, 'Earth'), isTrue);
    });

    test('refuses when neither topic nor body nor any tag mentions it '
        '(the Saturn-on-phone-a failure mode)', () {
      // The exact dry-run scenario: phone-a corpus = inner planets;
      // query = "Saturn"; cosine returns 5 notes (Mercury / Venus /
      // Earth / Mars / Moon) at low scores. The entity check refuses
      // each one before any of them reaches the LLM.
      final mercury = note(
          topic: 'Mercury',
          body: 'The closest planet to the Sun.',
          tags: const ['inner-planet']);
      final venus = note(
          topic: 'Venus',
          body: 'Hottest planet; dense CO2 atmosphere.',
          tags: const ['inner-planet']);
      final earth = note(
          topic: 'Earth',
          body: 'Third from the Sun; only known life-bearing.',
          tags: const ['inner-planet', 'home']);
      expect(RetrievalService.mentionsEntity(mercury, 'Saturn'), isFalse);
      expect(RetrievalService.mentionsEntity(venus, 'Saturn'), isFalse);
      expect(RetrievalService.mentionsEntity(earth, 'Saturn'), isFalse);
    });

    test('empty topic returns true (defer to cosine alone)', () {
      // Degenerate "no query" case — refusing everything would break
      // any caller that didn't expect a hard refuse on empty input;
      // cosine handles it (topK returns [] on empty topic).
      expect(RetrievalService.mentionsEntity(note(), ''), isTrue);
    });

    test('multi-word topic substring still works when the phrase appears '
        'verbatim', () {
      final n = note(
          topic: "Earth's Moon", body: 'tidally locked; ~3,475 km diameter');
      expect(RetrievalService.mentionsEntity(n, "Earth's Moon"), isTrue);
    });

    test('multi-word topic refused when no single chunk of text contains '
        'the whole phrase (documented caveat)', () {
      // If query phrasing reorders the words from the note's phrasing,
      // substring match misses. This is the boundary the other-Claude
      // note flagged: token-level NER would catch it, but Stage 0/1
      // queries are single-topic so we accept the limitation.
      final n = note(
          topic: 'lunar exploration',
          body: 'The Moon orbits the Earth at ~384,000 km.');
      // "Earth's Moon" never appears as a substring even though both
      // tokens are present individually.
      expect(RetrievalService.mentionsEntity(n, "Earth's Moon"), isFalse);
    });
  });

  group('RetrievalService.filterByEntityMention', () {
    StudyNote n(String topic) => StudyNote(
          id: 'note-$topic',
          topic: topic,
          contributor: 'phone-a',
          body: 'body of $topic note',
          tags: const [],
          embedding: const [],
          createdAt: DateTime.utc(2026, 5, 25),
        );

    test('drops notes that do not mention the topic; keeps those that do', () {
      final retrieved = [
        RetrievedNote(note: n('Mercury'), score: 0.25),
        RetrievedNote(note: n('Saturn'), score: 0.21),
        RetrievedNote(note: n('Venus'), score: 0.18),
      ];
      final out =
          RetrievalService.filterByEntityMention(retrieved, 'Saturn');
      expect(out.length, 1);
      expect(out.single.note.topic, 'Saturn');
    });

    test('preserves cosine-rank order on the surviving subset', () {
      // Caller already sorted by descending cosine; the filter is a
      // where-stable operation, so any retained subset keeps that order.
      final retrieved = [
        RetrievedNote(note: n('Saturn'), score: 0.9),
        RetrievedNote(note: n('Mercury'), score: 0.5),
        RetrievedNote(note: n('saturnine moods'), score: 0.3),
      ];
      final out =
          RetrievalService.filterByEntityMention(retrieved, 'Saturn');
      expect(out.map((r) => r.note.topic).toList(),
          ['Saturn', 'saturnine moods']);
      expect(out.first.score, greaterThan(out.last.score));
    });

    test('empty input → empty output', () {
      expect(
          RetrievalService.filterByEntityMention(const [], 'Saturn'), isEmpty);
    });

    test('empty topic returns input unchanged (defer to cosine alone)', () {
      final retrieved = [
        RetrievedNote(note: n('Mercury'), score: 0.5),
        RetrievedNote(note: n('Venus'), score: 0.4),
      ];
      final out = RetrievalService.filterByEntityMention(retrieved, '');
      expect(out, equals(retrieved));
    });

    test(
        'all retrievals filtered out → empty list (grounding gate '
        'fires upstream in generateFlashcards)', () {
      // The exact path that catches the on-device failure mode: cosine
      // returned 5 notes about inner planets, none mention "Saturn",
      // entity filter returns []; generateFlashcards sees
      // retrieved.isEmpty and skips the LLM call.
      final retrieved = [
        RetrievedNote(note: n('Mercury'), score: 0.25),
        RetrievedNote(note: n('Venus'), score: 0.21),
        RetrievedNote(note: n('Earth'), score: 0.18),
        RetrievedNote(note: n('Mars'), score: 0.15),
        RetrievedNote(note: n('Jupiter'), score: 0.12),
      ];
      expect(
          RetrievalService.filterByEntityMention(retrieved, 'Saturn'), isEmpty);
    });
  });

  group('RetrievalService.cleanCards', () {
    // Generation-side contract enforcement: on-topic → cite-filter →
    // dedupe → cap. The 2026-05-25 dry-run captured the failures these
    // tests pin: Qwen never closed <think>, drafted three cards three
    // separate times inside the unclosed reasoning (9 raw → 3 unique),
    // and on the moons follow-up dutifully made 4 cards from 1 Mars
    // note, only 1 of which was actually about moons.

    Flashcard card(String q, String a, {List<String> sources = const ['n1']}) =>
        Flashcard(question: q, answer: a, sourceNoteIds: sources);

    test('happy path: 3 unique cited on-topic cards passed through unchanged',
        () {
      final raw = [
        card('What is Mars?', 'The fourth planet.'),
        card('What are Mars moons?', 'Phobos and Deimos.'),
        card('How long is a Martian day on Mars?', '24 hours 37 minutes.'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, 'Mars');
      expect(out.length, 3);
      expect(out, equals(raw));
    });

    test('drops cards with empty sourceNoteIds (cite-required)', () {
      final raw = [
        card('Q1', 'A1', sources: const []),
        card('Q2', 'A2'),
        card('Q3', 'A3', sources: const []),
      ];
      // Topic '' skips the on-topic stage so this test isolates the
      // cite-filter behavior.
      final out = RetrievalService.cleanCards(raw, 3, '');
      expect(out.length, 1);
      expect(out.single.question, 'Q2');
    });

    test('dedupes by question (case-insensitive, whitespace-normalized)', () {
      final raw = [
        card('What is Mars?', 'first answer'),
        card('what  is\tmars?', 'duplicate variant'), // dup
        card('WHAT IS MARS?', 'another duplicate'), // dup
        card('What is Earth?', 'distinct'),
      ];
      final out = RetrievalService.cleanCards(raw, 5, '');
      expect(out.length, 2);
      expect(out.first.answer, 'first answer'); // first occurrence wins
      expect(out.last.question, 'What is Earth?');
    });

    test('caps at n after dedupe and cite-filter', () {
      final raw = [
        for (var i = 1; i <= 6; i++) card('Q$i', 'A$i'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, '');
      expect(out.length, 3);
      expect(out.map((c) => c.question).toList(), ['Q1', 'Q2', 'Q3']);
    });

    test('cite-filter runs before dedupe so uncited duplicates do not '
        'shadow the cited copy', () {
      // If the model writes Q1 uncited (inside <think>) and then Q1
      // cited (in the final answer), we want to keep the cited one.
      final raw = [
        card('What is Mars?', 'reasoning version', sources: const []),
        card('What is Mars?', 'final cited version'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, '');
      expect(out.length, 1);
      expect(out.single.answer, 'final cited version');
    });

    test('the on-device 9-cards-for-3 case collapses to 3', () {
      // Exact shape from the 2026-05-25 dry-run with topic="moons":
      // Qwen drafted 3 cards three times (initial think, "**Final
      // Answer**" repeat, boxed/repeat-again partial). All cited the
      // same note. Parser returned 9 cards; cleanCards must collapse
      // to 3. Topic '' here lets the test focus on dedupe.
      final raw = <Flashcard>[];
      const passes = 3;
      const qs = [
        'What is the name of Mars\' largest canyon system?',
        'Which two moons does Mars have?',
        'How long is a Martian day in hours?',
      ];
      const as = [
        'Valles Marineris.',
        'Phobos and Deimos.',
        'About 24 hours 37 minutes.',
      ];
      for (var pass = 0; pass < passes; pass++) {
        for (var i = 0; i < qs.length; i++) {
          raw.add(card(qs[i], as[i]));
        }
      }
      expect(raw.length, 9);
      final out = RetrievalService.cleanCards(raw, 3, '');
      expect(out.length, 3);
      expect(out.map((c) => c.question).toList(), qs);
    });

    test('empty input → empty output', () {
      expect(RetrievalService.cleanCards(const [], 3, ''), isEmpty);
    });

    test('all-uncited input → empty output (no fallback to uncited cards)',
        () {
      final raw = [
        for (var i = 1; i <= 3; i++)
          card('Q$i', 'A$i', sources: const []),
      ];
      expect(RetrievalService.cleanCards(raw, 3, ''), isEmpty);
    });

    test('n=0 returns empty regardless of input', () {
      final raw = [card('Q1', 'A1')];
      expect(RetrievalService.cleanCards(raw, 0, ''), isEmpty);
    });

    test('empty / whitespace-only question is dropped before dedupe', () {
      // A card whose question parses to "" (or just whitespace) can't
      // be a useful card — and would otherwise occupy the empty-string
      // dedupe key and shadow any later genuinely-empty card.
      final raw = [
        card('', 'orphan answer'),
        card('   ', 'another orphan'),
        card('Q1', 'A1'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, '');
      expect(out.length, 1);
      expect(out.single.question, 'Q1');
    });

    // ─── On-topic filter ─────────────────────────────────────────────

    test('drops cards whose Q and A do not mention the topic (case-insensitive)',
        () {
      // The exact 2026-05-25 follow-up dry-run shape: Mars note retrieved
      // for topic="moons"; model produced 4 cards, only one about moons.
      final raw = [
        card('Is Olympus Mons the largest volcano in the solar system?',
            'Yes, it is one of the tallest mountains in Mars.'),
        card('Is Valles Marineris the longest canyon on Mars?',
            'Yes, it spans approximately 4000 km across.'),
        card('What are the names of Mars\' two moons?',
            'Phobos and Deimos.'),
        card('How long is a day on Mars compared to Earth?',
            'A Martian sol is about 24 hours 37 minutes.'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, 'moons');
      expect(out.length, 1);
      expect(out.single.question, contains('moons'));
    });

    test('topic match in the answer alone is sufficient', () {
      // Sometimes the Q is generic and the A names the entity.
      final raw = [
        card('What did NASA find?', 'Two small moons orbiting Mars.'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, 'moons');
      expect(out.length, 1);
    });

    test('on-topic filter is case-insensitive', () {
      final raw = [
        card('Mars MOONS?', 'Phobos and Deimos'),
        card('mars moons?', 'Phobos and Deimos', sources: const ['n2']),
      ];
      final out = RetrievalService.cleanCards(raw, 3, 'Moons');
      // both pass on-topic; dedupe collapses them to one
      expect(out.length, 1);
    });

    test('empty topic skips the on-topic stage (degenerate guard)', () {
      // generateFlashcards refuses an empty-topic call upstream; this
      // ensures the static helper itself doesn't refuse-all on '' input.
      final raw = [
        card('Anything?', 'Whatever.'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, '');
      expect(out.length, 1);
    });

    test('on-topic stage runs first — does not waste a dedupe / cite slot '
        'on a card that the topic filter will drop', () {
      final raw = [
        card('Olympus Mons height?', '22 km'),
        card('Mars moons?', 'Phobos and Deimos'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, 'moons');
      expect(out.length, 1);
      expect(out.single.question, 'Mars moons?');
    });

    // ─── Reasoning-leak detection ────────────────────────────────────

    test('drops cards whose A contains reasoning markers (the on-device '
        '"Phoebus" leak)', () {
      // Exact A: shape from the 2026-05-25 dry-run: model started OK,
      // then leaked its own second-guessing into the answer field.
      final raw = [
        card('Mars moons?',
            'Mars has two smallest moons; Phoebus is a small moon... '
            'Wait, but original note says Phobos.'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, 'moons');
      expect(out, isEmpty);
    });

    test('drops cards with "Hmm,", "Actually,", "Let me check", "perhaps i", '
        '"I think", "but maybe"', () {
      final markers = {
        'Mars moons?': 'Hmm, well, two satellites of Mars are something.',
        'Mars rotation?': 'Actually, the rotation period is around 24 hours.',
        'Mars moons names?': 'Let me check, Mars has Phobos and Deimos.',
        'Mars day length?': 'Perhaps I should say about 24 hours.',
        'Mars composition?': 'I think Mars is mostly iron oxide and basalt.',
        'Mars satellites?': 'But maybe there are two small satellites.',
      };
      for (final entry in markers.entries) {
        final raw = [card(entry.key, entry.value)];
        final out = RetrievalService.cleanCards(raw, 3, 'Mars');
        expect(out, isEmpty,
            reason: 'Should drop card with reasoning marker in: '
                '"${entry.value}"');
      }
    });

    test('keeps factual answers that happen to contain reasoning-adjacent '
        'words far from reasoning use', () {
      // Not every "but" or "however" signals reasoning. Substring matches
      // are anchored to specific phrases so legitimate answers survive.
      final raw = [
        card('What is gravity?',
            'A force that attracts mass, however small, toward other mass.'),
      ];
      final out = RetrievalService.cleanCards(raw, 3, 'gravity');
      // "however," without "in reality" trailing is fine.
      expect(out.length, 1);
    });

    // ─── Answer-length cap ───────────────────────────────────────────

    test('drops cards whose A is longer than the cap (~300 chars)', () {
      // Models that ramble produce multi-clause answers. Real flashcard
      // answers are one sentence — overflow is the model talking, not
      // answering.
      final longA = 'a' * 350;
      final raw = [card('Q with long A about Mars?', longA)];
      final out = RetrievalService.cleanCards(raw, 3, 'Mars');
      expect(out, isEmpty);
    });

    test('answers right at the cap pass; one char over fails', () {
      // Boundary check — the cap is 300 chars; tests pin both sides
      // so a tuning change in the constant lights up here.
      final atCap = 'mars ${'a' * 295}'; // 300 chars exactly
      final overCap = 'mars ${'a' * 296}'; // 301 chars
      expect(RetrievalService.cleanCards(
          [card('Q?', atCap)], 3, 'mars').length, 1);
      expect(RetrievalService.cleanCards(
          [card('Q?', overCap)], 3, 'mars'), isEmpty);
    });

    // ─── answerLooksLikeReasoning helper ─────────────────────────────

    test('answerLooksLikeReasoning: positive markers', () {
      for (final s in const [
        'Wait, but original note says Phobos',
        'wait, but original note says phobos', // case-insensitive
        'Hmm, well that\'s tricky',
        'Actually, the answer is something else',
        'Let me check the source',
        'Perhaps I should reconsider',
        'I think this is right',
        'I believe so',
        'However, in reality there is no such thing',
        'Mars has moons. But maybe more exist.',
      ]) {
        expect(RetrievalService.answerLooksLikeReasoning(s), isTrue,
            reason: 'Should flag: "$s"');
      }
    });

    test('answerLooksLikeReasoning: negative cases (legitimate answers)', () {
      for (final s in const [
        'Phobos and Deimos, both captured asteroids.',
        'The fourth planet from the Sun.',
        'A force that attracts mass, however small, toward other mass.',
        '24 hours, 37 minutes.',
        '', // empty
      ]) {
        expect(RetrievalService.answerLooksLikeReasoning(s), isFalse,
            reason: 'Should NOT flag: "$s"');
      }
    });
  });

  group('RetrievalService.backfillCardSources', () {
    // Two dry-runs on 2026-05-25 captured the failure shape: Qwen
    // produced clean on-topic Q+A cards but omitted SOURCE lines.
    //   - Mars-moons (1 retrieved note) → unambiguous attribution.
    //   - Atmosphere (2 retrieved notes: Mercury + Venus) → content-
    //     matching: each card names the entity from its source note.

    StudyNote note(String id, {String topic = 'Mars', String body = 'body'}) =>
        StudyNote(
          id: id,
          topic: topic,
          contributor: 'phone-a',
          body: body,
          tags: const [],
          embedding: const [],
          createdAt: DateTime.utc(2026, 5, 25),
        );

    Flashcard card(String q, String a, {List<String> sources = const []}) =>
        Flashcard(question: q, answer: a, sourceNoteIds: sources);

    // ─── Single retrieval (unambiguous) ─────────────────────────────

    test('single retrieved note + uncited card → SOURCE backfilled with '
        'that note id, no content check needed', () {
      // The Mars-moons dry-run shape: model wrote a clean card without
      // SOURCE. With one note, attribution is unambiguous regardless of
      // whether the card text mentions "Mars".
      final retrieved = [RetrievedNote(note: note('mars-1'), score: 0.4)];
      final raw = [card('What are the two moons?', 'Phobos and Deimos')];
      final out = RetrievalService.backfillCardSources(raw, retrieved);
      expect(out.length, 1);
      expect(out.single.sourceNoteIds, ['mars-1']);
    });

    test('already-cited cards are left untouched (no overwriting attribution)',
        () {
      final retrieved = [RetrievedNote(note: note('mars-1'), score: 0.4)];
      final raw = [card('Mars moons?', 'Phobos and Deimos', sources: const ['model-cited-id'])];
      final out = RetrievalService.backfillCardSources(raw, retrieved);
      expect(out.single.sourceNoteIds, ['model-cited-id']);
    });

    test('zero retrieved notes → input unchanged (empty-gate handles this '
        'upstream anyway)', () {
      final raw = [card('Q', 'A')];
      final out = RetrievalService.backfillCardSources(raw, const []);
      expect(out, equals(raw));
      expect(out.single.sourceNoteIds, isEmpty);
    });

    test('empty input → empty output', () {
      final retrieved = [RetrievedNote(note: note('mars-1'), score: 0.4)];
      expect(RetrievalService.backfillCardSources(const [], retrieved),
          isEmpty);
    });

    test('mixed cited + uncited under single-retrieval → only uncited get '
        'backfilled', () {
      final retrieved = [RetrievedNote(note: note('mars-1'), score: 0.4)];
      final raw = [
        card('Q1', 'A1', sources: const ['existing']),
        card('Q2', 'A2'),
        card('Q3', 'A3', sources: const ['another']),
      ];
      final out = RetrievalService.backfillCardSources(raw, retrieved);
      expect(out[0].sourceNoteIds, ['existing']);
      expect(out[1].sourceNoteIds, ['mars-1']);
      expect(out[2].sourceNoteIds, ['another']);
    });

    // ─── Multi-retrieval (content matching) ─────────────────────────

    test('two retrieved notes + cards naming each entity → each card '
        'attributed to its named note (the atmosphere dry-run)', () {
      // Exact shape from 2026-05-25: topic="atmosphere", retrieved Mercury
      // and Venus notes, model wrote 2 cards (no SOURCE), each card's Q+A
      // names its entity.
      final retrieved = [
        RetrievedNote(
            note: note('mercury-1',
                topic: 'Mercury',
                body: 'Mercury has almost no atmosphere; '
                    'temperatures vary from 430°C to -180°C.'),
            score: 0.44),
        RetrievedNote(
            note: note('venus-1',
                topic: 'Venus',
                body: 'Venus has a thick CO2 atmosphere causing runaway '
                    'greenhouse effect; surface ~465°C.'),
            score: 0.41),
      ];
      final raw = [
        card('What is unique about Venus\'s atmosphere?',
            'Venus has a thick atmosphere composed of 96% carbon dioxide.'),
        card('How does Mercury\'s lack of atmosphere affect its environment?',
            'Mercury has almost no atmosphere with extreme temperatures.'),
      ];
      final out = RetrievalService.backfillCardSources(raw, retrieved);
      expect(out[0].sourceNoteIds, ['venus-1']);
      expect(out[1].sourceNoteIds, ['mercury-1']);
    });

    test('multi-retrieval: card mentioning both entities attributes to both',
        () {
      // Edge case: a card that legitimately cites two notes (e.g.
      // "Compare Mercury and Venus atmospheres") should land both ids.
      final retrieved = [
        RetrievedNote(note: note('mercury-1', topic: 'Mercury'), score: 0.4),
        RetrievedNote(note: note('venus-1', topic: 'Venus'), score: 0.39),
      ];
      final raw = [
        card('How do Mercury and Venus differ?',
            'Mercury is hot in day, cold at night; Venus is hot always.'),
      ];
      final out = RetrievalService.backfillCardSources(raw, retrieved);
      expect(out.single.sourceNoteIds, ['mercury-1', 'venus-1']);
    });

    test('multi-retrieval: card mentioning no retrieved entity is left '
        'uncited (drop-uncited will catch it downstream)', () {
      // If the card text doesn't name any retrieved note's topic, we
      // can't honestly attribute. Leave it uncited so cleanCards drops
      // it rather than guessing.
      final retrieved = [
        RetrievedNote(note: note('mercury-1', topic: 'Mercury'), score: 0.4),
        RetrievedNote(note: note('venus-1', topic: 'Venus'), score: 0.39),
      ];
      final raw = [
        card('What is an atmosphere?', 'A layer of gases around a body.'),
      ];
      final out = RetrievalService.backfillCardSources(raw, retrieved);
      expect(out.single.sourceNoteIds, isEmpty);
    });

    test('multi-retrieval content match is case-insensitive', () {
      final retrieved = [
        RetrievedNote(note: note('venus-1', topic: 'Venus'), score: 0.4),
        RetrievedNote(note: note('mars-1', topic: 'Mars'), score: 0.38),
      ];
      final raw = [
        card('What is VENUS like?', 'Hot, with a thick atmosphere.'),
      ];
      final out = RetrievalService.backfillCardSources(raw, retrieved);
      expect(out.single.sourceNoteIds, ['venus-1']);
    });

    test('multi-retrieval: model-cited cards still left untouched', () {
      final retrieved = [
        RetrievedNote(note: note('mercury-1', topic: 'Mercury'), score: 0.4),
        RetrievedNote(note: note('venus-1', topic: 'Venus'), score: 0.39),
      ];
      final raw = [
        card('Venus atmosphere?', 'Thick CO2.',
            sources: const ['model-cited']),
      ];
      final out = RetrievalService.backfillCardSources(raw, retrieved);
      expect(out.single.sourceNoteIds, ['model-cited']);
    });
  });
}
