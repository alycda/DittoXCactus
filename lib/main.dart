import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/cactus_service.dart';
import 'services/ditto_service.dart';
import 'services/retrieval_service.dart';
import 'services/seed_loader.dart';
import 'widgets/query_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ].request();
  }

  runApp(const MeshRagApp());
}

class MeshRagApp extends StatelessWidget {
  const MeshRagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mesh RAG Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const BootScreen(),
    );
  }
}

/// Splash + init flow. Boots Ditto + Cactus + seed insert + ensureEmbeddings,
/// then swaps in QueryScreen. The flow is intentionally one-shot — no
/// settings UI, no retry button — Stage 0 is "run once on demo day."
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  String _stage = 'starting…';
  double? _modelDownloadProgress;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      setState(() => _stage = 'connecting to mesh');
      await DittoService.instance.initialize();
      await DittoService.instance.startSync(
        subscriptionQuery: 'SELECT * FROM recipes',
      );

      setState(() => _stage = 'seeding local corpus (role=${SeedLoader.instance.role})');
      await SeedLoader.instance.loadAndInsert();

      setState(() => _stage = 'downloading cactus model');
      await CactusService.instance.initialize(
        onProgress: (p, status, isErr) {
          if (!mounted) return;
          setState(() {
            _modelDownloadProgress = p;
            _stage = status;
          });
        },
      );

      setState(() {
        _stage = 'embedding local corpus';
        _modelDownloadProgress = null;
      });
      await RetrievalService.instance.ensureEmbeddings();

      setState(() => _ready = true);
    } catch (e, st) {
      debugPrint('boot error: $e');
      debugPrint(st.toString());
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const QueryScreen();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mesh RAG — Stage 0',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_error == null) ...[
                  Text(
                    _stage,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: _modelDownloadProgress),
                ] else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
