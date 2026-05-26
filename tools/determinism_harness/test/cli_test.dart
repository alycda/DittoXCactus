// CLI behavior tests for the determinism-harness `run.dart` entry.
//
// The math layer is exercised in agreement_test.dart; this file pins the
// surface contract the on-device flow + CI integration depend on:
//   - subcommand routing (check / check-baseline / unknown)
//   - exit codes (0 / 1 / 2) under each shape of input
//   - `--ci` / `--json` produces a parseable JSON line on stdout
//   - missing-baseline emits an actionable error message
//
// Tests run with BufferCliIO so stdout/stderr are captured without going to
// the test runner's console. No subprocess spawning — runs in-isolate.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:determinism_harness/cli.dart';
import 'package:determinism_harness/output_format.dart';

void main() {
  group('runCli — usage / dispatch', () {
    test('no args → prints usage on stdout, exit 2', () {
      final io = BufferCliIO();
      final code = runCli(const [], io);
      expect(code, 2);
      expect(io.out.toString(), contains('Usage:'));
    });

    test('--help → prints usage on stdout, exit 2', () {
      final io = BufferCliIO();
      final code = runCli(const ['--help'], io);
      expect(code, 2);
      expect(io.out.toString(), contains('Usage:'));
    });

    test('unknown subcommand → error on stderr, exit 2', () {
      final io = BufferCliIO();
      final code = runCli(const ['bogus'], io);
      expect(code, 2);
      expect(io.err.toString(), contains('unknown subcommand "bogus"'));
    });

    test('check with wrong arg count → error on stderr, exit 2', () {
      final io = BufferCliIO();
      final code = runCli(const ['check', 'only-one.json'], io);
      expect(code, 2);
      expect(io.err.toString(), contains('exactly 2 positional args'));
    });

    test('check-baseline with wrong arg count → error on stderr, exit 2', () {
      final io = BufferCliIO();
      final code = runCli(
          const ['check-baseline', 'only-one.json'], io);
      expect(code, 2);
      expect(io.err.toString(), contains('exactly 2 positional args'));
    });
  });

  group('runCli — check (two-device cross-platform)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('cli_check_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('identical inputs → rate 1.0, exit 0', () {
      final path = _writeDeviceJson(tmp, 'ios.json', device: 'ios');
      final code = runCli(['check', path, path], BufferCliIO());
      expect(code, 0);
    });

    test('diverged inputs below 0.95 → exit 1, prints disagreeing queries', () {
      final aPath = _writeDeviceJson(tmp, 'ios.json',
          device: 'ios', topKByQ: const {'Q01': ['P01']});
      final bPath = _writeDeviceJson(tmp, 'android.json',
          device: 'android', topKByQ: const {'Q01': ['P99']});
      final io = BufferCliIO();
      final code = runCli(['check', aPath, bPath], io);
      expect(code, 1);
      expect(io.out.toString(), contains('Q01'));
      expect(io.out.toString(), contains('FAIL'));
      expect(io.err.toString(), contains('R2 gate failed'));
    });

    test('missing file → exit 2 with file-not-found error', () {
      final io = BufferCliIO();
      final code = runCli(
          ['check', '${tmp.path}/missing.json', '${tmp.path}/also-missing.json'],
          io);
      expect(code, 2);
      expect(io.err.toString(), contains('not found'));
    });

    test('malformed JSON → exit 2 with format error', () {
      final bad = File('${tmp.path}/bad.json')..writeAsStringSync('{not json');
      final io = BufferCliIO();
      final code = runCli(['check', bad.path, bad.path], io);
      expect(code, 2);
      expect(io.err.toString(), contains('malformed'));
    });

    test('--ci → emits a single parseable JSON line on stdout', () {
      final path = _writeDeviceJson(tmp, 'ios.json', device: 'ios');
      final io = BufferCliIO();
      final code = runCli(['check', path, path, '--ci'], io);
      expect(code, 0);

      final lines = io.out
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 1,
          reason: '--ci should print exactly one JSON line; got: ${io.out}');

      final parsed = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(parsed['mode'], 'check');
      expect(parsed['rate'], 1.0);
      expect(parsed['matched'], greaterThanOrEqualTo(1));
      expect(parsed['total'], greaterThanOrEqualTo(1));
      expect(parsed['clearsGate'], true);
      expect(parsed['disagreements'], isEmpty);
      expect((parsed['a'] as Map)['label'], 'device A');
      expect((parsed['b'] as Map)['label'], 'device B');
    });

    test('--json alias works identically to --ci', () {
      final path = _writeDeviceJson(tmp, 'ios.json', device: 'ios');
      final ioCi = BufferCliIO();
      final ioJson = BufferCliIO();
      runCli(['check', path, path, '--ci'], ioCi);
      runCli(['check', path, path, '--json'], ioJson);
      expect(ioCi.out.toString(), equals(ioJson.out.toString()));
    });
  });

  group('runCli — check-baseline (U13 regression)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('cli_baseline_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('device matches baseline → rate 1.0, exit 0', () {
      final baseline = _writeDeviceJson(tmp, 'baseline.json', device: 'ios');
      final device = _writeDeviceJson(tmp, 'fresh.json', device: 'ios');
      final code = runCli(['check-baseline', baseline, device], BufferCliIO());
      expect(code, 0);
    });

    test('device drifted from baseline → exit 1, labels show baseline/device',
        () {
      final baseline = _writeDeviceJson(tmp, 'baseline.json',
          device: 'ios', topKByQ: const {'Q01': ['P01']});
      final device = _writeDeviceJson(tmp, 'fresh.json',
          device: 'ios', topKByQ: const {'Q01': ['P99']});
      final io = BufferCliIO();
      final code = runCli(['check-baseline', baseline, device], io);
      expect(code, 1);
      expect(io.out.toString(), contains('baseline'));
      expect(io.out.toString(), contains('device'));
      // The check-baseline failure message should specifically call out drift
      // and not lean on the "pivot to option C" wording (that's the U1 cross-
      // platform framing; baseline drift is a different signal).
      expect(io.err.toString(), contains('drift'));
    });

    test('missing baseline → exit 2 with actionable error message', () {
      final device = _writeDeviceJson(tmp, 'fresh.json', device: 'ios');
      final io = BufferCliIO();
      final code = runCli(
          ['check-baseline', '${tmp.path}/missing-baseline.json', device], io);
      expect(code, 2);
      expect(io.err.toString(), contains('baseline not found'));
      expect(io.err.toString(), contains('baselines/latest'),
          reason:
              'error should tell the operator where to put a new baseline');
    });

    test('--ci on check-baseline emits mode=check-baseline in the JSON', () {
      final baseline = _writeDeviceJson(tmp, 'baseline.json', device: 'ios');
      final device = _writeDeviceJson(tmp, 'fresh.json', device: 'ios');
      final io = BufferCliIO();
      final code = runCli(
          ['check-baseline', baseline, device, '--ci'], io);
      expect(code, 0);
      final lines = io.out
          .toString()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 1);
      final parsed = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(parsed['mode'], 'check-baseline');
      expect((parsed['a'] as Map)['label'], 'baseline');
      expect((parsed['b'] as Map)['label'], 'device');
    });
  });

  group('runCli — JSON summary shape (stable contract for CI)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('cli_ci_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('failure case: disagreements are listed in the JSON', () {
      final aPath = _writeDeviceJson(tmp, 'a.json',
          device: 'ios', topKByQ: const {
            'Q01': ['P01'],
            'Q02': ['P02'],
          });
      final bPath = _writeDeviceJson(tmp, 'b.json',
          device: 'android', topKByQ: const {
            'Q01': ['P99'], // disagrees
            'Q02': ['P02'],
          });
      final io = BufferCliIO();
      final code = runCli(['check', aPath, bPath, '--ci'], io);
      expect(code, 1);

      final parsed =
          jsonDecode(io.out.toString().trim()) as Map<String, dynamic>;
      expect(parsed['rate'], lessThan(0.95));
      expect(parsed['clearsGate'], false);
      expect((parsed['disagreements'] as List), contains('Q01'));
      expect((parsed['disagreements'] as List), isNot(contains('Q02')));
    });

    test('keys present on a passing run (schema lock for CI parsing)', () {
      final path = _writeDeviceJson(tmp, 'ios.json', device: 'ios');
      final io = BufferCliIO();
      runCli(['check', path, path, '--ci'], io);
      final parsed =
          jsonDecode(io.out.toString().trim()) as Map<String, dynamic>;
      expect(
          parsed.keys.toSet(),
          containsAll(<String>{
            'mode',
            'rate',
            'matched',
            'total',
            'k',
            'clearsGate',
            'diagnosticBand',
            'disagreements',
            'a',
            'b',
          }));
    });
  });
}

/// Builds a temp DeviceOutput JSON file. Defaults give a tiny single-query
/// fixture so the call sites that don't care about contents stay terse.
String _writeDeviceJson(
  Directory dir,
  String name, {
  required String device,
  String model = 'qwen3-0.6',
  int dimension = 1024,
  int k = 5,
  Map<String, List<String>> topKByQ = const {
    'Q01': ['P01', 'P02', 'P03', 'P04', 'P05'],
  },
}) {
  final out = DeviceOutput(
    device: device,
    model: model,
    dimension: dimension,
    k: k,
    timestampIso: '2026-05-25T00:00:00.000Z',
    perQuery: [
      for (final entry in topKByQ.entries)
        PerQueryOutput(
          queryId: entry.key,
          topK: entry.value,
          scores: List<double>.filled(entry.value.length, 0.9),
        ),
    ],
  );
  final path = '${dir.path}/$name';
  File(path).writeAsStringSync(out.toJsonString());
  return path;
}
