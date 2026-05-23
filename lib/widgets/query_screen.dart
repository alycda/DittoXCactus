import 'dart:async';

import 'package:flutter/material.dart';

import '../services/retrieval_service.dart';
import 'mesh_status_widget.dart';

/// Stage-0 demo surface: one text input, one streaming answer pane, one
/// attribution footer. The mesh-status pill lives in the app bar so the
/// "alone → connected" transition is on camera at all times.
class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key});

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  final _controller = TextEditingController();
  String _answer = '';
  List<RetrievedNote> _retrieved = const [];
  bool _streaming = false;
  StreamSubscription<String>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _runQuery() {
    final topic = _controller.text.trim();
    if (topic.isEmpty) return;
    _sub?.cancel();
    setState(() {
      _streaming = true;
      _answer = '';
      _retrieved = const [];
    });
    _sub = RetrievalService.instance
        .answerQuery(
          topic,
          onRetrieved: (r) {
            if (mounted) setState(() => _retrieved = r);
          },
        )
        .listen(
          (chunk) {
            if (mounted) setState(() => _answer += chunk);
          },
          onDone: () {
            if (mounted) setState(() => _streaming = false);
          },
          onError: (Object e) {
            if (mounted) {
              setState(() {
                _streaming = false;
                _answer += '\n\n[error: $e]';
              });
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh RAG'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: MeshStatusWidget()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Ask the mesh',
                      hintText: 'e.g. "What are gas giants?"',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _runQuery(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  icon: _streaming
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  onPressed: _streaming ? null : _runQuery,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _answer.isEmpty && !_streaming
                      ? 'Ask a question. The answer is synthesized on-device '
                            'from notes retrieved across the mesh.'
                      : _answer,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              ),
            ),
            if (_retrieved.isNotEmpty) _AttributionFooter(retrieved: _retrieved),
          ],
        ),
      ),
    );
  }
}

class _AttributionFooter extends StatelessWidget {
  final List<RetrievedNote> retrieved;

  const _AttributionFooter({required this.retrieved});

  @override
  Widget build(BuildContext context) {
    final byContributor = <String, int>{};
    for (final r in retrieved) {
      byContributor.update(r.note.contributor, (n) => n + 1, ifAbsent: () => 1);
    }
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.source, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'from ${retrieved.length} note${retrieved.length == 1 ? '' : 's'}: '
              '${byContributor.entries.map((e) => "${e.key}×${e.value}").join(", ")}',
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
