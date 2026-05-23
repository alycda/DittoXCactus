import 'package:flutter/material.dart';

import 'services/cactus_service.dart';
import 'services/ditto_service.dart';
import 'widgets/query_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Eager-load both runtimes so the first query is fast.
  await DittoService.instance.init();
  await CactusService.instance.initialize();
  runApp(const MeshRagApp());
}

class MeshRagApp extends StatelessWidget {
  const MeshRagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mesh RAG',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const QueryScreen(),
    );
  }
}
