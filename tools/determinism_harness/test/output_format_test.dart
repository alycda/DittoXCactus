// Tests for the per-device measurement JSON format (lib/output_format.dart).
// Run via:  flutter test test/output_format_test.dart

import 'package:flutter_test/flutter_test.dart';

import 'package:determinism_harness/output_format.dart';

void main() {
  group('DeviceOutput round-trip', () {
    test('encode then decode preserves all fields', () {
      const original = DeviceOutput(
        device: 'ios',
        model: 'qwen3-0.6',
        dimension: 384,
        k: 5,
        timestampIso: '2026-05-23T12:00:00.000Z',
        perQuery: [
          PerQueryOutput(
            queryId: 'Q01',
            topK: ['P01', 'P02', 'P03', 'P04', 'P05'],
            scores: [0.823, 0.412, 0.388, 0.301, 0.250],
          ),
          PerQueryOutput(
            queryId: 'Q02',
            topK: ['P02'],
            scores: [0.99],
          ),
        ],
      );

      final json = original.toJsonString();
      final decoded = DeviceOutput.fromJsonString(json);

      expect(decoded.device, original.device);
      expect(decoded.model, original.model);
      expect(decoded.dimension, original.dimension);
      expect(decoded.k, original.k);
      expect(decoded.timestampIso, original.timestampIso);
      expect(decoded.perQuery.length, original.perQuery.length);
      expect(decoded.perQuery.first.queryId, 'Q01');
      expect(decoded.perQuery.first.topK, original.perQuery.first.topK);
      expect(decoded.perQuery.first.scores, original.perQuery.first.scores);
    });

    test('topKByQuery indexes by query id', () {
      const out = DeviceOutput(
        device: 'android',
        model: 'qwen3-0.6',
        dimension: 384,
        k: 5,
        timestampIso: '2026-05-23T12:00:00.000Z',
        perQuery: [
          PerQueryOutput(queryId: 'Q01', topK: ['P01'], scores: [0.9]),
          PerQueryOutput(queryId: 'Q02', topK: ['P02'], scores: [0.8]),
        ],
      );
      final indexed = out.topKByQuery();
      expect(indexed.keys.toSet(), {'Q01', 'Q02'});
      expect(indexed['Q01'], ['P01']);
    });

    test('malformed JSON surfaces a FormatException', () {
      expect(() => DeviceOutput.fromJsonString('{not json'),
          throwsA(isA<FormatException>()));
    });
  });
}
