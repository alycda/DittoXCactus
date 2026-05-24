/// Pure-Dart math for the iOS↔Android embedding determinism gate (U1, R2).
///
/// All functions here are deterministic and dependency-free so the
/// agreement-rate calculation is never where R2 bugs hide. The Cactus
/// embedding pipeline is exercised separately in `integration_test/`.
library determinism_harness.agreement;

import 'dart:convert';
import 'dart:math' as math;

// ─────────────────────────────────────────────────────────────────────────────
// Vector math
// ─────────────────────────────────────────────────────────────────────────────

/// Cosine similarity between two vectors of equal dimension.
///
/// Returns 0.0 if either side is the zero vector (treating "no direction" as
/// "no similarity" rather than producing NaN, which would poison sort order).
/// Throws [ArgumentError] on dimension mismatch — surfacing this loudly at the
/// math layer keeps a model swap from silently producing 0-similarity hits.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError(
        'cosineSimilarity: dimension mismatch (${a.length} vs ${b.length})');
  }
  double dot = 0.0;
  double na = 0.0;
  double nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0.0 || nb == 0.0) return 0.0;
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-k with deterministic tie-break  (load-bearing for R2 and R3)
// ─────────────────────────────────────────────────────────────────────────────

class TopKEntry {
  final String id;
  final double score;
  const TopKEntry(this.id, this.score);

  @override
  String toString() => '$id:${score.toStringAsFixed(6)}';
}

/// Top-k passage retrieval over a single query embedding.
///
/// Tie-break: `(score desc, id asc)`. This is the invariant SEED.md and the
/// plan pin for R2 (cross-device top-k agreement) and R3 (sync idempotence) —
/// without it, tied scores produce nondeterministic ordering across devices
/// even when embeddings are bitwise-identical.
///
/// Passages whose embedding dimension does not match the query's are dropped
/// (not raised), so a model swap mid-corpus is contained at the query boundary
/// instead of crashing the harness.
List<TopKEntry> topK({
  required List<double> queryEmbedding,
  required Map<String, List<double>> passageEmbeddings,
  required int k,
}) {
  final entries = <TopKEntry>[];
  for (final id in passageEmbeddings.keys) {
    final emb = passageEmbeddings[id]!;
    if (emb.length != queryEmbedding.length) continue;
    entries.add(TopKEntry(id, cosineSimilarity(queryEmbedding, emb)));
  }
  entries.sort((a, b) {
    final c = b.score.compareTo(a.score); // score desc
    if (c != 0) return c;
    return a.id.compareTo(b.id); // id asc
  });
  if (entries.length > k) entries.length = k;
  return entries;
}

// ─────────────────────────────────────────────────────────────────────────────
// Agreement rate  (the gate)
// ─────────────────────────────────────────────────────────────────────────────

class AgreementResult {
  final double rate;
  final int matchedQueries;
  final int totalQueries;
  final List<String> disagreements;

  const AgreementResult({
    required this.rate,
    required this.matchedQueries,
    required this.totalQueries,
    required this.disagreements,
  });

  @override
  String toString() =>
      'agreement_rate=${rate.toStringAsFixed(4)} '
      '($matchedQueries/$totalQueries matched, '
      '${disagreements.length} disagreed)';
}

/// Compare the top-k passages per query across two devices.
///
/// Both arguments map `query_id → top-k passage ids in deterministic order`.
/// Tie-break is the producer's responsibility (see [topK]); this function does
/// not re-sort.
///
/// Comparison is strict over the first [k] positions: any difference (missing
/// query, shorter list, reordering within top-k) counts as a disagreement. The
/// tie-break invariant in [topK] makes within-top-k reorderings impossible on
/// bitwise-identical embeddings — surfacing one here means either the
/// embeddings diverged or the tie-break wasn't applied.
AgreementResult agreementRate(
  Map<String, List<String>> perQueryTopkA,
  Map<String, List<String>> perQueryTopkB, {
  int k = 5,
}) {
  final disagreements = <String>[];
  final allQueries = <String>{...perQueryTopkA.keys, ...perQueryTopkB.keys};
  final sortedQueries = allQueries.toList()..sort();

  for (final q in sortedQueries) {
    final a = perQueryTopkA[q];
    final b = perQueryTopkB[q];
    if (a == null || b == null || !_prefixEqual(a, b, k)) {
      disagreements.add(q);
    }
  }

  final total = sortedQueries.length;
  final matched = total - disagreements.length;
  final rate = total == 0 ? 1.0 : matched / total;

  return AgreementResult(
    rate: rate,
    matchedQueries: matched,
    totalQueries: total,
    disagreements: disagreements,
  );
}

bool _prefixEqual(List<String> a, List<String> b, int k) {
  final limit = [a.length, b.length, k].reduce(math.min);
  for (var i = 0; i < limit; i++) {
    if (a[i] != b[i]) return false;
  }
  // Lists of different length up to k count as disagreement.
  if (a.length < k || b.length < k) {
    return a.length == b.length;
  }
  return true;
}

/// True when the rate clears the R2 gate (≥ 0.95).
bool clearsR2Gate(double rate) => rate >= 0.95;

/// True when the rate is in the diagnostic band (0.85 ≤ rate < 0.95) — close
/// enough to be worth dumping the offending queries before giving up on the
/// kernel pin, far enough that we can't ship.
bool isDiagnosticBand(double rate) => rate >= 0.85 && rate < 0.95;

// ─────────────────────────────────────────────────────────────────────────────
// Fixture parsing
// ─────────────────────────────────────────────────────────────────────────────

class FixturePassage {
  final String id;
  final String cluster;
  final String text;
  const FixturePassage(
      {required this.id, required this.cluster, required this.text});
}

class FixtureQuery {
  final String id;
  final String cluster;
  final String text;
  final String expectedTop1;
  const FixtureQuery({
    required this.id,
    required this.cluster,
    required this.text,
    required this.expectedTop1,
  });
}

class Fixture {
  final int k;
  final List<String> clusters;
  final List<FixturePassage> passages;
  final List<FixtureQuery> queries;
  const Fixture({
    required this.k,
    required this.clusters,
    required this.passages,
    required this.queries,
  });
}

/// Parse the checked-in `fixtures/queries.json`.
///
/// Throws [FormatException] for malformed JSON; [ArgumentError] for missing or
/// wrong-typed required fields.
Fixture parseFixture(String jsonText) {
  final dynamic raw = jsonDecode(jsonText);
  if (raw is! Map<String, dynamic>) {
    throw ArgumentError('Fixture JSON must be a top-level object');
  }
  final k = raw['k'];
  if (k is! int) {
    throw ArgumentError('Fixture JSON missing or non-int "k"');
  }
  final clustersRaw = raw['clusters'];
  if (clustersRaw is! List) {
    throw ArgumentError('Fixture JSON missing "clusters" list');
  }
  final passagesRaw = raw['passages'];
  if (passagesRaw is! List) {
    throw ArgumentError('Fixture JSON missing "passages" list');
  }
  final queriesRaw = raw['queries'];
  if (queriesRaw is! List) {
    throw ArgumentError('Fixture JSON missing "queries" list');
  }

  return Fixture(
    k: k,
    clusters: clustersRaw.cast<String>(),
    passages: passagesRaw.map((dynamic p) {
      final m = p as Map<String, dynamic>;
      return FixturePassage(
        id: m['id'] as String,
        cluster: m['cluster'] as String,
        text: m['text'] as String,
      );
    }).toList(),
    queries: queriesRaw.map((dynamic q) {
      final m = q as Map<String, dynamic>;
      return FixtureQuery(
        id: m['id'] as String,
        cluster: m['cluster'] as String,
        text: m['text'] as String,
        expectedTop1: m['expectedTop1'] as String,
      );
    }).toList(),
  );
}
