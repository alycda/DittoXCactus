import 'dart:async';

import 'package:flutter/material.dart';

import '../prompts/flashcard_gen.dart';
import '../services/retrieval_service.dart';
import '../services/seed_loader.dart';
import 'mesh_status_widget.dart';

/// The Stage-0.5 demo screen: topic input, mesh-status pill, flashcard stack
/// with flip-on-tap and swipe-to-advance, and the "drew on N notes (M from
/// peers)" attribution footer. Optimized for camera legibility, not
/// production polish.
class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key});

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  final _controller = TextEditingController(text: 'the solar system');
  List<RetrievedNote> _retrieved = const [];
  List<Flashcard> _cards = const [];
  StreamSubscription<FlashcardEvent>? _sub;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_busy) return; // debounce double-tap (U8 edge case)
    final topic = _controller.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _busy = true;
      _cards = const [];
      _retrieved = const [];
      _error = null;
    });

    _sub?.cancel();
    _sub = RetrievalService.instance.generateFlashcards(topic).listen(
      (event) {
        if (!mounted) return;
        if (event.retrieved != null) {
          setState(() => _retrieved = event.retrieved!);
        } else if (event.cards != null) {
          setState(() => _cards = event.cards!);
        } else if (event.isDone) {
          setState(() => _busy = false);
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selfContributor = SeedLoader.instance.selfContributor;
    final fromPeerCount = _retrieved
        .where((r) => r.note.contributor != selfContributor)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Together'),
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
                hintText: 'topic for flashcards',
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
                  icon: const Icon(Icons.auto_awesome, size: 28),
                  tooltip: 'make flashcards',
                  onPressed: _busy ? null : _ask,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildBody(theme),
            ),
            const SizedBox(height: 12),
            if (_retrieved.isNotEmpty)
              Text(
                'drew on ${_retrieved.length} note${_retrieved.length == 1 ? '' : 's'}'
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

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          _error!,
          style: TextStyle(
            color: theme.colorScheme.onErrorContainer,
            fontFamily: 'monospace',
          ),
        ),
      );
    }
    if (_busy && _cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _retrieved.isEmpty
                  ? 'retrieving notes…'
                  : 'generating ${RetrievalService.defaultN} flashcards…',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }
    if (_cards.isEmpty) {
      return Center(
        child: Text(
          'enter a topic and tap the spark to generate flashcards.',
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    return _FlashcardStack(cards: _cards);
  }
}

/// A swipeable, flip-on-tap stack of flashcards. PageView for horizontal
/// swipe; each page is a `_FlashcardTile` with its own flip state.
class _FlashcardStack extends StatefulWidget {
  final List<Flashcard> cards;
  const _FlashcardStack({required this.cards});

  @override
  State<_FlashcardStack> createState() => _FlashcardStackState();
}

class _FlashcardStackState extends State<_FlashcardStack> {
  late final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.cards.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _FlashcardTile(
                  key: ValueKey('card-$i-${widget.cards[i].question}'),
                  card: widget.cards[i],
                  index: i,
                  total: widget.cards.length,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.cards.length,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _currentPage
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single flashcard. Tap to flip between question (front) and answer
/// (back). Source-note count is shown on the back so the audience can see
/// when a card draws on multiple peers' notes.
class _FlashcardTile extends StatefulWidget {
  final Flashcard card;
  final int index;
  final int total;
  const _FlashcardTile({
    super.key,
    required this.card,
    required this.index,
    required this.total,
  });

  @override
  State<_FlashcardTile> createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<_FlashcardTile> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFront = !_showAnswer;
    return GestureDetector(
      onTap: () => setState(() => _showAnswer = !_showAnswer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isFront
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.index + 1} / ${widget.total}',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  isFront ? 'tap to reveal' : 'tap to flip back',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: SelectableText(
                    isFront ? widget.card.question : widget.card.answer,
                    style: TextStyle(
                      fontSize: isFront ? 24 : 20,
                      height: 1.4,
                      color: isFront
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSecondaryContainer,
                      fontWeight: isFront ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            if (!isFront && widget.card.sourceNoteIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'from ${widget.card.sourceNoteIds.length} note'
                  '${widget.card.sourceNoteIds.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSecondaryContainer
                        .withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
