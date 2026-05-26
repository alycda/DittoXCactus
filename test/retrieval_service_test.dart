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
}
