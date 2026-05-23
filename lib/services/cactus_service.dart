import 'dart:typed_data';

import 'package:cactus/cactus.dart';

/// Owns the Cactus on-device LLM lifecycle for embeddings and completions.
///
/// Stage 0 keeps Cactus *narrow*: only `generateEmbedding` and
/// `generateCompletion[Stream]` — Ditto carries persistence and we own
/// retrieval ourselves (see `retrieval_service.dart`).
class CactusService {
  CactusService._();
  static final CactusService instance = CactusService._();

  final CactusLM _lm = CactusLM();
  bool _initialized = false;
  String? _resolvedModelSlug;

  /// Slug pin: see plan U1/U2. Locked here for reproducibility on demo day.
  /// Cactus exposes models by slug from a built-in catalog; the spike step
  /// (U2) picks the slug that hits cosine ≥ 0.999 across iOS+Android.
  ///
  /// 2026-05-22: Bumped from `qwen3-0.6` (~600M) to `qwen3-1.7` (~1.7B) after
  /// the on-device dogfood produced incoherent flashcards. The prompts in
  /// `flashcard_gen.dart` were tuned for Qwen 2.5 1.5B; `qwen3-0.6` is below
  /// the size where structured Q/A from passages becomes reliable.
  /// Future axis to consider: split embedding to the purpose-built
  /// `qwen3-embedding-0.6` slug (would double the first-launch download,
  /// but the embedding model is tuned for similarity rather than chat).
  static const String preferredEmbeddingSlug = 'qwen3-1.7';
  static const String preferredCompletionSlug = 'qwen3-1.7';

  bool get isReady => _initialized;
  String? get modelSlug => _resolvedModelSlug;

  /// Download (if needed) and initialize the model in-place.
  /// Stage 0 uses one model for both embed + complete to stay under the
  /// first-launch download budget.
  Future<void> initialize({
    String? slug,
    int contextSize = 2048,
    void Function(double? progress, String status, bool isError)? onProgress,
  }) async {
    if (_initialized) return;
    final chosen = slug ?? preferredCompletionSlug;
    await _lm.downloadModel(
      model: chosen,
      downloadProcessCallback: (p, s, e) {
        onProgress?.call(p, s, e);
      },
    );
    await _lm.initializeModel(
      params: CactusInitParams(model: chosen, contextSize: contextSize),
    );
    _resolvedModelSlug = chosen;
    _initialized = true;
  }

  /// Embed a single string. Returns the raw `List<double>` from Cactus;
  /// `retrieval_service.dart` converts to `Float32List` for the tight loop.
  Future<List<double>> embed(String text) async {
    _requireReady();
    final CactusEmbeddingResult r = await _lm.generateEmbedding(text: text);
    if (!r.success) {
      throw StateError('cactus_embed failed for text len=${text.length}');
    }
    return r.embeddings;
  }

  /// Convenience: embed and return as `Float32List` for cosine.
  Future<Float32List> embedF32(String text) async {
    final raw = await embed(text);
    return Float32List.fromList(raw.map((d) => d.toDouble()).toList());
  }

  /// Streaming completion. Yields token chunks as the model emits them.
  Stream<String> complete(
    List<ChatMessage> messages, {
    int maxTokens = 256,
  }) async* {
    _requireReady();
    final s = await _lm.generateCompletionStream(
      messages: messages,
      params: CactusCompletionParams(maxTokens: maxTokens),
    );
    await for (final chunk in s.stream) {
      yield chunk;
    }
  }

  /// Non-streaming variant for evals (U3) and tests.
  Future<String> completeAll(
    List<ChatMessage> messages, {
    int maxTokens = 256,
  }) async {
    _requireReady();
    final r = await _lm.generateCompletion(
      messages: messages,
      params: CactusCompletionParams(maxTokens: maxTokens),
    );
    return r.response;
  }

  void _requireReady() {
    if (!_initialized) {
      throw StateError('CactusService not initialized; call initialize() first');
    }
  }
}
