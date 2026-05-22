import '../models/study_note.dart';

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
    // TODO(commit 4): wire ditto_live, configure transports, start sync
    _initialized = true;
  }

  /// Idempotent upsert keyed by `note.id` (which seed-loaded notes derive
  /// as a UUIDv5 over (contributor, topic, createdAt) so re-running the
  /// seed loader is a no-op).
  Future<void> upsertNote(StudyNote note) async {
    // TODO(commit 4): use ditto.store.execute with INSERT … ON ID CONFLICT
    //                 DO UPDATE, passing note.toMap()
  }
}
