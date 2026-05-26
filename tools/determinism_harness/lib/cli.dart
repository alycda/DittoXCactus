/// Determinism-harness CLI entry, factored out of `run.dart` so the
/// subcommand dispatch + output rendering are unit-testable without spawning
/// a subprocess. `run.dart` is a thin shim that calls [runCli] with
/// stdout/stderr from `dart:io`.
///
/// Subcommands:
///   check           U1 cross-platform: two-device JSONs → agreement rate.
///   check-baseline  U13 regression: one fresh device JSON vs a baseline.
///
/// Both subcommands accept `--ci` (also `--json`) to emit a single-line JSON
/// summary on stdout instead of the human report. Exit codes are stable:
///
///   0 — agreement_rate >= 0.95 (R2 gate clears)
///   1 — agreement_rate <  0.95 (gate fails; diagnostic lines printed)
///   2 — usage or I/O error
library determinism_harness.cli;

import 'dart:convert';
import 'dart:io';

import 'agreement.dart';
import 'output_format.dart';

const _usage = '''
Usage:
  dart run run.dart check <output_a.json> <output_b.json> [--ci]
  dart run run.dart check-baseline <baseline.json> <device.json> [--ci]

  check           U1 cross-platform gate: compare two device measurements.
  check-baseline  U13 regression: compare a fresh device run against a
                  checked-in baseline. The baseline pins the locked Cactus
                  slug; any diff signals an intentional or accidental pin
                  change. Regenerate by copying a fresh measurement over
                  baselines/latest/<device>.json.

  --ci, --json    Emit a single JSON line on stdout instead of the human
                  report. Stable schema; safe to parse from CI.

Exit codes:
  0   agreement_rate >= 0.95 (R2 gate clears)
  1   agreement_rate <  0.95 (gate fails; offending queries printed)
  2   usage or I/O error
''';

/// Stream sinks the CLI writes to. Production passes `stdout`/`stderr`;
/// tests pass `StringBuffer`s via [StringSinkCliIO] so output is captured.
abstract class CliIO {
  StringSink get out;
  StringSink get err;
}

/// Production [CliIO] that writes to the process's actual stdout/stderr.
class ProcessCliIO implements CliIO {
  @override
  StringSink get out => stdout;
  @override
  StringSink get err => stderr;
}

/// Test [CliIO] backed by [StringBuffer]s so tests can assert on output
/// without subprocess noise.
class BufferCliIO implements CliIO {
  @override
  final StringBuffer out = StringBuffer();
  @override
  final StringBuffer err = StringBuffer();
}

/// Dispatcher. Returns the exit code; never calls [exit] itself so tests
/// don't terminate the test process.
int runCli(List<String> argv, CliIO io) {
  if (argv.isEmpty || argv.first == '-h' || argv.first == '--help') {
    io.out.writeln(_usage);
    return 2;
  }

  final ciFlag = argv.contains('--ci') || argv.contains('--json');
  final positional = argv.where((a) => !a.startsWith('--')).toList();

  if (positional.isEmpty) {
    io.err.writeln('error: no subcommand\n\n$_usage');
    return 2;
  }

  switch (positional.first) {
    case 'check':
      return _runCheck(positional.sublist(1), io: io, ciJson: ciFlag);
    case 'check-baseline':
      return _runCheckBaseline(positional.sublist(1), io: io, ciJson: ciFlag);
    default:
      io.err.writeln('error: unknown subcommand "${positional.first}"\n\n$_usage');
      return 2;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// check — two-device cross-platform comparison (U1)
// ─────────────────────────────────────────────────────────────────────────────

int _runCheck(List<String> args, {required CliIO io, required bool ciJson}) {
  if (args.length != 2) {
    io.err.writeln('error: `check` takes exactly 2 positional args\n\n$_usage');
    return 2;
  }

  final aLoad = _loadDeviceOutput(args[0], io: io);
  if (aLoad == null) return 2;
  final bLoad = _loadDeviceOutput(args[1], io: io);
  if (bLoad == null) return 2;

  return _reportComparison(
    a: aLoad,
    b: bLoad,
    io: io,
    ciJson: ciJson,
    mode: 'check',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// check-baseline — one device run vs a frozen baseline (U13)
// ─────────────────────────────────────────────────────────────────────────────

int _runCheckBaseline(List<String> args,
    {required CliIO io, required bool ciJson}) {
  if (args.length != 2) {
    io.err.writeln(
        'error: `check-baseline` takes exactly 2 positional args '
        '(baseline + device output)\n\n$_usage');
    return 2;
  }
  final baselinePath = args[0];
  final devicePath = args[1];

  if (!File(baselinePath).existsSync()) {
    io.err.writeln(
        'error: baseline not found at $baselinePath. To create one, copy a '
        'fresh measurement over baselines/latest/<device>.json (only do this '
        'on an intentional model-pin change).');
    return 2;
  }

  final baseline = _loadDeviceOutput(baselinePath, io: io, label: 'baseline');
  if (baseline == null) return 2;
  final device = _loadDeviceOutput(devicePath, io: io, label: 'device');
  if (device == null) return 2;

  return _reportComparison(
    a: baseline,
    b: device,
    io: io,
    ciJson: ciJson,
    mode: 'check-baseline',
    aLabel: 'baseline',
    bLabel: 'device',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// shared loading + reporting
// ─────────────────────────────────────────────────────────────────────────────

DeviceOutput? _loadDeviceOutput(String path,
    {required CliIO io, String label = 'measurement'}) {
  final file = File(path);
  if (!file.existsSync()) {
    io.err.writeln('error: $label file not found: $path');
    return null;
  }
  try {
    return DeviceOutput.fromJsonString(file.readAsStringSync());
  } on FormatException catch (e) {
    io.err.writeln('error: malformed $label JSON at $path: $e');
    return null;
  }
}

int _reportComparison({
  required DeviceOutput a,
  required DeviceOutput b,
  required CliIO io,
  required bool ciJson,
  required String mode,
  String aLabel = 'device A',
  String bLabel = 'device B',
}) {
  if (a.model != b.model) {
    io.err.writeln(
        'warning: model mismatch — $aLabel=${a.model} vs $bLabel=${b.model}');
  }
  if (a.dimension != b.dimension) {
    io.err.writeln(
        'warning: embedding-dimension mismatch — '
        '$aLabel=${a.dimension} vs $bLabel=${b.dimension}');
  }
  final k = a.k < b.k ? a.k : b.k;
  if (a.k != b.k && !ciJson) {
    io.out.writeln(
        'note: per-side k differs (${a.k} vs ${b.k}); comparing first $k positions.');
  }

  final result = agreementRate(a.topKByQuery(), b.topKByQuery(), k: k);
  final cleared = clearsR2Gate(result.rate);

  if (ciJson) {
    final summary = <String, dynamic>{
      'mode': mode,
      'rate': double.parse(result.rate.toStringAsFixed(4)),
      'matched': result.matchedQueries,
      'total': result.totalQueries,
      'k': k,
      'clearsGate': cleared,
      'diagnosticBand': isDiagnosticBand(result.rate),
      'disagreements': result.disagreements,
      'a': {'label': aLabel, 'device': a.device, 'model': a.model, 'dim': a.dimension, 'k': a.k},
      'b': {'label': bLabel, 'device': b.device, 'model': b.model, 'dim': b.dimension, 'k': b.k},
    };
    io.out.writeln(jsonEncode(summary));
    return cleared ? 0 : 1;
  }

  io.out.writeln('=== R2 determinism gate ($mode) ===');
  io.out.writeln(
      '  $aLabel : ${a.device}  model=${a.model}  dim=${a.dimension}');
  io.out.writeln(
      '  $bLabel : ${b.device}  model=${b.model}  dim=${b.dimension}');
  io.out.writeln('  k        : $k');
  io.out.writeln(
      '  matched  : ${result.matchedQueries}/${result.totalQueries}');
  io.out.writeln(
      '  rate     : ${result.rate.toStringAsFixed(4)}  '
      '${cleared ? 'PASS' : 'FAIL'}');

  if (result.disagreements.isNotEmpty) {
    io.out.writeln('--- disagreeing queries ---');
    final aTopk = a.topKByQuery();
    final bTopk = b.topKByQuery();
    for (final q in result.disagreements) {
      io.out.writeln('  $q');
      io.out.writeln('    $aLabel: ${aTopk[q] ?? '<missing>'}');
      io.out.writeln('    $bLabel: ${bTopk[q] ?? '<missing>'}');
    }
  }

  if (isDiagnosticBand(result.rate)) {
    io.out.writeln(
        'NOTE: rate is in the 0.85–0.95 diagnostic band — fixable by kernel-pin '
        'tightening (batch invariance, quant, backend lock) before pivoting to '
        'option C. See plan U1 + thinkingmachines determinism article.');
  }
  if (!cleared) {
    io.err.writeln(
        'R2 gate failed at ${result.rate.toStringAsFixed(4)} (< 0.95). '
        '${mode == 'check-baseline' ? 'Baseline drift detected — investigate '
            'model pin, framework upgrade, or kernel-layer change.' : 'See '
            'SEED.md cut-order: this is the pivot signal to brainstorm option C.'}');
    return 1;
  }
  return 0;
}
