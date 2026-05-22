import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/cactus_service.dart';
import 'services/ditto_service.dart';
import 'services/seed_loader.dart';

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
      home: const InitScreen(),
    );
  }
}

/// Stage-0 placeholder. Init both SDKs, show "Cactus: ready / Ditto: peers=N"
/// so the implementer can verify on hardware that U1 is done.
/// U8 replaces this with the actual query screen.
class InitScreen extends StatefulWidget {
  const InitScreen({super.key});

  @override
  State<InitScreen> createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> {
  String _cactusStatus = 'idle';
  String _dittoStatus = 'idle';
  double? _modelDownloadProgress; // null = indeterminate
  int _peerCount = 0;
  int _localRecipeCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      setState(() => _dittoStatus = 'initializing');
      await DittoService.instance.initialize();
      await DittoService.instance.startSync(
        subscriptionQuery: 'SELECT * FROM recipes',
      );
      DittoService.instance.peerCount.listen((n) {
        if (mounted) setState(() => _peerCount = n);
      });
      DittoService.instance.subscribeToRecipes((rows) {
        if (mounted) setState(() => _localRecipeCount = rows.length);
      });
      await SeedLoader.instance.loadAndInsert();
      setState(() => _dittoStatus = 'ready (role=${SeedLoader.instance.role})');
    } catch (e) {
      setState(() {
        _dittoStatus = 'failed';
        _error = e.toString();
      });
    }

    try {
      setState(() => _cactusStatus = 'downloading model');
      await CactusService.instance.initialize(
        onProgress: (p, status, isErr) {
          if (mounted) {
            setState(() {
              _modelDownloadProgress = p;
              _cactusStatus = status;
            });
          }
        },
      );
      setState(() {
        _cactusStatus = 'ready';
        _modelDownloadProgress = null;
      });
    } catch (e) {
      setState(() {
        _cactusStatus = 'failed';
        _error = '${_error ?? ''}\nCactus: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mesh RAG — Stage 0')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line('Ditto', _dittoStatus, ok: _dittoStatus.startsWith('ready')),
              const SizedBox(height: 8),
              Text('  peers: $_peerCount   |   local recipes: $_localRecipeCount'),
              const SizedBox(height: 24),
              _line('Cactus', _cactusStatus, ok: _cactusStatus == 'ready'),
              if (_modelDownloadProgress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _modelDownloadProgress),
              ],
              if (_error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String status, {required bool ok}) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.hourglass_empty,
          color: ok ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $status',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
