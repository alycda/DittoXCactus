import 'dart:async';
import 'dart:io' show Platform;

import 'package:ditto_live/ditto_live.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Owns the global Ditto lifecycle: init, license token, transport config,
/// sync, presence stream. Stage 0 uses **small-peers-only** mode (no Big Peer).
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

  Future<void> dispose() async {
    _presenceObserver?.stop();
    await _peerCountController.close();
    _ditto?.sync.stop();
    _ditto = null;
  }
}
