import 'dart:async';

import 'package:flutter/material.dart';

import '../services/retrieval_service.dart';
import '../services/seed_loader.dart';
import 'mesh_status_widget.dart';

/// The Stage-0 demo screen: one input, one streaming answer pane, mesh-status
/// pill, and the "N tuples (M from peers)" attribution footer. Optimized for
/// camera legibility, not production polish.
class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key});

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  final _controller = TextEditingController();
  final _answer = StringBuffer();
  List<RetrievedRecipe> _retrieved = const [];
  StreamSubscription<AnswerEvent>? _sub;
  bool _busy = false;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_busy) return; // debounce double-tap (U8 edge case)
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _busy = true;
      _answer.clear();
      _retrieved = const [];
    });

    _sub?.cancel();
    _sub = RetrievalService.instance.answerQuery(query).listen(
      (event) {
        if (!mounted) return;
        if (event.retrieved != null) {
          setState(() => _retrieved = event.retrieved!);
        } else if (event.token != null) {
          setState(() => _answer.write(event.token));
        } else if (event.isDone) {
          setState(() => _busy = false);
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _answer.write('\n\n[error: $e]');
          _busy = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromPeerCount = _retrieved
        .where((r) => r.recipe.contributor != SeedLoader.instance.selfContributor)
        .length;

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
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _ask(),
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                hintText: 'ask the mesh',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, size: 28),
                  onPressed: _busy ? null : _ask,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _answer.isEmpty
                        ? (_busy ? 'thinking…' : 'ask a question above.')
                        : _answer.toString(),
                    style: const TextStyle(fontSize: 18, height: 1.45),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_retrieved.isNotEmpty)
              Text(
                'drew on ${_retrieved.length} tuple${_retrieved.length == 1 ? '' : 's'}'
                ' ($fromPeerCount from peer${fromPeerCount == 1 ? '' : 's'})',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
