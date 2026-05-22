import 'dart:math' as math;
import 'dart:typed_data';

import '../models/study_note.dart';
import 'cactus_service.dart';
import 'ditto_service.dart';

/// A scored retrieval result: a study note and its cosine similarity vs the
/// query topic.
class RetrievedNote {
  final StudyNote note;
  final double score;

  const RetrievedNote(this.note, this.score);
}

/// Cosine top-k over a flat float32 array materialized from Ditto. Stage 0 is
/// brute-force on purpose: ≤5k notes × 384 dims = 7.7 MB, so exact-recall
/// brute force is sub-millisecond and the CRDT-merged note set has no index
/// state to keep in sync.
class RetrievalService {
  RetrievalService._();
  static final RetrievalService instance = RetrievalService._();

  /// Default k for Stage 0.
  static const int defaultK = 5;

  /// Encode a study note as the short text we hand to `cactus_embed`.
  /// Keeps it short on purpose — embedding context budgets are tight, and
  /// the topic + first 200 chars of body is enough signal for cosine.
  String _noteText(StudyNote n) {
    final body = n.body.length > 200 ? n.body.substring(0, 200) : n.body;
    return '${n.topic}. $body';
  }

  /// Embed missing rows and persist the embedding column back to Ditto.
  /// Idempotent: rows that already have a non-empty embedding are skipped.
  /// Returns the number of rows newly embedded.
  Future<int> ensureEmbeddings() async {
    final missing = await DittoService.instance.queryMissingEmbedding();
    var n = 0;
    for (final note in missing) {
      final emb = await CactusService.instance.embed(_noteText(note));
      await DittoService.instance.setEmbedding(note.id, emb);
      n++;
    }
    return n;
  }

  /// Convenience wrapper around `CactusService.embed` that returns a
  /// `Float32List` ready for the cosine loop.
  Future<Float32List> embedQuery(String query) async {
    final raw = await CactusService.instance.embed(query);
    return Float32List.fromList(raw.map((d) => d.toDouble()).toList());
  }

  /// Compute cosine-top-k over the embedded corpus. Returns up to `k`
  /// `RetrievedNote`s in descending score order.
  ///
  /// Cactus output is typically L2-normalized; we still normalize on both
  /// sides so the score stays in [-1, 1] regardless of model quirks.
  Future<List<RetrievedNote>> topK(String topic, {int k = defaultK}) async {
    final qVec = normalize(await embedQuery(topic));
    final corpus = await DittoService.instance.queryWithEmbedding();
    if (corpus.isEmpty) return const [];

    final scored = <RetrievedNote>[];
    for (final note in corpus) {
      final docVec = normalize(Float32List.fromList(note.embedding.map((d) => d.toDouble()).toList()));
      if (docVec.length != qVec.length) continue;
      scored.add(RetrievedNote(note, dot(qVec, docVec)));
    }

    scored.sort((a, b) {
      final s = b.score.compareTo(a.score);
      return s != 0 ? s : a.note.id.compareTo(b.note.id); // tie-break by _id
    });
    return scored.take(k).toList();
  }

  // ---------------------------------------------------------------------------
  // pure-math helpers — tested in retrieval_service_test.dart

  static Float32List normalize(Float32List v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final n = math.sqrt(sum);
    if (n == 0) return v;
    final out = Float32List(v.length);
    for (var i = 0; i < v.length; i++) {
      out[i] = v[i] / n;
    }
    return out;
  }

  static double dot(Float32List a, Float32List b) {
    var s = 0.0;
    for (var i = 0; i < a.length; i++) {
      s += a[i] * b[i];
    }
    return s;
  }
}
