/// Narrow Cactus surface used by Mesh RAG: embed() and complete() only.
/// Persistence lives in [DittoService]; this service never owns tuples.
class CactusService {
  CactusService._();
  static final CactusService instance = CactusService._();

  bool _initialized = false;

  /// Loads the on-device embedding model + small LLM weights from assets.
  /// Eager-called on app start (see lib/main.dart) to keep first query fast.
  Future<void> init() async {
    if (_initialized) return;
    // TODO(commit 4): wire Cactus runtime, load EmbeddingGemma + Qwen 2.5 1.5B
    _initialized = true;
  }
}
