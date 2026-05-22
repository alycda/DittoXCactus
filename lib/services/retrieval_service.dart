import 'dart:math' as math;
import 'dart:typed_data';

import '../models/recipe_tuple.dart';
import '../prompts/recipe_merge.dart';
import 'cactus_service.dart';
import 'ditto_service.dart';

/// A scored retrieval result: a recipe and its cosine similarity vs the query.
class RetrievedRecipe {
  final RecipeTuple recipe;
  final double score;

  const RetrievedRecipe(this.recipe, this.score);
}

/// Discriminated union over the events the answer pipeline can emit.
class AnswerEvent {
  final List<RetrievedRecipe>? retrieved;
  final String? token;
  final bool isDone;

  const AnswerEvent._({this.retrieved, this.token, this.isDone = false});

  const AnswerEvent.retrieved(List<RetrievedRecipe> r) : this._(retrieved: r);
  const AnswerEvent.token(String t) : this._(token: t);
  const AnswerEvent.done() : this._(isDone: true);
}

/// Cosine top-k over a flat float32 array materialized from Ditto. Stage 0 is
/// brute-force on purpose: ≤5k tuples × 384 dims = 7.7 MB, so exact-recall
/// brute force is sub-millisecond and the CRDT-merged tuple set has no index
/// state to keep in sync.
class RetrievalService {
  RetrievalService._();
  static final RetrievalService instance = RetrievalService._();

  /// Default k for Stage 0; the prompt template (U6) expects ~3 tuples.
  static const int defaultK = 3;

  /// Encode a recipe as the short text we hand to `cactus_embed`.
  /// Keeps it short on purpose — embedding context budgets are tight.
  String _recipeText(RecipeTuple r) {
    return '${r.dish}. Ingredients: ${r.ingredients.join(', ')}.';
  }

  /// Embed missing rows and persist the embedding column back to Ditto.
  /// Idempotent: rows that already have a non-empty embedding are skipped.
  /// Returns the number of rows newly embedded.
  Future<int> ensureEmbeddings() async {
    final missing = await DittoService.instance.queryMissingEmbedding();
    var n = 0;
    for (final r in missing) {
      final emb = await CactusService.instance.embed(_recipeText(r));
      await DittoService.instance.setEmbedding(r.id, emb);
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
  /// `RetrievedRecipe`s in descending score order.
  ///
  /// Cactus output is typically L2-normalized; we still normalize on both
  /// sides so the score stays in [-1, 1] regardless of model quirks.
  Future<List<RetrievedRecipe>> topK(String query, {int k = defaultK}) async {
    final qVec = normalize(await embedQuery(query));
    final corpus = await DittoService.instance.queryWithEmbedding();
    if (corpus.isEmpty) return const [];

    final scored = <RetrievedRecipe>[];
    for (final r in corpus) {
      final docVec = normalize(Float32List.fromList(r.embedding.map((d) => d.toDouble()).toList()));
      if (docVec.length != qVec.length) continue;
      scored.add(RetrievedRecipe(r, dot(qVec, docVec)));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).toList();
  }

  /// End-to-end answer pipeline: embed → top-k → prompt → streaming completion.
  /// Yields the top-k results once (as a structured marker) followed by raw
  /// LLM token chunks. U8 listens on this stream to render answer + attribution.
  Stream<AnswerEvent> answerQuery(String query, {int k = defaultK}) async* {
    final retrieved = await topK(query, k: k);
    yield AnswerEvent.retrieved(retrieved);

    final messages = RecipeMergePrompt.build(query: query, retrieved: retrieved);
    await for (final chunk in CactusService.instance.complete(messages, maxTokens: 768)) {
      yield AnswerEvent.token(chunk);
    }
    yield const AnswerEvent.done();
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
