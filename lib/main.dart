// Mesh-RAG demo entry point.
//
// Two phones each hold a slice of a study-notes corpus; they meet over
// BLE/Wi-Fi and the vector index merges as a CRDT, so a query on one phone
// draws on the other's notes after handshake — with WAN off.
//
// The boot sequence runs once at app launch:
//   1. DittoService.initialize + startSync   (U5)
//   2. SeedLoader.loadAndInsert               (U8)
//   3. CactusService.initialize               (U6)
//   4. RetrievalService.ensureEmbeddings      (U8)
// then swaps in QueryScreen (U10) for the live UI.
//
// U4 lands the skeleton. U5–U10 fill in the boot steps via Modify-to-this-file
// rather than via add-a-new-app-shell, so the structure of `_BootScreenState`
// is the join point — each step is a labelled future that progresses the
// `_BootPhase` state machine.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

/// Phone-role env var (`PHONE_ROLE=a` or `PHONE_ROLE=b`) — selects which
/// seed_notes_<role>.json the SeedLoader (U8) preloads. Empty string at
/// boot time is a fatal config error and BootScreen surfaces it.
const String kPhoneRole = String.fromEnvironment('PHONE_ROLE');

void main() {
  // U5's `Approach` calls `permission_handler` here (bluetoothConnect,
  // bluetoothAdvertise, bluetoothScan, nearbyWifiDevices). U4 leaves the
  // hook explicit so U5 has an unambiguous place to wire it.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MeshRagApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// Root app
// ─────────────────────────────────────────────────────────────────────────────

class MeshRagApp extends StatelessWidget {
  const MeshRagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mesh RAG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BootScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Boot sequence
// ─────────────────────────────────────────────────────────────────────────────

/// Discrete phases of app boot. The UI shows the current phase as a status
/// line so demo-day failures point at the right service. Each subsequent
/// unit fills in the corresponding `_run<Phase>` step and advances the state.
enum _BootPhase {
  starting,
  initDitto, // U5
  startSync, // U5
  seedLoad, // U8
  initCactus, // U6
  ensureEmbeddings, // U8
  ready,
  failed,
}

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  _BootPhase _phase = _BootPhase.starting;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      _validatePhoneRole();

      // U5: DittoService.instance.initialize() + startSync()
      _advance(_BootPhase.initDitto);
      // TODO(U5): await DittoService.instance.initialize();
      _advance(_BootPhase.startSync);
      // TODO(U5): await DittoService.instance.startSync(
      //     subscriptionQuery: 'SELECT * FROM notes');

      // U8: SeedLoader reads assets/seed_notes_<role>.json and upserts.
      _advance(_BootPhase.seedLoad);
      // TODO(U8): await SeedLoader.loadAndInsert(role: kPhoneRole);

      // U6: CactusService brings up the two CactusLM instances.
      _advance(_BootPhase.initCactus);
      // TODO(U6): await CactusService.instance.initialize();

      // U8 (second pass): RetrievalService backfills embeddings for any
      // notes whose embedding column is still null.
      _advance(_BootPhase.ensureEmbeddings);
      // TODO(U8): await RetrievalService.instance.ensureEmbeddings();

      _advance(_BootPhase.ready);
    } catch (e, st) {
      if (kDebugMode) debugPrint('Boot failed at $_phase: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _phase = _BootPhase.failed;
      });
    }
  }

  void _validatePhoneRole() {
    if (kPhoneRole != 'a' && kPhoneRole != 'b') {
      throw StateError(
          'PHONE_ROLE must be passed via --dart-define=PHONE_ROLE=a (or =b). '
          'Got "$kPhoneRole".');
    }
  }

  void _advance(_BootPhase next) {
    if (!mounted) return;
    setState(() => _phase = next);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _BootPhase.ready) {
      return const QueryScreen();
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _phase == _BootPhase.failed
              ? _FailedView(error: _error)
              : _BootingView(phase: _phase),
        ),
      ),
    );
  }
}

class _BootingView extends StatelessWidget {
  const _BootingView({required this.phase});
  final _BootPhase phase;

  String get _label {
    switch (phase) {
      case _BootPhase.starting:
        return 'Starting…';
      case _BootPhase.initDitto:
        return 'Bringing up Ditto…';
      case _BootPhase.startSync:
        return 'Starting mesh sync…';
      case _BootPhase.seedLoad:
        return 'Loading seed notes…';
      case _BootPhase.initCactus:
        return 'Loading Cactus models…';
      case _BootPhase.ensureEmbeddings:
        return 'Embedding corpus…';
      case _BootPhase.ready:
      case _BootPhase.failed:
        return ''; // not used in this view
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Mesh RAG',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_label, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Boot failed',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(
            error?.toString() ?? 'Unknown error',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Query screen — placeholder; U10 ships the two-tab Scaffold + mesh status
// pill + per-card source attribution. U4 just gives later units a real
// destination Widget to swap to once boot completes.
// ─────────────────────────────────────────────────────────────────────────────

class QueryScreen extends StatelessWidget {
  const QueryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh RAG'),
        // U10 will add MeshStatusWidget (`mesh: alone` / `mesh: N peers`)
        // here as the AppBar's trailing widget.
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Boot complete.\n\nU10 will land the notes + flashcards tabs here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
