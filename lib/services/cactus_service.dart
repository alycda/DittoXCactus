import 'dart:typed_data';

import 'package:cactus/cactus.dart';

/// Owns the Cactus on-device LLM lifecycle for embeddings and completions.
///
/// Stage 0 keeps Cactus *narrow*: only `generateEmbedding` and
/// `generateCompletion[Stream]` — Ditto carries persistence and we own
/// retrieval ourselves (see `retrieval_service.dart`).
///
/// Holds **two** `CactusLM` instances: completion + embedding models are
/// independent slugs because Cactus's chat-tuned slugs (e.g. `qwen3-1.7`)
/// don't expose an embedding head — `generateEmbedding` returns result
/// code `-2`. The dedicated `qwen3-embedding-0.6` slug is similarity-tuned
/// and exposes the head, but it's a separate download.
class CactusService {
  CactusService._();
  static final CactusService instance = CactusService._();

  final CactusLM _completionLm = CactusLM();
  final CactusLM _embeddingLm = CactusLM();
  bool _initialized = false;
  String? _resolvedCompletionSlug;
  String? _resolvedEmbeddingSlug;

  /// Slug pins: see plan U1/U2. Locked here for reproducibility on demo day.
  /// Cactus exposes models by slug from a built-in catalog; the spike step
  /// (U2) picks the slug that hits cosine ≥ 0.999 across iOS+Android.
  ///
  /// 2026-05-22: First swap moved both slugs from `qwen3-0.6` (~600M) to
  /// `qwen3-1.7` (~1.7B) after the on-device dogfood produced incoherent
  /// flashcards. On second device run, `qwen3-1.7` returned result code
  /// `-2` on `generateEmbedding` — it doesn't ship an embedding head.
  /// Split the slugs: completion stays at `qwen3-1.7`, embedding moves to
  /// the purpose-built `qwen3-embedding-0.6`. First launch now downloads
  /// two models (~1.7B + ~0.6B params total).
  static const String preferredEmbeddingSlug = 'qwen3-embedding-0.6';
  static const String preferredCompletionSlug = 'qwen3-1.7';

  bool get isReady => _initialized;
  String? get completionSlug => _resolvedCompletionSlug;
  String? get embeddingSlug => _resolvedEmbeddingSlug;

  /// Download (if needed) and initialize both models in-place.
  /// Both downloads happen sequentially so the progress callback can
  /// label which phase it's reporting.
  Future<void> initialize({
    String? completionSlugOverride,
    String? embeddingSlugOverride,
    int contextSize = 2048,
    void Function(double? progress, String status, bool isError)? onProgress,
  }) async {
    if (_initialized) return;
    final cSlug = completionSlugOverride ?? preferredCompletionSlug;
    final eSlug = embeddingSlugOverride ?? preferredEmbeddingSlug;

    await _completionLm.downloadModel(
      model: cSlug,
      downloadProcessCallback: (p, s, e) {
        onProgress?.call(p, 'completion ($cSlug): $s', e);
      },
    );
    await _embeddingLm.downloadModel(
      model: eSlug,
      downloadProcessCallback: (p, s, e) {
        onProgress?.call(p, 'embedding ($eSlug): $s', e);
      },
    );

    await _completionLm.initializeModel(
      params: CactusInitParams(model: cSlug, contextSize: contextSize),
    );
    await _embeddingLm.initializeModel(
      params: CactusInitParams(model: eSlug, contextSize: contextSize),
    );

    _resolvedCompletionSlug = cSlug;
    _resolvedEmbeddingSlug = eSlug;
    _initialized = true;
  }

  /// Embed a single string. Returns the raw `List<double>` from Cactus;
  /// `retrieval_service.dart` converts to `Float32List` for the tight loop.
  Future<List<double>> embed(String text) async {
    _requireReady();
    final CactusEmbeddingResult r = await _embeddingLm.generateEmbedding(text: text);
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
    final s = await _completionLm.generateCompletionStream(
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
    final r = await _completionLm.generateCompletion(
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
