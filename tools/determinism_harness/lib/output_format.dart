/// JSON serialization for per-device measurement output and combined agreement
/// reports. Pure Dart; no Flutter dependencies — used by both the on-device
/// integration test (write) and the check-mode CLI (read).
library determinism_harness.output_format;

import 'dart:convert';

class PerQueryOutput {
  final String queryId;
  final List<String> topK;
  final List<double> scores;
  const PerQueryOutput({
    required this.queryId,
    required this.topK,
    required this.scores,
  });

  Map<String, dynamic> toJson() => {
        'queryId': queryId,
        'topK': topK,
        'scores': scores,
      };

  factory PerQueryOutput.fromJson(Map<String, dynamic> m) => PerQueryOutput(
        queryId: m['queryId'] as String,
        topK: (m['topK'] as List).cast<String>(),
        scores: (m['scores'] as List).map((dynamic v) => (v as num).toDouble()).toList(),
      );
}

class DeviceOutput {
  final String device; // 'ios' | 'android' | other
  final String model; // Cactus slug, e.g. 'qwen3-0.6'
  final int dimension;
  final int k;
  final String timestampIso;
  final List<PerQueryOutput> perQuery;

  const DeviceOutput({
    required this.device,
    required this.model,
    required this.dimension,
    required this.k,
    required this.timestampIso,
    required this.perQuery,
  });

  String toJsonString() => const JsonEncoder.withIndent('  ').convert({
        'device': device,
        'model': model,
        'dimension': dimension,
        'k': k,
        'timestamp': timestampIso,
        'perQuery': perQuery.map((e) => e.toJson()).toList(),
      });

  factory DeviceOutput.fromJsonString(String jsonText) {
    final dynamic raw = jsonDecode(jsonText);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('DeviceOutput JSON must be a top-level object');
    }
    return DeviceOutput(
      device: raw['device'] as String,
      model: raw['model'] as String,
      dimension: raw['dimension'] as int,
      k: raw['k'] as int,
      timestampIso: raw['timestamp'] as String,
      perQuery: (raw['perQuery'] as List)
          .map((dynamic e) => PerQueryOutput.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, List<String>> topKByQuery() => {
        for (final p in perQuery) p.queryId: p.topK,
      };
}
