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
      expect(RetrievalService.defaultK, 5);
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
  });

  group('RetrievalService.backfillSingleRetrievalSource', () {
    // The 2026-05-25 dry-run captured this exact shape: Qwen produced
    // a clean on-topic Q+A about Mars's moons from one retrieved Mars
    // note, then the stream ended before it could write SOURCE. The
    // card was real and verifiably grounded — the attribution is just
    // implicit. Backfill makes it explicit so cleanCards keeps it.

    StudyNote note(String id) => StudyNote(
          id: id,
          topic: 'Mars',
          contributor: 'phone-a',
          body: 'Mars has two small moons.',
          tags: const [],
          embedding: const [],
          createdAt: DateTime.utc(2026, 5, 25),
        );

    Flashcard card(String q, String a, {List<String> sources = const []}) =>
        Flashcard(question: q, answer: a, sourceNoteIds: sources);

    test('single retrieved note + uncited card → SOURCE backfilled with '
        'that note id', () {
      final retrieved = [RetrievedNote(note: note('mars-1'), score: 0.4)];
      final raw = [card('Mars moons?', 'Phobos and Deimos')];
      final out =
          RetrievalService.backfillSingleRetrievalSource(raw, retrieved);
      expect(out.length, 1);
      expect(out.single.sourceNoteIds, ['mars-1']);
    });

    test('already-cited cards are left untouched (no overwriting attribution)',
        () {
      final retrieved = [RetrievedNote(note: note('mars-1'), score: 0.4)];
      final raw = [card('Mars moons?', 'Phobos and Deimos', sources: const ['model-cited-id'])];
      final out =
          RetrievalService.backfillSingleRetrievalSource(raw, retrieved);
      expect(out.single.sourceNoteIds, ['model-cited-id']);
    });

    test('zero retrieved notes → input unchanged (empty-gate handles this '
        'upstream anyway)', () {
      final raw = [card('Q', 'A')];
      final out =
          RetrievalService.backfillSingleRetrievalSource(raw, const []);
      expect(out, equals(raw));
      expect(out.single.sourceNoteIds, isEmpty);
    });

    test('multiple retrieved notes → input unchanged (cannot disambiguate '
        'which one to attribute to)', () {
      final retrieved = [
        RetrievedNote(note: note('mars-1'), score: 0.4),
        RetrievedNote(note: note('mars-2'), score: 0.38),
      ];
      final raw = [card('Mars moons?', 'Phobos and Deimos')];
      final out =
          RetrievalService.backfillSingleRetrievalSource(raw, retrieved);
      expect(out.single.sourceNoteIds, isEmpty,
          reason:
              '>1 retrieved means attribution is ambiguous — drop-uncited '
              'should still fire downstream rather than guessing.');
    });

    test('empty input → empty output', () {
      final retrieved = [RetrievedNote(note: note('mars-1'), score: 0.4)];
      expect(
          RetrievalService.backfillSingleRetrievalSource(const [], retrieved),
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
      final out =
          RetrievalService.backfillSingleRetrievalSource(raw, retrieved);
      expect(out[0].sourceNoteIds, ['existing']);
      expect(out[1].sourceNoteIds, ['mars-1']);
      expect(out[2].sourceNoteIds, ['another']);
    });
  });
}
