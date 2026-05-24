// On-device measurement entry — the "measure" half of the U1 determinism gate.
//
// Loads the same Cactus slug the app will use (qwen3-0.6 per the plan's Key
// Technical Decisions), embeds every fixture query and passage, computes top-k
// per query using the harness math (lib/agreement.dart), and writes a
// per-device JSON output to the app's documents directory. The result is
// compared offline against the other phone's output by run.dart (check mode).
//
// Why this lives under integration_test/ and not as a pure-Dart CLI: Cactus is
// a Flutter FFI plugin. Its model-loading path needs path_provider and a live
// FlutterBinding, so it can only run inside a Flutter app or integration test.
//
// Invocation:
//   cd tools/determinism_harness
//   flutter test integration_test/measure_test.dart -d <device-id>
//
// The output file path is logged to stdout at the end of the run. Pull it off
// the device (adb / Xcode devicectl) and feed both pulled outputs to:
//   dart run run.dart check <ios_output.json> <android_output.json>

import 'dart:convert';
import 'dart:io' as io;

import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:determinism_harness/agreement.dart';
import 'package:determinism_harness/output_format.dart';

const String _embeddingSlug = 'qwen3-0.6';

/// Routes harness output through `debugPrint`, which integration_test
/// forwards to the parent `flutter test` process. Direct `io.stdout` writes
/// from inside a `testWidgets` block do not reliably appear in the test log
/// — caught the hard way on the first device-run attempt.
void _emit(Object line) => debugPrint(line.toString());

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'embeds the fixture set and writes a top-k report to app docs dir',
    (WidgetTester tester) async {
      // 1. Load the fixture from the package assets.
      final fixtureJson =
          await rootBundle.loadString('fixtures/queries.json');
      final fixture = parseFixture(fixtureJson);
      _emit(
          'Fixture loaded: ${fixture.queries.length} queries, '
          '${fixture.passages.length} passages, k=${fixture.k}.');

      // 2. Bring up Cactus with the chosen embedding slug.
      final lm = CactusLM();
      _emit('Downloading + initializing $_embeddingSlug ...');
      await lm.downloadModel(model: _embeddingSlug);
      await lm.initializeModel(
          params: CactusInitParams(model: _embeddingSlug));
      expect(lm.isLoaded(), isTrue,
          reason: 'Cactus failed to load $_embeddingSlug');

      // 3. Embed every passage. Sequential, batch=1; per plan U1's Approach.
      final passageEmbeddings = <String, List<double>>{};
      int? observedDim;
      for (final p in fixture.passages) {
        final r = await lm.generateEmbedding(text: p.text);
        expect(r.success, isTrue,
            reason: 'embedding failed for passage ${p.id}: ${r.errorMessage}');
        observedDim ??= r.dimension;
        passageEmbeddings[p.id] = r.embeddings;
      }
      _emit(
          'Passages embedded. dimension=${observedDim ?? 'unknown'}.');

      // 4. Embed every query and compute top-k for each.
      final perQuery = <PerQueryOutput>[];
      for (final q in fixture.queries) {
        final r = await lm.generateEmbedding(text: q.text);
        expect(r.success, isTrue,
            reason: 'embedding failed for query ${q.id}: ${r.errorMessage}');
        final ranked = topK(
          queryEmbedding: r.embeddings,
          passageEmbeddings: passageEmbeddings,
          k: fixture.k,
        );
        perQuery.add(PerQueryOutput(
          queryId: q.id,
          topK: ranked.map((e) => e.id).toList(),
          scores: ranked.map((e) => e.score).toList(),
        ));
      }

      // 5. Assemble the per-device output. Platform detection is best-effort
      // — defaults to dart:io's Platform.operatingSystem so the same code runs
      // on iOS and Android without a build-time switch.
      final out = DeviceOutput(
        device: io.Platform.operatingSystem,
        model: _embeddingSlug,
        dimension: observedDim ?? 0,
        k: fixture.k,
        timestampIso: DateTime.now().toUtc().toIso8601String(),
        perQuery: perQuery,
      );

      // 6. Write to the app's documents directory (only writable location on
      // both iOS and Android sandboxes). Path is logged so the operator can
      // pull it off the device.
      final docsDir = await getApplicationDocumentsDirectory();
      final outFile = io.File(
          '${docsDir.path}/determinism_${out.device}_${_embeddingSlug.replaceAll('.', '_')}.json');
      final serialized = out.toJsonString();
      await outFile.writeAsString(serialized);
      _emit('Wrote ${outFile.path}');

      // 6b. Also dump the JSON between markers so the operator can extract it
      // directly from the test log without pulling the file off the device.
      // This is the supported workflow when the workstation has the phones on
      // USB and `flutter test` output is captured in a shell.
      _emit('--- BEGIN DETERMINISM_JSON ---');
      for (final line in serialized.split('\n')) {
        _emit(line);
      }
      _emit('--- END DETERMINISM_JSON ---');

      // 7. Stdout summary in the legacy TSV shape the plan describes, so a
      // human watching the test log can spot-check the result without pulling
      // the file. One line per query: <query_id>\t<top-k space-joined>.
      _emit('--- BEGIN TOPK ---');
      for (final p in perQuery) {
        _emit('${p.queryId}\t${p.topK.join(' ')}\t'
            'top1_cos=${p.scores.first.toStringAsFixed(6)}');
      }
      _emit('--- END TOPK ---');

      // 8. Cheap sanity gate — the fixture is constructed so every query has a
      // clear-cut top-1 in its own cluster. If <80% of queries land their
      // expectedTop1 in the top-3, the slug is junk and the gate failure is
      // diagnosable from this run alone (no need to wait for the cross-device
      // diff). 80% is a deliberately loose floor; the real R2 gate is the
      // cross-device 95% top-k-ordered match, applied by run.dart check.
      final byId = {for (final q in fixture.queries) q.id: q};
      var landedExpectedInTop3 = 0;
      for (final p in perQuery) {
        final expected = byId[p.queryId]!.expectedTop1;
        if (p.topK.take(3).contains(expected)) landedExpectedInTop3++;
      }
      _emit(
          'On-device sanity: $landedExpectedInTop3/${perQuery.length} '
          'queries put expectedTop1 in their top-3.');

      // Encode the floor so a model-quality regression breaks the test
      // immediately on whichever device runs it.
      expect(landedExpectedInTop3 / perQuery.length, greaterThanOrEqualTo(0.8),
          reason: 'Cactus slug $_embeddingSlug is failing the sanity floor — '
              'fewer than 80% of fixture queries put their expectedTop1 in '
              'the top-3. Investigate before treating cross-device diff as '
              'load-bearing.');

      lm.unload();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

// ignore: unused_element
String _previewJson(DeviceOutput out, {int maxQueries = 3}) {
  // Convenience for log inspection when iterating; kept tree-shakable by the
  // ignore above. Useful when triaging a slug change locally.
  return const JsonEncoder.withIndent('  ').convert({
    'device': out.device,
    'model': out.model,
    'dimension': out.dimension,
    'preview':
        out.perQuery.take(maxQueries).map((p) => p.toJson()).toList(),
  });
}
