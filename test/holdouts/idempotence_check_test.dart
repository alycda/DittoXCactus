// Tests for IdempotenceCheck (U15a / R3 + R4).
//
// Pure-Dart math: convergence + idempotence verdicts over StudyNote
// snapshots. The live-device runner under tools/holdout_34/ feeds in
// snapshots captured from DittoService.queryAll; here we feed in
// hand-built fixtures so the math is exercised independently of BLE,
// Ditto, or Cactus.
//
// Coverage matrix (plan §U15a test scenarios):
//   - Happy path (R4): A has T1/T2, B has T3; post-meet both have all three.
//   - Idempotence (R3): re-meet with no edits → no diffs.
//   - Edge: missing from one side (BLE pair flaked) → convergence fails.
//   - Edge: id present on both but different content → diverged.
//   - Edge: re-meet introduced a note (idempotence violation).
//   - Top-k drift: any reorder counts; lengths can disagree.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/holdouts/idempotence_check.dart';
import 'package:mesh_rag/models/study_note.dart';

void main() {
  // Stable fixture builder. Same `(contributor, topic, createdAt)` →
  // same UUIDv5 id every time, so test assertions on diff sets are
  // bitwise-reproducible.
  StudyNote note(
    String contributor,
    String topic, {
    String body = 'body',
    List<String> tags = const ['t'],
    List<double> embedding = const [0.1, 0.2, 0.3],
    List<String> acceptedBy = const [],
  }) {
    return StudyNote.seed(
      contributor: contributor,
      topic: topic,
      createdAt: DateTime.utc(2026, 5, 25, 12, 0, 0),
      tags: tags,
      body: body,
      embedding: embedding,
      acceptedBy: acceptedBy,
    );
  }

  group('IdempotenceCheck.detectConvergence (R4 bidirectional merge)', () {
    test('happy path: A={T1,T2}, B={T3} → post-meet both have all three', () {
      final t1 = note('a', 'T1');
      final t2 = note('a', 'T2');
      final t3 = note('b', 'T3');

      final result = IdempotenceCheck.detectConvergence(
        preA: [t1, t2],
        preB: [t3],
        postA: [t1, t2, t3],
        postB: [t1, t2, t3],
      );

      expect(result.pass, isTrue);
      expect(result.expectedUnionSize, 3);
      expect(result.actualASize, 3);
      expect(result.actualBSize, 3);
      expect(result.missingFromA, isEmpty);
      expect(result.missingFromB, isEmpty);
      expect(result.divergedIds, isEmpty);
    });

    test('disjoint corpora converge to symmetric union', () {
      // R4's load-bearing case: A and B have *zero* overlap pre-meet,
      // post-meet both hold the full union. This is the writeup's
      // "moment of magic" frame.
      final aOnly = [note('a', 'jupiter-moons'), note('a', 'saturn-rings')];
      final bOnly = [note('b', 'mars-polar-ice')];
      final union = [...aOnly, ...bOnly];

      final result = IdempotenceCheck.detectConvergence(
        preA: aOnly,
        preB: bOnly,
        postA: union,
        postB: union,
      );

      expect(result.pass, isTrue);
      expect(result.expectedUnionSize, 3);
    });

    test('R4 FAIL: post-A is missing one of B\'s notes', () {
      final t1 = note('a', 'T1');
      final t3 = note('b', 'T3');
      final t4 = note('b', 'T4');

      // Post-A picked up T3 but lost T4 — sync stalled before drain.
      final result = IdempotenceCheck.detectConvergence(
        preA: [t1],
        preB: [t3, t4],
        postA: [t1, t3],
        postB: [t1, t3, t4],
      );

      expect(result.pass, isFalse);
      expect(result.missingFromA, [t4.id]);
      expect(result.missingFromB, isEmpty);
      expect(result.divergedIds, isEmpty,
          reason: 't4 is missing from A entirely; it\'s a miss, not a diverge');
    });

    test('R4 FAIL: same id on both sides but content disagrees (diverged)', () {
      final t1 = note('a', 'T1', body: 'A-version');
      final t1Other = note('a', 'T1', body: 'B-version'); // same id (UUIDv5
      // over (contributor, topic, createdAt) collides because we pass the
      // identical seed), but body differs — this is exactly the CRDT-merge
      // sanity case we want to flag.

      // Sanity: ids match.
      expect(t1.id, t1Other.id);

      final result = IdempotenceCheck.detectConvergence(
        preA: [t1],
        preB: [t1Other],
        postA: [t1],
        postB: [t1Other],
      );

      expect(result.pass, isFalse);
      expect(result.missingFromA, isEmpty);
      expect(result.missingFromB, isEmpty);
      expect(result.divergedIds, [t1.id]);
    });

    test('both corpora empty → trivially passes', () {
      final result = IdempotenceCheck.detectConvergence(
        preA: const [],
        preB: const [],
        postA: const [],
        postB: const [],
      );

      expect(result.pass, isTrue);
      expect(result.expectedUnionSize, 0);
    });

    test('A has notes, B starts empty → both end up holding A\'s notes', () {
      final t1 = note('a', 'T1');
      final t2 = note('a', 'T2');

      final result = IdempotenceCheck.detectConvergence(
        preA: [t1, t2],
        preB: const [],
        postA: [t1, t2],
        postB: [t1, t2],
      );

      expect(result.pass, isTrue);
      expect(result.missingFromA, isEmpty);
      expect(result.missingFromB, isEmpty);
    });

    test('diverged ids are sorted lex-asc for stable verdict diffs', () {
      final base1 = note('a', 'TA', body: 'v1');
      final base2 = note('a', 'TB', body: 'v1');
      final base3 = note('a', 'TC', body: 'v1');
      final base1Other = base1.copyWith(body: 'v2');
      final base2Other = base2.copyWith(body: 'v2');
      final base3Other = base3.copyWith(body: 'v2');

      final result = IdempotenceCheck.detectConvergence(
        preA: [base1, base2, base3],
        preB: [base1Other, base2Other, base3Other],
        postA: [base1, base2, base3],
        postB: [base1Other, base2Other, base3Other],
      );

      expect(result.divergedIds, hasLength(3));
      final sorted = [...result.divergedIds]..sort();
      expect(result.divergedIds, sorted);
    });
  });

  group('IdempotenceCheck.detectIdempotence (R3 sync idempotence)', () {
    final t1 = StudyNote.seed(
      contributor: 'a',
      topic: 'T1',
      createdAt: DateTime.utc(2026, 5, 25),
      tags: const ['x'],
      body: 'b1',
      embedding: const [0.1, 0.2, 0.3],
    );
    final t2 = StudyNote.seed(
      contributor: 'a',
      topic: 'T2',
      createdAt: DateTime.utc(2026, 5, 25),
      tags: const ['y'],
      body: 'b2',
      embedding: const [0.4, 0.5, 0.6],
    );
    final t3 = StudyNote.seed(
      contributor: 'b',
      topic: 'T3',
      createdAt: DateTime.utc(2026, 5, 25),
      tags: const ['z'],
      body: 'b3',
      embedding: const [0.7, 0.8, 0.9],
    );

    test('happy path: re-meet with no edits → all three axes stable', () {
      final result = IdempotenceCheck.detectIdempotence(
        postMeet: [t1, t2, t3],
        postRemeet: [t1, t2, t3],
        topKPreRemeet: [t1.id, t3.id, t2.id],
        topKPostRemeet: [t1.id, t3.id, t2.id],
      );

      expect(result.pass, isTrue);
      expect(result.idsAdded, isEmpty);
      expect(result.idsRemoved, isEmpty);
      expect(result.contentChangedIds, isEmpty);
      expect(result.topKDriftCount, 0);
      expect(result.topKLength, 3);
    });

    test('FAIL: re-meet adds a note (note count went up)', () {
      // R3 says re-meet with no edits → no adds. If a phantom note
      // shows up post-re-meet, sync isn't idempotent.
      final result = IdempotenceCheck.detectIdempotence(
        postMeet: [t1, t2],
        postRemeet: [t1, t2, t3],
        topKPreRemeet: [t1.id],
        topKPostRemeet: [t1.id],
      );

      expect(result.pass, isFalse);
      expect(result.idsAdded, [t3.id]);
      expect(result.idsRemoved, isEmpty);
    });

    test('FAIL: re-meet removed a note', () {
      final result = IdempotenceCheck.detectIdempotence(
        postMeet: [t1, t2, t3],
        postRemeet: [t1, t2],
        topKPreRemeet: [t1.id],
        topKPostRemeet: [t1.id],
      );

      expect(result.pass, isFalse);
      expect(result.idsAdded, isEmpty);
      expect(result.idsRemoved, [t3.id]);
    });

    test('FAIL: same id but content changed (e.g., embedding re-baked)', () {
      final t1Drifted = t1.copyWith(embedding: const [0.99, 0.99, 0.99]);

      final result = IdempotenceCheck.detectIdempotence(
        postMeet: [t1, t2],
        postRemeet: [t1Drifted, t2],
        topKPreRemeet: [t1.id, t2.id],
        topKPostRemeet: [t1.id, t2.id],
      );

      expect(result.pass, isFalse);
      expect(result.contentChangedIds, [t1.id]);
    });

    test('top-k reorder counts as drift even when id sets are equal', () {
      final result = IdempotenceCheck.detectIdempotence(
        postMeet: [t1, t2, t3],
        postRemeet: [t1, t2, t3],
        topKPreRemeet: [t1.id, t2.id, t3.id],
        topKPostRemeet: [t1.id, t3.id, t2.id], // swap pos 1↔2
      );

      expect(result.pass, isFalse);
      expect(result.topKDriftCount, 2);
      expect(result.idsAdded, isEmpty);
      expect(result.contentChangedIds, isEmpty);
    });

    test('top-k length mismatch contributes |Δlen| to drift', () {
      final result = IdempotenceCheck.detectIdempotence(
        postMeet: [t1, t2, t3],
        postRemeet: [t1, t2, t3],
        topKPreRemeet: [t1.id, t2.id, t3.id],
        topKPostRemeet: [t1.id, t2.id],
      );

      expect(result.pass, isFalse);
      expect(result.topKDriftCount, 1, reason: 'one fewer position');
      expect(result.topKLength, 2);
    });

    test('empty post-meet AND post-remeet → trivially passes', () {
      final result = IdempotenceCheck.detectIdempotence(
        postMeet: const [],
        postRemeet: const [],
        topKPreRemeet: const [],
        topKPostRemeet: const [],
      );

      expect(result.pass, isTrue);
    });
  });

  group('IdempotenceCheck.orderedDiffCount (drift counter)', () {
    test('identical lists → 0 drift', () {
      expect(
        IdempotenceCheck.orderedDiffCountForTest(['a', 'b', 'c'], ['a', 'b', 'c']),
        0,
      );
    });

    test('single position swap counts as 2 drifts (each position diff)', () {
      expect(
        IdempotenceCheck.orderedDiffCountForTest(['a', 'b', 'c'], ['a', 'c', 'b']),
        2,
      );
    });

    test('shorter second list contributes |Δlen|', () {
      expect(
        IdempotenceCheck.orderedDiffCountForTest(['a', 'b', 'c'], ['a', 'b']),
        1,
      );
    });

    test('longer second list contributes |Δlen|', () {
      expect(
        IdempotenceCheck.orderedDiffCountForTest(['a'], ['a', 'b', 'c']),
        2,
      );
    });
  });

  group('IdempotenceCheck.buildReport (verdict JSON shape)', () {
    test('round-trips through jsonEncode/Decode without loss', () {
      // The verdict CLI emits this JSON to stdout / a per-run file.
      // U17's recorded artifact reviewer parses it. Lock the shape
      // here so a future field rename surfaces as a deliberate change.
      const convergence = ConvergenceResult(
        pass: true,
        expectedUnionSize: 3,
        actualASize: 3,
        actualBSize: 3,
        missingFromA: [],
        missingFromB: [],
        divergedIds: [],
      );
      const idempotence = IdempotenceResult(
        pass: true,
        idsAdded: [],
        idsRemoved: [],
        contentChangedIds: [],
        topKDriftCount: 0,
        topKLength: 5,
      );

      final report = IdempotenceCheck.buildReport(
        convergence: convergence,
        idempotence: idempotence,
      );
      expect(report['test'], 'holdout_34');
      expect(report['pass'], isTrue);

      final encoded = jsonEncode(report);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['pass'], isTrue);
      expect((decoded['convergence'] as Map)['expected_union_size'], 3);
      expect((decoded['idempotence'] as Map)['topk_length'], 5);
    });

    test('combined pass = convergence.pass AND idempotence.pass', () {
      const failConv = ConvergenceResult(
        pass: false,
        expectedUnionSize: 3,
        actualASize: 2,
        actualBSize: 3,
        missingFromA: ['x'],
        missingFromB: [],
        divergedIds: [],
      );
      const passIdemp = IdempotenceResult(
        pass: true,
        idsAdded: [],
        idsRemoved: [],
        contentChangedIds: [],
        topKDriftCount: 0,
        topKLength: 3,
      );
      final report = IdempotenceCheck.buildReport(
        convergence: failConv,
        idempotence: passIdemp,
      );
      expect(report['pass'], isFalse,
          reason: 'one axis failing must fail the combined verdict');
    });
  });
}
