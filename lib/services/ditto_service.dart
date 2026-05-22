import 'dart:async';
import 'dart:io' show Platform;

import 'package:ditto_live/ditto_live.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/study_note.dart';
import '../prompts/dql_queries.dart';

/// Owns the global Ditto lifecycle: init, license token, transport config,
/// sync, presence stream, and CRUD over `StudyNote`. Stage 0 uses
/// **small-peers-only** mode (no Big Peer).
///
/// Configuration is provided at build time via `--dart-define`:
/// - `DITTO_APP_ID` — UUID of the development app (required).
/// - `DITTO_LICENSE` — offline license token (required for P2P).
class DittoService {
  DittoService._();
  static final DittoService instance = DittoService._();

  Ditto? _ditto;
  String? _localPeerKey;
  PresenceObserver? _presenceObserver;
  final _peerCountController = StreamController<int>.broadcast();

  Ditto get ditto {
    final d = _ditto;
    if (d == null) {
      throw StateError('DittoService.initialize() must be awaited first');
    }
    return d;
  }

  String get localPeerKey => _localPeerKey ?? '';
  Stream<int> get peerCount => _peerCountController.stream;
  bool get isReady => _ditto != null;

  static const String _envAppId = String.fromEnvironment(
    'DITTO_APP_ID',
    defaultValue: '',
  );
  static const String _envLicense = String.fromEnvironment(
    'DITTO_LICENSE',
    defaultValue: '',
  );

  Future<void> initialize() async {
    if (_ditto != null) return;
    if (_envAppId.isEmpty) {
      throw StateError(
        'DITTO_APP_ID is not set. Pass via '
        '--dart-define=DITTO_APP_ID=<uuid> on flutter run/build.',
      );
    }
    if (_envLicense.isEmpty) {
      throw StateError(
        'DITTO_LICENSE is not set. Pass via '
        '--dart-define=DITTO_LICENSE=<offline-token> on flutter run/build.',
      );
    }

    await Ditto.init();

    final config = DittoConfig(
      databaseID: _envAppId,
      connect: const DittoConfigConnectSmallPeersOnly(),
    );
    final d = await Ditto.open(config);
    d.setOfflineOnlyLicenseToken(_envLicense);

    d.updateTransportConfig((c) {
      if (kIsWeb) return;
      c.peerToPeer.bluetoothLE.isEnabled = true;
      c.peerToPeer.lan.isEnabled = true;
      if (Platform.isIOS || Platform.isMacOS) {
        c.peerToPeer.awdl.isEnabled = true;
      }
    });

    _localPeerKey = d.presence.graph.localPeer.peerKey;
    _presenceObserver = d.presence.observe((graph) {
      _peerCountController.add(graph.remotePeers.length);
    });

    _ditto = d;
  }

  Future<void> startSync({String? subscriptionQuery}) async {
    if (subscriptionQuery != null) {
      ditto.sync.registerSubscription(subscriptionQuery);
    }
    ditto.sync.start();
  }

  void stopSync() => _ditto?.sync.stop();

  // ---------------------------------------------------------------------------
  // StudyNote CRUD

  /// Idempotent insert: same `_id` lands as an update, so re-running the seed
  /// loader doesn't duplicate notes (verification gate for R3).
  Future<void> upsertNote(StudyNote note) async {
    await ditto.store.execute(
      NotesQueries.upsert,
      arguments: {'doc': note.toDittoDoc()},
    );
  }

  Future<List<StudyNote>> queryAll() async {
    final r = await ditto.store.execute(NotesQueries.selectAll);
    return r.items
        .map((it) => StudyNote.fromDittoValue(Map<String, dynamic>.from(it.value)))
        .toList();
  }

  /// Dart-side filter — Ditto's MISSING vs NULL semantics + the `embedding`
  /// field being absent on fresh seeds make a DQL predicate brittle here, and
  /// the Stage 0 corpus is ≤ 10 rows so the cost is invisible.
  Future<List<StudyNote>> queryWithEmbedding() async {
    final all = await queryAll();
    return all.where((n) => n.hasEmbedding).toList();
  }

  Future<List<StudyNote>> queryMissingEmbedding() async {
    final all = await queryAll();
    return all.where((n) => !n.hasEmbedding).toList();
  }

  Future<void> setEmbedding(String id, List<double> embedding) async {
    await ditto.store.execute(
      NotesQueries.setEmbedding,
      arguments: {'id': id, 'embedding': embedding},
    );
  }

  /// Live updates: callback fires whenever a `StudyNote` is added, modified,
  /// or removed (locally or via mesh sync).
  StoreObserver subscribeToNotes(void Function(List<StudyNote>) onChange) {
    return ditto.store.registerObserver(
      NotesQueries.selectAll,
      onChange: (result) {
        final rows = result.items
            .map((it) => StudyNote.fromDittoValue(Map<String, dynamic>.from(it.value)))
            .toList();
        onChange(rows);
      },
    );
  }

  Future<void> dispose() async {
    _presenceObserver?.stop();
    await _peerCountController.close();
    _ditto?.sync.stop();
    _ditto = null;
  }
}
