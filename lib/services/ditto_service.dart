/// Singleton wrapper around the [Ditto] instance.
///
/// Stage 0 wires Ditto with BLE + LAN + AWDL (iOS/macOS only); Wi-Fi Aware
/// (Android) is deliberately *not* enabled because BLE/LAN/AWDL clears every
/// holdout the demo needs without growing the Android permission surface —
/// see plan §Key Technical Decisions ("Ditto transport config") and §U5.
///
/// Default mode is offline-only small-peers with the offline license token.
/// `DITTO_CONNECT=server` opts into a Ditto Server connection authenticated
/// with the Portal development token (see [_validateCredentials]).
library mesh_rag.services.ditto_service;

import 'dart:async';

import 'package:ditto_live/ditto_live.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/study_note.dart';
import '../prompts/dql_queries.dart';

/// `--dart-define=DITTO_APP_ID=…` — the database UUID from the Ditto portal
/// (or any UUID the developer picks for small-peers-only mode).
const String _envAppId = String.fromEnvironment('DITTO_APP_ID');

/// `--dart-define=DITTO_LICENSE=…` — the offline-only license token. Required
/// for small-peers-only mode; sync refuses to start without it.
const String _envLicense = String.fromEnvironment('DITTO_LICENSE');

/// `--dart-define=DITTO_CONNECT=server` — opt-in switch from the default
/// small-peers-only demo wiring to a Ditto Server (cloud) connection. Any
/// other value keeps the Stage 0 offline behavior.
const String _envConnect = String.fromEnvironment('DITTO_CONNECT');

/// `--dart-define=DITTO_SERVER_URL=…` — the URL from the Portal Connect tab.
/// Required when DITTO_CONNECT=server.
const String _envServerUrl = String.fromEnvironment('DITTO_SERVER_URL');

/// `--dart-define=DITTO_DEV_TOKEN=…` — the Portal development token (called
/// "playground token" in some docs). Required when DITTO_CONNECT=server.
const String _envDevToken = String.fromEnvironment('DITTO_DEV_TOKEN');

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

  bool get _isServerMode => _envConnect == 'server';

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
      connect: _envConnect == 'server'
          ? DittoConfigConnectServer(url: _envServerUrl)
          : DittoConfigConnectSmallPeersOnly(),
    ));
    if (_isServerMode) {
      // v5 server connections refuse Sync.start without an expiration
      // handler; authenticate with the development token on demand.
      await ditto.auth.setExpirationHandler((d, _) async {
        await d.auth.login(
          token: _envDevToken,
          provider: Authenticator.developmentProvider,
        );
      });
    } else {
      ditto.setOfflineOnlyLicenseToken(_envLicense);
    }

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
    if (_isServerMode) {
      if (_envServerUrl.isEmpty) {
        throw StateError('DITTO_SERVER_URL is empty. Pass it via '
            '--dart-define=DITTO_SERVER_URL=<portal-connect-url>.');
      }
      if (_envDevToken.isEmpty) {
        throw StateError('DITTO_DEV_TOKEN is empty. Pass it via '
            '--dart-define=DITTO_DEV_TOKEN=<development-token>.');
      }
      return;
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

  // ───── Notes CRUD (typed against StudyNote — see U7) ──────────────────

  /// Insert-or-update a [StudyNote]. The `_id` from `note.toDittoDoc()` is
  /// content-addressed (UUIDv5), so re-running the seed loader is a no-op:
  /// `ON ID CONFLICT DO UPDATE` lands the same document on top of itself.
  Future<void> upsertNote(StudyNote note) async {
    final ditto = _requireDitto();
    await ditto.store
        .execute(NotesQueries.upsert, arguments: {'doc': note.toDittoDoc()});
  }

  /// Materialize the full corpus as a list of typed notes. Used by U9's
  /// retrieval before the brute-force cosine pass. At ≤5k tuples this is
  /// sub-millisecond.
  Future<List<StudyNote>> queryAll() async {
    final ditto = _requireDitto();
    final result = await ditto.store.execute(NotesQueries.selectAll);
    return result.items
        .map((item) => StudyNote.fromDittoValue(item.value))
        .toList(growable: false);
  }

  /// Convenience for retrieval: every note whose embedding has been
  /// backfilled. Filtered in Dart rather than via a DQL `WHERE` because
  /// Ditto v5's MISSING-vs-NULL semantics make embedding predicates
  /// brittle for fresh-seeded notes (plan U9 §Approach).
  Future<List<StudyNote>> queryWithEmbedding() async {
    final all = await queryAll();
    return all.where((n) => n.hasEmbedding).toList(growable: false);
  }

  /// Companion to [setEmbedding]: notes whose embedding column is still
  /// empty. U8's `ensureEmbeddings` iterates this list to backfill the
  /// corpus once Cactus is loaded.
  ///
  /// Filtered in Dart (mirroring [queryWithEmbedding]'s approach)
  /// because Ditto v5's `WHERE embedding IS NULL` predicate doesn't
  /// match notes whose embedding column was inserted as an empty array
  /// `[]` — which is exactly what `StudyNote.toDittoDoc()` produces
  /// before backfill. On-device U12 dry-run surfaced this: SeedLoader
  /// inserted 5 notes, `ensureEmbeddings` reported `backfilled 0`,
  /// retrieval saw `totalEmbedded=0` permanently. Filtering in Dart
  /// against the materialized corpus is the same workaround
  /// `queryWithEmbedding` already uses for the inverse predicate.
  Future<List<StudyNote>> queryMissingEmbedding() async {
    final all = await queryAll();
    return all.where((n) => !n.hasEmbedding).toList(growable: false);
  }

  /// Write `embedding` for a single existing row. Used by the U8 backfill
  /// loop (note → embed → setEmbedding). Stays untyped because it touches
  /// one column rather than the full document.
  Future<void> setEmbedding(String id, List<double> embedding) async {
    final ditto = _requireDitto();
    await ditto.store.execute(
      NotesQueries.setEmbedding,
      arguments: {'id': id, 'embedding': embedding},
    );
  }

  /// Subscribe to changes on the full notes query for live UI updates
  /// (U10's notes tab). The callback receives parsed [StudyNote]s rather
  /// than raw query items so consumers don't have to repeat the parse
  /// at every call site.
  ///
  /// Returns the underlying [StoreObserver] so the caller can `.stop()`
  /// it from `dispose()`.
  StoreObserver subscribeToNotes(void Function(List<StudyNote>) onChange) {
    final ditto = _requireDitto();
    return ditto.store.registerObserver(
      NotesQueries.selectAll,
      onChange: (result) {
        final notes = result.items
            .map((item) => StudyNote.fromDittoValue(item.value))
            .toList(growable: false);
        onChange(notes);
      },
    );
  }

  Ditto _requireDitto() {
    final d = _ditto;
    if (d == null) {
      throw StateError('DittoService used before initialize() completed.');
    }
    return d;
  }

  /// First-sync proof (ditto-first-sync skill): writes one attempt-owned
  /// probe document to the fixed `first_sync_probe` collection and accepts
  /// only the Ditto Server watermark in `system:data_sync_info` reaching the
  /// write's local commit ID as proof. Everything printed is secret-free —
  /// nonces and commit IDs, never configuration values. One bounded attempt
  /// plus at most one retry with a fresh nonce; a timeout is an incomplete
  /// outcome, not a product-failure claim.
  Future<String> runFirstSyncProbe({
    Duration evidenceTimeout = const Duration(seconds: 90),
  }) async {
    final ditto = _requireDitto();
    // Receiver-side readiness: the probe collection participates in sync
    // before the write.
    final subscription =
        ditto.sync.registerSubscription('SELECT * FROM first_sync_probe');
    try {
      var outcome = await _attemptProbe(ditto, evidenceTimeout);
      if (outcome != 'sync-proven') {
        outcome = await _attemptProbe(ditto, evidenceTimeout);
      }
      return outcome;
    } finally {
      subscription.cancel();
    }
  }

  Future<String> _attemptProbe(Ditto ditto, Duration evidenceTimeout) async {
    const collection = 'first_sync_probe';
    final nonce = const Uuid().v4();
    final id = 'first-sync-$nonce';
    final deadline = DateTime.now().toUtc().add(evidenceTimeout);
    debugPrint('first-sync probe: attempt $id (nonce generated after the '
        'probe subscription was registered)');

    final written = await ditto.store.execute(
      'INSERT INTO $collection DOCUMENTS (:doc)',
      arguments: {
        'doc': {'_id': id, 'nonce': nonce, 'attempt': id},
      },
    );
    final commitId = written.commitID;
    debugPrint('first-sync probe: local commit id '
        '${commitId ?? 'unexposed — cannot bind a watermark'}');
    if (commitId == null) {
      await _cleanupProbe(ditto, collection, id);
      return 'local-store-proven';
    }

    // Local readback is supporting evidence only.
    final readback = await ditto.store.execute(
      'SELECT * FROM $collection WHERE _id = :id',
      arguments: {'id': id},
    );
    final localProven = readback.items.isNotEmpty;

    while (DateTime.now().toUtc().isBefore(deadline)) {
      final rows = await ditto.store
          .execute('SELECT * FROM system:data_sync_info');
      for (final row in rows.items) {
        final watermark = row.value['synced_up_to_local_commit_id'];
        if (watermark is int && watermark >= commitId) {
          debugPrint('first-sync probe: server watermark $watermark covers '
              'commit $commitId at ${DateTime.now().toUtc()}');
          await _cleanupProbe(ditto, collection, id);
          return 'sync-proven';
        }
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    await _cleanupProbe(ditto, collection, id);
    return localProven ? 'local-store-proven' : 'ran';
  }

  /// Deletes only the document created by this attempt. Cleanup failure is
  /// reported with the remaining probe ID and does not demote proof.
  Future<void> _cleanupProbe(
      Ditto ditto, String collection, String id) async {
    try {
      await ditto.store.execute(
        'DELETE FROM $collection WHERE _id = :id',
        arguments: {'id': id},
      );
    } catch (error) {
      debugPrint('first-sync probe: cleanup failed; remaining probe $id '
          '(${error.runtimeType})');
    }
  }

  /// Process-exit teardown for the first-sync proof runner (main.dart probe
  /// mode). Shares the test teardown path.
  Future<void> shutdown() => dispose();

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
