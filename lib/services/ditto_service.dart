/// Singleton wrapper around the [Ditto] instance.
///
/// Stage 0 wires Ditto with BLE + LAN + AWDL (iOS/macOS only); Wi-Fi Aware
/// (Android) is deliberately *not* enabled because BLE/LAN/AWDL clears every
/// holdout the demo needs without growing the Android permission surface —
/// see plan §Key Technical Decisions ("Ditto transport config") and §U5.
///
/// The Stage 0 demo is offline-only: no big-peer URL is wired and the offline
/// license token is required — `DittoConfigConnectSmallPeersOnly` refuses to
/// start sync without it.
library mesh_rag.services.ditto_service;

import 'dart:async';

import 'package:ditto_live/ditto_live.dart';
import 'package:flutter/foundation.dart';

import '../prompts/dql_queries.dart';

/// `--dart-define=DITTO_APP_ID=…` — the database UUID from the Ditto portal
/// (or any UUID the developer picks for small-peers-only mode).
const String _envAppId = String.fromEnvironment('DITTO_APP_ID');

/// `--dart-define=DITTO_LICENSE=…` — the offline-only license token. Required
/// for small-peers-only mode; sync refuses to start without it.
const String _envLicense = String.fromEnvironment('DITTO_LICENSE');

class DittoService {
  DittoService._();
  static final DittoService instance = DittoService._();

  Ditto? _ditto;
  SyncSubscription? _subscription;
  PresenceObserver? _presenceObserver;

  /// Broadcast stream of remote-peer counts. Emits whenever the presence
  /// graph changes; subscribers can render `mesh: alone` (0) vs `mesh: N
  /// peers` (>0). Late subscribers don't replay the last value — query
  /// [currentPeerCount] for the synchronous initial state.
  final StreamController<int> _peerCountController =
      StreamController<int>.broadcast();

  /// Latest known remote-peer count. Starts at 0 (alone) and updates whenever
  /// the presence callback fires. U10's `MeshStatusWidget` reads this for its
  /// initial paint, then subscribes to [peerCount] for live updates.
  int currentPeerCount = 0;

  Stream<int> get peerCount => _peerCountController.stream;

  /// True once [initialize] has completed and `_ditto` is open.
  bool get isInitialized => _ditto != null;

  /// Identifier of the local peer in the presence graph. Useful for
  /// diagnostics and for U10's debug HUD. Reading this before [initialize]
  /// returns the empty string rather than throwing.
  String get localPeerKey =>
      _ditto?.presence.graph.localPeer.peerKey ?? '';

  /// Bring up Ditto with the configured transports. Idempotent — repeated
  /// calls after the first are no-ops, so [BootScreen] hot-restarts don't
  /// double-open the database.
  Future<void> initialize() async {
    if (_ditto != null) return;

    _validateCredentials();

    // Required before any other Ditto API. Repeated calls are no-ops inside
    // the SDK.
    await Ditto.init();

    final ditto = await Ditto.open(const DittoConfig(
      databaseID: _envAppId,
      connect: DittoConfigConnectSmallPeersOnly(),
    ));
    ditto.setOfflineOnlyLicenseToken(_envLicense);

    // Stage 0 transport policy. Explicit booleans (rather than
    // setAllPeerToPeerEnabled) so the next reader of this file can see
    // exactly which transports are intentional.
    ditto.updateTransportConfig((c) {
      c.peerToPeer.bluetoothLE.isEnabled = true;
      c.peerToPeer.lan.isEnabled = true;
      // AWDL is the iOS/macOS peer-to-peer Wi-Fi transport. Off on Android.
      switch (Ditto.currentPlatform) {
        case SupportedPlatform.ios:
        case SupportedPlatform.macos:
          c.peerToPeer.awdl.isEnabled = true;
        case SupportedPlatform.android:
        case SupportedPlatform.linux:
        case SupportedPlatform.windows:
        case SupportedPlatform.web:
          // Wi-Fi Aware deliberately stays off on Android — see comment at
          // the top of this file.
          break;
      }
    });

    _ditto = ditto;

    _presenceObserver = ditto.presence.observe((graph) {
      currentPeerCount = graph.remotePeers.length;
      _peerCountController.add(currentPeerCount);
    });
  }

  void _validateCredentials() {
    if (_envAppId.isEmpty) {
      throw StateError(
          'DITTO_APP_ID is empty. Pass it via --dart-define=DITTO_APP_ID=<uuid>.');
    }
    if (_envLicense.isEmpty) {
      throw StateError(
          'DITTO_LICENSE is empty. Pass it via --dart-define=DITTO_LICENSE=<offline-license-token>.');
    }
  }

  /// Register a sync subscription and start the transports. Repeated calls
  /// replace the subscription rather than stacking.
  Future<void> startSync({
    String subscriptionQuery = NotesQueries.syncSubscription,
  }) async {
    final ditto = _requireDitto();
    _subscription?.cancel();
    _subscription = ditto.sync.registerSubscription(subscriptionQuery);
    ditto.sync.start();
  }

  /// Stop transports. The subscription stays registered so that calling
  /// [startSync] again resumes the same query without re-registering.
  void stopSync() {
    _ditto?.sync.stop();
  }

  // ───── Notes CRUD ──────────────────────────────────────────────────────
  //
  // Stage 0 takes documents as `Map<String, dynamic>` rather than a typed
  // `StudyNote`. U7 lands the StudyNote model and the typed wrappers
  // (`upsertNote(StudyNote)` etc.) on top of these primitives — keeping the
  // primitives untyped here lets U7 evolve the model without churning the
  // CRUD surface.

  /// Insert-or-update a note document. `doc` must contain its own `_id`
  /// (the StudyNote.seed factory in U7 supplies a deterministic UUIDv5).
  Future<void> upsertNote(Map<String, dynamic> doc) async {
    final ditto = _requireDitto();
    await ditto.store.execute(NotesQueries.upsert, arguments: {'doc': doc});
  }

  /// Materialize the full corpus. Used by retrieval (U9) before the
  /// brute-force cosine pass. At ≤5k tuples this is sub-millisecond.
  Future<List<Map<String, dynamic>>> queryAll() async {
    final ditto = _requireDitto();
    final result = await ditto.store.execute(NotesQueries.selectAll);
    return result.items.map((item) => item.value).toList(growable: false);
  }

  /// Convenience for retrieval: every row whose embedding has been
  /// backfilled. Equivalent to `queryAll().where(row['embedding'] != null)`
  /// but pushes the filter into DQL.
  Future<List<Map<String, dynamic>>> queryWithEmbedding() async {
    final all = await queryAll();
    return all.where((row) => row['embedding'] != null).toList(growable: false);
  }

  /// Companion to [setEmbedding]: returns rows whose embedding column is
  /// still NULL. `RetrievalService.ensureEmbeddings` (U8) iterates this
  /// list to backfill the corpus once Cactus is loaded.
  Future<List<Map<String, dynamic>>> queryMissingEmbedding() async {
    final ditto = _requireDitto();
    final result = await ditto.store.execute(NotesQueries.selectMissingEmbedding);
    return result.items.map((item) => item.value).toList(growable: false);
  }

  /// Write `embedding` for a single existing row. Used by the backfill
  /// loop — see [queryMissingEmbedding].
  Future<void> setEmbedding(String id, List<double> embedding) async {
    final ditto = _requireDitto();
    await ditto.store.execute(
      NotesQueries.setEmbedding,
      arguments: {'id': id, 'embedding': embedding},
    );
  }

  /// Subscribe to changes on the full notes query for live UI updates
  /// (U10's notes tab). Returns the [StoreObserver] so the caller can
  /// `.stop()` it from `dispose()`.
  StoreObserver subscribeToNotes(void Function(QueryResult) onChange) {
    final ditto = _requireDitto();
    return ditto.store.registerObserver(
      NotesQueries.selectAll,
      onChange: onChange,
    );
  }

  Ditto _requireDitto() {
    final d = _ditto;
    if (d == null) {
      throw StateError('DittoService used before initialize() completed.');
    }
    return d;
  }

  /// Tear-down hook. Called from `MeshRagApp.dispose` (or test teardown)
  /// to release the presence callback and stop sync. Not strictly required
  /// for the demo flow, but keeps tests + hot-restart honest.
  @visibleForTesting
  Future<void> dispose() async {
    _presenceObserver?.stop();
    _presenceObserver = null;
    _subscription?.cancel();
    _subscription = null;
    _ditto?.sync.stop();
    await _ditto?.close();
    _ditto = null;
    await _peerCountController.close();
  }
}
