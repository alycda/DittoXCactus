// run.dart — the U1 determinism gate's check-mode entry.
//
// Loads two per-device measurement JSONs (produced by
// integration_test/measure_test.dart on iOS and Android), computes the
// top-k agreement rate, and exits with status 0 only if the rate clears
// the R2 gate (>= 0.95). Exit codes:
//   0  — gate clears
//   1  — gate fails (below 0.95)
//   2  — usage / file-error
//
// Why this is a pure-Dart CLI and not a Flutter integration test: the
// measurement half is forced to be Flutter (Cactus is an FFI plugin); the
// check half is pure deterministic math over two JSON blobs and benefits
// from being runnable on a CI workstation without device access.
//
// Invocation:
//   cd tools/determinism_harness
//   dart run run.dart check <ios.json> <android.json>
//   dart run run.dart check --baseline <baseline.json> <device.json>
//
// The second form compares a fresh device output against the checked-in
// baseline.json (planned for U13 — not present in U1's surface area).

import 'dart:io';

import 'package:determinism_harness/agreement.dart';
import 'package:determinism_harness/output_format.dart';

const _usage = '''
Usage:
  dart run run.dart check <output_a.json> <output_b.json>

Loads two per-device measurement outputs and reports the top-k agreement rate.

Exit codes:
  0   agreement_rate >= 0.95 (R2 gate clears)
  1   agreement_rate <  0.95 (gate fails; diagnostic lines printed)
  2   usage or I/O error
''';

void main(List<String> argv) {
  exitCode = _run(argv);
}

int _run(List<String> argv) {
  if (argv.isEmpty || argv.first == '-h' || argv.first == '--help') {
    stdout.writeln(_usage);
    return 2;
  }
  if (argv.first != 'check' || argv.length != 3) {
    stderr.writeln('error: unrecognized arguments\n\n$_usage');
    return 2;
  }

  final aPath = argv[1];
  final bPath = argv[2];

  final aFile = File(aPath);
  final bFile = File(bPath);
  if (!aFile.existsSync()) {
    stderr.writeln('error: file not found: $aPath');
    return 2;
  }
  if (!bFile.existsSync()) {
    stderr.writeln('error: file not found: $bPath');
    return 2;
  }

  final DeviceOutput a;
  final DeviceOutput b;
  try {
    a = DeviceOutput.fromJsonString(aFile.readAsStringSync());
    b = DeviceOutput.fromJsonString(bFile.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('error: malformed measurement JSON: $e');
    return 2;
  }

  if (a.model != b.model) {
    stderr.writeln(
        'warning: model mismatch — ${a.device}=${a.model} vs ${b.device}=${b.model}');
  }
  if (a.dimension != b.dimension) {
    stderr.writeln(
        'warning: embedding-dimension mismatch — ${a.device}=${a.dimension} vs ${b.device}=${b.dimension}');
  }
  final k = a.k < b.k ? a.k : b.k;
  if (a.k != b.k) {
    stdout.writeln(
        'note: per-device k differs (${a.k} vs ${b.k}); comparing first $k positions.');
  }

  final result = agreementRate(a.topKByQuery(), b.topKByQuery(), k: k);

  stdout.writeln('=== R2 determinism gate ===');
  stdout.writeln('  device A : ${a.device}  model=${a.model}  dim=${a.dimension}');
  stdout.writeln('  device B : ${b.device}  model=${b.model}  dim=${b.dimension}');
  stdout.writeln('  k        : $k');
  stdout.writeln('  matched  : ${result.matchedQueries}/${result.totalQueries}');
  stdout.writeln(
      '  rate     : ${result.rate.toStringAsFixed(4)}  '
      '${clearsR2Gate(result.rate) ? 'PASS' : 'FAIL'}');

  if (result.disagreements.isNotEmpty) {
    // Per the plan: when between 0.85 and 0.95, dump offending queries so a
    // human can decide whether to expand the fixture or re-engineer the
    // kernel pin. We dump them whenever there are any disagreements — that's
    // strictly more useful than only printing them in the band.
    stdout.writeln('--- disagreeing queries ---');
    final aTopk = a.topKByQuery();
    final bTopk = b.topKByQuery();
    for (final q in result.disagreements) {
      stdout.writeln('  $q');
      stdout.writeln('    ${a.device}: ${aTopk[q] ?? '<missing>'}');
      stdout.writeln('    ${b.device}: ${bTopk[q] ?? '<missing>'}');
    }
  }

  if (isDiagnosticBand(result.rate)) {
    stdout.writeln(
        'NOTE: rate is in the 0.85–0.95 diagnostic band — fixable by kernel-pin '
        'tightening (batch invariance, quant, backend lock) before pivoting to '
        'option C. See plan U1 + thinkingmachines determinism article.');
  }
  if (!clearsR2Gate(result.rate)) {
    stderr.writeln(
        'R2 gate failed at ${result.rate.toStringAsFixed(4)} (< 0.95). '
        'See SEED.md cut-order: this is the pivot signal to brainstorm option C.');
    return 1;
  }
  return 0;
}
