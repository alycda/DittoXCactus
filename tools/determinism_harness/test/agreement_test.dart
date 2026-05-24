// Pure-Dart tests for the determinism harness math.
// Run from inside tools/determinism_harness/ with:  flutter test
//
// The on-device measurement code (integration_test/measure_test.dart) is what
// has to work in production; this file is the safety net that ensures the
// agreement-rate calculation is not where bugs hide. Test-first per the plan's
// Execution note on U1.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:determinism_harness/agreement.dart';

void main() {
  group('cosineSimilarity', () {
    test('returns 1.0 for identical unit vectors', () {
      expect(cosineSimilarity([1.0, 0.0], [1.0, 0.0]), closeTo(1.0, 1e-12));
    });

    test('returns 0.0 for orthogonal vectors', () {
      expect(cosineSimilarity([1.0, 0.0], [0.0, 1.0]), closeTo(0.0, 1e-12));
    });

    test('returns -1.0 for antiparallel unit vectors', () {
      expect(cosineSimilarity([1.0, 0.0], [-1.0, 0.0]), closeTo(-1.0, 1e-12));
    });

    test('is scale-invariant', () {
      final a = cosineSimilarity([1.0, 2.0, 3.0], [2.0, 4.0, 6.0]);
      expect(a, closeTo(1.0, 1e-12));
    });

    test('throws on mismatched dimensions', () {
      expect(() => cosineSimilarity([1.0, 0.0], [1.0, 0.0, 0.0]),
          throwsA(isA<ArgumentError>()));
    });

    test('returns 0.0 when one side is the zero vector', () {
      // A zero vector has no direction; treat similarity as 0 rather than NaN.
      expect(cosineSimilarity([0.0, 0.0], [1.0, 0.0]), 0.0);
    });
  });

  group('topK', () {
    test('happy path: returns scores sorted descending', () {
      final result = topK(
        queryEmbedding: [1.0, 0.0],
        passageEmbeddings: {
          'P01': [1.0, 0.0],
          'P02': [0.5, 0.5],
          'P03': [0.0, 1.0],
        },
        k: 3,
      );
      expect(result.map((e) => e.id).toList(), ['P01', 'P02', 'P03']);
      expect(result.first.score, closeTo(1.0, 1e-12));
    });

    test('returns at most k entries', () {
      final result = topK(
        queryEmbedding: [1.0, 0.0],
        passageEmbeddings: {
          'P01': [1.0, 0.0],
          'P02': [0.5, 0.5],
          'P03': [0.0, 1.0],
        },
        k: 2,
      );
      expect(result.length, 2);
      expect(result.map((e) => e.id).toList(), ['P01', 'P02']);
    });

    test('applies (score desc, id asc) tie-break — load-bearing for R2', () {
      // P03 and P07 have identical cosine to the query; with the tie-break
      // policy, the lower id (P03) must come first on every device.
      final result = topK(
        queryEmbedding: [1.0, 0.0],
        passageEmbeddings: {
          'P07': [0.9, 0.1],
          'P03': [0.9, 0.1],
          'P05': [0.1, 0.9],
        },
        k: 3,
      );
      expect(result.map((e) => e.id).toList(), ['P03', 'P07', 'P05']);
    });

    test('insertion order does not affect output (determinism invariant)', () {
      // Two map insertion orders → identical top-k. If the implementation
      // relies on hash-map iteration order, this catches it.
      final embeddings1 = <String, List<double>>{
        'P07': [0.9, 0.1],
        'P03': [0.9, 0.1],
        'P05': [0.1, 0.9],
      };
      final embeddings2 = <String, List<double>>{
        'P05': [0.1, 0.9],
        'P03': [0.9, 0.1],
        'P07': [0.9, 0.1],
      };
      final r1 = topK(
          queryEmbedding: [1.0, 0.0],
          passageEmbeddings: embeddings1,
          k: 3);
      final r2 = topK(
          queryEmbedding: [1.0, 0.0],
          passageEmbeddings: embeddings2,
          k: 3);
      expect(r1.map((e) => e.id).toList(),
          equals(r2.map((e) => e.id).toList()));
    });

    test('drops passages whose embedding dimension differs from the query', () {
      // R2 escape hatch: model swap mid-corpus must not crash; mismatched
      // dimensions are skipped, not raised.
      final result = topK(
        queryEmbedding: [1.0, 0.0],
        passageEmbeddings: {
          'P01': [1.0, 0.0],
          'P02': [1.0, 0.0, 0.0], // wrong dimension; should be skipped
          'P03': [0.5, 0.5],
        },
        k: 3,
      );
      expect(result.map((e) => e.id).toList(), ['P01', 'P03']);
    });
  });

  group('agreementRate', () {
    test('identical top-k → 1.0', () {
      final a = {
        'Q01': ['P01', 'P02', 'P03'],
        'Q02': ['P05', 'P06', 'P07'],
      };
      final b = {
        'Q01': ['P01', 'P02', 'P03'],
        'Q02': ['P05', 'P06', 'P07'],
      };
      final result = agreementRate(a, b, k: 3);
      expect(result.rate, 1.0);
      expect(result.disagreements, isEmpty);
      expect(result.matchedQueries, 2);
      expect(result.totalQueries, 2);
    });

    test('one disagreement out of two → 0.5; disagreement is reported', () {
      final a = {
        'Q01': ['P01', 'P02', 'P03'],
        'Q02': ['P05', 'P06', 'P07'],
      };
      final b = {
        'Q01': ['P01', 'P02', 'P03'],
        'Q02': ['P05', 'P07', 'P06'], // within-top-k reordering
      };
      final result = agreementRate(a, b, k: 3);
      expect(result.rate, 0.5);
      expect(result.disagreements, ['Q02']);
    });

    test('shorter than k is still comparable when both sides are short', () {
      final a = {
        'Q01': ['P01', 'P02'],
      };
      final b = {
        'Q01': ['P01', 'P02'],
      };
      final result = agreementRate(a, b, k: 5);
      expect(result.rate, 1.0);
    });

    test('only compares the first k positions when lists are longer', () {
      final a = {
        'Q01': ['P01', 'P02', 'P03', 'P04', 'P05', 'P06'],
      };
      final b = {
        'Q01': ['P01', 'P02', 'P03', 'P04', 'P05', 'P99'], // diff at pos 6
      };
      final result = agreementRate(a, b, k: 5);
      expect(result.rate, 1.0);
    });

    test('queries present only on one side count as disagreements', () {
      final a = {
        'Q01': ['P01'],
        'Q02': ['P05'],
      };
      final b = {
        'Q01': ['P01'],
      };
      final result = agreementRate(a, b, k: 5);
      expect(result.rate, 0.5);
      expect(result.disagreements, ['Q02']);
    });

    test('threshold helper flags when between 0.85 and 0.95 (diagnostic band)',
        () {
      // Plan: "when agreement_rate is between 0.85 and 0.95, dump the offending
      // queries (so a human can decide whether to expand the fixture or
      // re-engineer the kernel pin)."
      expect(isDiagnosticBand(0.84), false);
      expect(isDiagnosticBand(0.85), true);
      expect(isDiagnosticBand(0.90), true);
      expect(isDiagnosticBand(0.94999), true);
      expect(isDiagnosticBand(0.95), false); // gate clears at >= 0.95
      expect(isDiagnosticBand(1.0), false);
    });

    test('clears the R2 gate at exactly 0.95', () {
      expect(clearsR2Gate(0.949999), false);
      expect(clearsR2Gate(0.95), true);
      expect(clearsR2Gate(1.0), true);
    });
  });

  group('parseFixture', () {
    test('parses the checked-in queries.json', () {
      final file = File('fixtures/queries.json');
      expect(file.existsSync(), isTrue,
          reason: 'Run from tools/determinism_harness/ directory.');
      final fixture = parseFixture(file.readAsStringSync());
      expect(fixture.queries.length, 20);
      expect(fixture.passages.length, 20);
      expect(fixture.k, 5);
    });

    test('every query points at a real passage id (expectedTop1)', () {
      final file = File('fixtures/queries.json');
      final fixture = parseFixture(file.readAsStringSync());
      final passageIds = fixture.passages.map((p) => p.id).toSet();
      for (final q in fixture.queries) {
        expect(passageIds.contains(q.expectedTop1), isTrue,
            reason: 'Query ${q.id} references unknown passage ${q.expectedTop1}');
      }
    });

    test('all passage ids are unique', () {
      final file = File('fixtures/queries.json');
      final fixture = parseFixture(file.readAsStringSync());
      final ids = fixture.passages.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all query ids are unique', () {
      final file = File('fixtures/queries.json');
      final fixture = parseFixture(file.readAsStringSync());
      final ids = fixture.queries.map((q) => q.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('error path: malformed JSON surfaces a clear FormatException', () {
      expect(() => parseFixture('{not json'),
          throwsA(isA<FormatException>()));
    });

    test('error path: missing required field surfaces ArgumentError', () {
      final bad = jsonEncode({
        'passages': [
          {'id': 'P01', 'text': 'a passage'},
        ],
        // queries omitted
      });
      expect(() => parseFixture(bad), throwsA(isA<ArgumentError>()));
    });
  });

  group('end-to-end with synthetic embeddings (no Cactus)', () {
    // The pure-math harness should clear the gate when we hand it bitwise-identical
    // embeddings on both sides. This proves the math + the comparator are sound;
    // the on-device test (integration_test/run_test.dart) is what proves the
    // Cactus pipeline holds determinism in practice.
    test('identical synthetic embeddings → 1.0 agreement on full fixture', () {
      final file = File('fixtures/queries.json');
      final fixture = parseFixture(file.readAsStringSync());

      // Synthetic per-cluster embedding: each cluster gets a unit vector along
      // a distinct axis, so intra-cluster similarity = 1 and inter-cluster = 0.
      final clusters = fixture.clusters;
      List<double> axisFor(String cluster) {
        final v = List<double>.filled(clusters.length, 0.0);
        v[clusters.indexOf(cluster)] = 1.0;
        return v;
      }

      final passageEmbeddings = {
        for (final p in fixture.passages) p.id: axisFor(p.cluster)
      };

      final perQueryTopK = <String, List<String>>{};
      for (final q in fixture.queries) {
        final entries = topK(
          queryEmbedding: axisFor(q.cluster),
          passageEmbeddings: passageEmbeddings,
          k: fixture.k,
        );
        perQueryTopK[q.id] = entries.map((e) => e.id).toList();
      }

      // Both "devices" produce the same synthetic embeddings, so the harness
      // must report perfect agreement.
      final result = agreementRate(perQueryTopK, perQueryTopK, k: fixture.k);
      expect(result.rate, 1.0);
      expect(result.disagreements, isEmpty);

      // Spot-check: top-1 must land in the query's own cluster. (Axis-per-
      // cluster makes all cluster-mates tie at cosine=1.0, so the tie-break
      // picks the alphabetically-first cluster-mate, not necessarily the
      // fixture's expectedTop1 — that hypothesis is for real Cactus
      // embeddings and is verified by the on-device run, not here.)
      final passageById = {for (final p in fixture.passages) p.id: p};
      for (final q in fixture.queries) {
        final top1Cluster = passageById[perQueryTopK[q.id]!.first]!.cluster;
        expect(top1Cluster, q.cluster,
            reason: 'Synthetic top-1 left ${q.id}\'s cluster');
      }
    });

    test('one device flipping a within-top-k pair surfaces as a disagreement',
        () {
      // Simulates a non-deterministic tie-break (the exact bug R2 is guarding
      // against). If both devices use the same tie-break, this never happens;
      // if one drifts, agreement drops below 1.0 and we can localize the
      // offending query.
      final a = {
        'Q01': ['P01', 'P02', 'P03', 'P04', 'P05'],
        'Q02': ['P10', 'P11', 'P12', 'P13', 'P14'],
      };
      final b = {
        'Q01': ['P01', 'P02', 'P03', 'P04', 'P05'],
        'Q02': ['P10', 'P12', 'P11', 'P13', 'P14'], // 11 and 12 swapped
      };
      final result = agreementRate(a, b, k: 5);
      expect(result.rate, 0.5);
      expect(result.disagreements, ['Q02']);
    });
  });
}
