/// Owns persistence + P2P sync for RecipeTuple documents.
/// All Cactus-produced embeddings round-trip through here.
class DittoService {
  DittoService._();
  static final DittoService instance = DittoService._();

  bool _initialized = false;

  /// Initializes the local Ditto store, configures BLE/LAN transports,
  /// and calls sync.start. Eager-called on app start.
  Future<void> init() async {
    if (_initialized) return;
    // TODO(commit 3): wire ditto_live, configure transports, start sync
    _initialized = true;
  }
}
