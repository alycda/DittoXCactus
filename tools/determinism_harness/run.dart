// run.dart — determinism-harness CLI entry.
//
// Subcommands (see lib/cli.dart for full docs):
//   check           U1 cross-platform gate: two device JSONs → agreement rate.
//   check-baseline  U13 regression: device JSON vs baselines/latest/<device>.json.
//
// Both accept `--ci` (alias `--json`) for a single-line JSON summary on stdout.
//
// Exit codes:
//   0  agreement_rate >= 0.95 (R2 gate clears)
//   1  agreement_rate <  0.95 (gate fails)
//   2  usage / file-error

import 'dart:io';

import 'package:determinism_harness/cli.dart';

void main(List<String> argv) {
  exitCode = runCli(argv, ProcessCliIO());
}
