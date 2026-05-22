import 'dart:async';

import 'package:ditto_live/ditto_live.dart' show StoreObserver;

import '../models/study_note.dart';

/// Owns persistence + P2P sync for RecipeTuple documents.
/// All Cactus-produced embeddings round-trip through here.
class DittoService {
  DittoService._();
  static final DittoService instance = DittoService._();

  bool _initialized = false;

  final _peerCountController = StreamController<int>.broadcast();

  /// Broadcasts the current mesh peer count whenever Ditto's presence
  /// observer fires. UI surfaces (e.g. MeshStatusWidget) listen here to
  /// render the "alone → connected" transition.
  Stream<int> get peerCount => _peerCountController.stream;

  /// True once [init] has resolved. UI guards (e.g. NotesTab) read this
  /// before attempting to subscribe.
  bool get isReady => _initialized;

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

  /// Returns notes whose `embedding` column is empty — i.e. freshly inserted
  /// rows that `RetrievalService.ensureEmbeddings()` still needs to fill.
  Future<List<StudyNote>> queryMissingEmbedding() async {
    // TODO(later): SELECT … FROM notes WHERE array_length(embedding) = 0
    return const [];
  }

  /// Persists a freshly-computed embedding back to the note's document.
  Future<void> setEmbedding(String noteId, List<double> embedding) async {
    // TODO(later): UPDATE notes SET embedding = :emb WHERE _id = :id
  }

  /// Returns all notes whose `embedding` is non-empty — the retrievable set
  /// that `RetrievalService.topK()` materializes into Float32 cosine space.
  Future<List<StudyNote>> queryWithEmbedding() async {
    // TODO(later): SELECT … FROM notes WHERE array_length(embedding) > 0
    return const [];
  }

  /// Registers a live observer over `SELECT * FROM notes` and invokes
  /// [onUpdate] whenever the result set changes (including from peer-synced
  /// inserts). Returns the observer for the caller to cancel on dispose.
  /// Stub returns null until ditto_live is wired.
  StoreObserver? subscribeToNotes(void Function(List<StudyNote>) onUpdate) {
    // TODO(later): ditto.store.registerObserver(NotesQueries.selectAll, ...)
    return null;
  }
}
