// holdout_34 verdict CLI — pure-Dart consumer of IdempotenceCheck.
//
// Reads five snapshot JSON files captured during the live-device runner:
//
//   --pre-a       path to A's notes BEFORE the meet
//   --pre-b       path to B's notes BEFORE the meet
//   --post-a      path to A's notes AFTER the first meet
//   --post-b      path to B's notes AFTER the first meet
//   --remeet-a    path to A's notes AFTER the re-meet (no edits between)
//   --remeet-b    path to B's notes AFTER the re-meet (defaults to --post-a
//                 if elided; only --remeet-a is strictly required for R3,
//                 since R3 is a single-device idempotence check)
//   --topk-pre    optional path to ordered top-k id list pre-re-meet
//   --topk-post   optional path to ordered top-k id list post-re-meet
//
// Each snapshot JSON is a list of StudyNote-shaped maps as produced by
// `StudyNote.toDittoDoc()` — the same shape the Ditto upsert payload uses,
// so the on-device runner can dump straight out of `DittoService.queryAll`.
//
// Output:
//   stdout: human-readable PASS/FAIL banner + per-axis detail
//   --ci    suppresses the banner and emits a single-line JSON to stdout
//
// Exit codes mirror the determinism harness:
//   0  R3 + R4 both PASS
//   1  R3 or R4 FAIL
//   2  usage / file-read error
//
// Usage:
//   dart run tools/holdout_34/verdict.dart \
//     --pre-a /tmp/a-pre.json --pre-b /tmp/b-pre.json \
//     --post-a /tmp/a-post.json --post-b /tmp/b-post.json \
//     --remeet-a /tmp/a-remeet.json \
//     [--topk-pre /tmp/topk-pre.json --topk-post /tmp/topk-post.json] \
//     [--ci]

import 'dart:convert';
import 'dart:io';

import 'package:mesh_rag/holdouts/idempotence_check.dart';
import 'package:mesh_rag/models/study_note.dart';

Future<void> main(List<String> argv) async {
  final args = _parseArgs(argv);
  if (args == null) {
    _usage(stderr);
    exit(2);
  }

  try {
    final preA = await _readSnapshot(args.preA);
    final preB = await _readSnapshot(args.preB);
    final postA = await _readSnapshot(args.postA);
    final postB = await _readSnapshot(args.postB);
    final remeetA = await _readSnapshot(args.remeetA);
    final remeetB = args.remeetB != null
        ? await _readSnapshot(args.remeetB!)
        : postB; // R3 only requires one device's re-meet snapshot.

    final topKPre = args.topKPre != null
        ? await _readIdList(args.topKPre!)
        : <String>[];
    final topKPost = args.topKPost != null
        ? await _readIdList(args.topKPost!)
        : <String>[];

    final convergence = IdempotenceCheck.detectConvergence(
      preA: preA,
      preB: preB,
      postA: postA,
      postB: postB,
    );

    // R3 is per-device idempotence; we check A's pre/post re-meet. If a
    // --remeet-b is supplied we also independently check B and combine
    // the verdicts (fail-fast: any device that fails idempotence fails
    // the holdout).
    final idempotenceA = IdempotenceCheck.detectIdempotence(
      postMeet: postA,
      postRemeet: remeetA,
      topKPreRemeet: topKPre,
      topKPostRemeet: topKPost,
    );
    final idempotenceB = args.remeetB != null
        ? IdempotenceCheck.detectIdempotence(
            postMeet: postB,
            postRemeet: remeetB,
            topKPreRemeet: topKPre,
            topKPostRemeet: topKPost,
          )
        : null;
    final idempotence = idempotenceB == null || idempotenceA.pass == false
        ? idempotenceA
        : (idempotenceB.pass ? idempotenceA : idempotenceB);

    final report = IdempotenceCheck.buildReport(
      convergence: convergence,
      idempotence: idempotence,
    );

    if (args.ci) {
      stdout.writeln(jsonEncode(report));
    } else {
      _renderHumanReport(report, convergence, idempotence);
    }

    exit(report['pass'] == true ? 0 : 1);
  } on FormatException catch (e) {
    stderr.writeln('error: malformed snapshot JSON — ${e.message}');
    exit(2);
  } on FileSystemException catch (e) {
    stderr.writeln('error: ${e.message} (${e.path})');
    exit(2);
  }
}

class _Args {
  final String preA;
  final String preB;
  final String postA;
  final String postB;
  final String remeetA;
  final String? remeetB;
  final String? topKPre;
  final String? topKPost;
  final bool ci;
  _Args({
    required this.preA,
    required this.preB,
    required this.postA,
    required this.postB,
    required this.remeetA,
    required this.remeetB,
    required this.topKPre,
    required this.topKPost,
    required this.ci,
  });
}

_Args? _parseArgs(List<String> argv) {
  String? preA, preB, postA, postB, remeetA, remeetB, topKPre, topKPost;
  var ci = false;
  for (var i = 0; i < argv.length; i++) {
    final a = argv[i];
    String? next() => i + 1 < argv.length ? argv[++i] : null;
    switch (a) {
      case '--pre-a':
        preA = next();
      case '--pre-b':
        preB = next();
      case '--post-a':
        postA = next();
      case '--post-b':
        postB = next();
      case '--remeet-a':
        remeetA = next();
      case '--remeet-b':
        remeetB = next();
      case '--topk-pre':
        topKPre = next();
      case '--topk-post':
        topKPost = next();
      case '--ci':
      case '--json':
        ci = true;
      case '-h':
      case '--help':
        return null;
      default:
        stderr.writeln('unknown flag: $a');
        return null;
    }
  }
  if (preA == null ||
      preB == null ||
      postA == null ||
      postB == null ||
      remeetA == null) {
    return null;
  }
  return _Args(
    preA: preA,
    preB: preB,
    postA: postA,
    postB: postB,
    remeetA: remeetA,
    remeetB: remeetB,
    topKPre: topKPre,
    topKPost: topKPost,
    ci: ci,
  );
}

Future<List<StudyNote>> _readSnapshot(String path) async {
  final raw = await File(path).readAsString();
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  return list.map(StudyNote.fromDittoValue).toList(growable: false);
}

Future<List<String>> _readIdList(String path) async {
  final raw = await File(path).readAsString();
  return (jsonDecode(raw) as List).cast<String>();
}

void _usage(IOSink out) {
  out.writeln('Usage: dart run tools/holdout_34/verdict.dart \\');
  out.writeln('  --pre-a <path> --pre-b <path> \\');
  out.writeln('  --post-a <path> --post-b <path> \\');
  out.writeln('  --remeet-a <path> [--remeet-b <path>] \\');
  out.writeln('  [--topk-pre <path> --topk-post <path>] [--ci]');
  out.writeln('');
  out.writeln(
      'Snapshot JSONs are lists of StudyNote.toDittoDoc-shaped maps.');
  out.writeln(
      'Top-k JSONs are lists of note _id strings in retrieval order.');
}

void _renderHumanReport(
  Map<String, dynamic> report,
  ConvergenceResult convergence,
  IdempotenceResult idempotence,
) {
  final banner = (report['pass'] == true) ? 'PASS' : 'FAIL';
  stdout.writeln('holdout_34: $banner');
  stdout.writeln('');
  stdout.writeln('R4 (bidirectional merge):'
      ' ${convergence.pass ? "PASS" : "FAIL"}');
  stdout.writeln(
      '  expected union size: ${convergence.expectedUnionSize}, '
      'actual A=${convergence.actualASize}, B=${convergence.actualBSize}');
  if (convergence.missingFromA.isNotEmpty) {
    stdout.writeln('  missing from A: ${convergence.missingFromA}');
  }
  if (convergence.missingFromB.isNotEmpty) {
    stdout.writeln('  missing from B: ${convergence.missingFromB}');
  }
  if (convergence.divergedIds.isNotEmpty) {
    stdout.writeln('  diverged ids: ${convergence.divergedIds}');
  }
  stdout.writeln('');
  stdout.writeln('R3 (sync idempotence):'
      ' ${idempotence.pass ? "PASS" : "FAIL"}');
  if (idempotence.idsAdded.isNotEmpty) {
    stdout.writeln('  added on re-meet (should be empty): '
        '${idempotence.idsAdded}');
  }
  if (idempotence.idsRemoved.isNotEmpty) {
    stdout.writeln('  removed on re-meet (should be empty): '
        '${idempotence.idsRemoved}');
  }
  if (idempotence.contentChangedIds.isNotEmpty) {
    stdout.writeln('  content changed on re-meet: '
        '${idempotence.contentChangedIds}');
  }
  stdout.writeln(
      '  top-k drift count: ${idempotence.topKDriftCount} '
      '(top-k length: ${idempotence.topKLength})');
}
