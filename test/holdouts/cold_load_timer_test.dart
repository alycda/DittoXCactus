// Tests for ColdLoadTimer (U14 / R5 instrument).
//
// The pure-Dart parts here are buildReport (JSON shape) and the
// expectedPhases contract. The Stopwatch-backed parts (start/mark
// elapsed math) are exercised with controlled durations via brief
// async sleeps — enough to verify the API doesn't drop data, without
// asserting on absolute milliseconds (which would be flaky in CI).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/holdouts/cold_load_timer.dart';

void main() {
  group('ColdLoadTimer.buildReport (pure JSON shape)', () {
    test('happy path: synthetic phases → well-formed report', () {
      final report = ColdLoadTimer.buildReport(
        device: 'pixel-6a',
        totalMs: 8500,
        phases: const {
          'app_init_done': 100,
          'ditto_initialized': 250,
          'cactus_initialized': 8200,
          'first_card_displayed': 8500,
        },
      );

      expect(report['device'], 'pixel-6a');
      expect(report['total_ms'], 8500);
      expect(report['phases'], hasLength(4));
      expect(report['phases']['app_init_done'], 100);
      expect(report['phases']['first_card_displayed'], 8500);
    });

    test('serializes to JSON cleanly (Map<String, dynamic> contract)', () {
      // Per plan §U14: report is "logged to console + a per-launch file".
      // The file consumer parses with jsonDecode, so jsonEncode must
      // round-trip without throwing.
      final report = ColdLoadTimer.buildReport(
        device: 'iphone-14-pro',
        totalMs: 7200,
        phases: const {
          'app_init_done': 50,
          'embeddings_backfilled': 7100,
        },
      );
      final encoded = jsonEncode(report);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['device'], 'iphone-14-pro');
      expect(decoded['total_ms'], 7200);
      expect((decoded['phases'] as Map)['embeddings_backfilled'], 7100);
    });

    test('empty phases map → report still well-formed (boot died early)',
        () {
      // If the boot crashed before any mark() fired, the report should
      // still be a valid JSON document — useful as evidence of "boot
      // never started".
      final report = ColdLoadTimer.buildReport(
        device: 'pixel-6a',
        totalMs: 0,
        phases: const {},
      );
      expect(report['phases'], isEmpty);
      expect(() => jsonEncode(report), returnsNormally);
    });

    test('report Map is decoupled from the input phases Map '
        '(caller mutation does not leak in)', () {
      // Important: the report is logged + potentially passed across
      // boundaries. If the caller mutates their phases dict after the
      // report builds, the logged report should not change.
      final phases = <String, int>{'app_init_done': 100};
      final report = ColdLoadTimer.buildReport(
        device: 'pixel-6a',
        totalMs: 100,
        phases: phases,
      );
      phases['ditto_initialized'] = 999; // mutate after build
      expect(report['phases'], hasLength(1));
      expect((report['phases'] as Map).containsKey('ditto_initialized'),
          isFalse);
    });
  });

  group('ColdLoadTimer.expectedPhases (contract for boot-path readers)', () {
    test('all expected phase markers are listed in plan-spec order', () {
      // Pinned so a future edit to the marker list shows up here as a
      // deliberate change. Plan §U14 Approach is the source of truth.
      expect(ColdLoadTimer.expectedPhases, [
        'app_init_done',
        'ditto_initialized',
        'sync_started',
        'corpus_seeded',
        'cactus_completion_downloaded',
        'cactus_embedding_downloaded',
        'cactus_initialized',
        'embeddings_backfilled',
        'first_query_submitted',
        'first_top_k_returned',
        'first_card_buffered',
        'first_card_displayed',
      ]);
    });

    test('no duplicates in the expected-phase contract', () {
      final set = ColdLoadTimer.expectedPhases.toSet();
      expect(set.length, ColdLoadTimer.expectedPhases.length);
    });
  });

  group('ColdLoadTimer state machine (mark/start/report integration)', () {
    setUp(() => ColdLoadTimer.instance.reset());

    test('mark() before start() is a no-op (does not crash, does not '
        'record)', () {
      // Defensive: hot-reload paths or integration test setups may call
      // mark() without ever calling start(). Don't let that blow up.
      ColdLoadTimer.instance.mark('app_init_done');
      final report = ColdLoadTimer.instance.report(device: 'test');
      expect(report['phases'], isEmpty);
      expect(report['total_ms'], 0);
    });

    test('start() then mark() records the phase with non-negative ms', () {
      ColdLoadTimer.instance.start();
      ColdLoadTimer.instance.mark('app_init_done');
      final report = ColdLoadTimer.instance.report(device: 'test');
      expect(report['phases'], hasLength(1));
      expect(report['phases']['app_init_done'], greaterThanOrEqualTo(0));
    });

    test('phases are recorded in monotonic order (each mark has elapsed '
        '>= the previous)', () async {
      ColdLoadTimer.instance.start();
      ColdLoadTimer.instance.mark('app_init_done');
      // Sleep enough that the Stopwatch should advance even on a fast CI
      // host. We're not asserting on absolute ms — just monotonicity.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      ColdLoadTimer.instance.mark('ditto_initialized');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      ColdLoadTimer.instance.mark('cactus_initialized');

      final phases = ColdLoadTimer.instance.report(device: 'test')['phases']
          as Map<String, dynamic>;
      final t0 = phases['app_init_done'] as int;
      final t1 = phases['ditto_initialized'] as int;
      final t2 = phases['cactus_initialized'] as int;
      expect(t1, greaterThanOrEqualTo(t0));
      expect(t2, greaterThanOrEqualTo(t1));
    });

    test('first-occurrence wins: re-marking the same phase is ignored', () async {
      // Boot retry semantics — if a phase is reached again on a retry,
      // we want the original (cold) timing, not the retry (which
      // would be faster because Cactus weights are already cached).
      ColdLoadTimer.instance.start();
      ColdLoadTimer.instance.mark('app_init_done');
      final first = (ColdLoadTimer.instance.report()['phases']
          as Map<String, dynamic>)['app_init_done'] as int;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      ColdLoadTimer.instance.mark('app_init_done'); // re-mark
      final second = (ColdLoadTimer.instance.report()['phases']
          as Map<String, dynamic>)['app_init_done'] as int;
      expect(second, first, reason: 'second mark must not overwrite first');
    });

    test('start() resets prior phase data (fresh measurement)', () {
      ColdLoadTimer.instance.start();
      ColdLoadTimer.instance.mark('app_init_done');
      expect((ColdLoadTimer.instance.report()['phases'] as Map), hasLength(1));
      ColdLoadTimer.instance.start(); // fresh measurement
      expect((ColdLoadTimer.instance.report()['phases'] as Map), isEmpty);
    });

    test('hasCompletedAllExpectedPhases: false until every marker fired', () {
      ColdLoadTimer.instance.start();
      expect(ColdLoadTimer.instance.hasCompletedAllExpectedPhases, isFalse);
      for (final phase in ColdLoadTimer.expectedPhases) {
        ColdLoadTimer.instance.mark(phase);
      }
      expect(ColdLoadTimer.instance.hasCompletedAllExpectedPhases, isTrue);
    });

    test('report() with default device returns "unknown"', () {
      ColdLoadTimer.instance.start();
      final report = ColdLoadTimer.instance.report();
      expect(report['device'], 'unknown');
    });
  });
}
