import 'dart:async';

import 'package:flutter/material.dart';

import '../prompts/flashcard_gen.dart';
import '../services/retrieval_service.dart';
import '../services/seed_loader.dart';

/// The flashcard surface. Topic input + spark to generate; renders the
/// resulting cards as a swipeable stack with flip-on-tap. Tracks a small
/// history so the audience can see *how* a card changed when a peer
/// joined the mesh.
///
/// Visible-improvement surfaces, in increasing depth:
/// - Aggregate footer ("drew on N notes — M from peers")
/// - Generation counter ("gen #2 — drew on 10 notes (5 from peers)")
/// - Per-card peer badge (card.sourceNoteIds includes peer-contributed ids)
/// - Diff alt-view: previous generation vs current, NEW cards highlighted
///
/// Layout responds to OrientationBuilder so landscape (the natural pose for
/// flipping cards) gets a single big card; portrait keeps the stack.
class FlashcardsTab extends StatefulWidget {
  const FlashcardsTab({super.key});

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

class _Generation {
  final int index;
  final List<Flashcard> cards;
  final List<RetrievedNote> retrieved;
  final Set<String> peerNoteIds;
  final DateTime at;
  const _Generation({
    required this.index,
    required this.cards,
    required this.retrieved,
    required this.peerNoteIds,
    required this.at,
  });

  int get peerNoteCount => retrieved
      .where((r) => peerNoteIds.contains(r.note.id))
      .length;
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  final _controller = TextEditingController(text: 'the solar system');
  final List<_Generation> _history = [];
  List<Flashcard> _currentCards = const [];
  List<RetrievedNote> _retrieved = const [];
  StreamSubscription<FlashcardEvent>? _sub;
  bool _busy = false;
  String? _error;
  bool _showDiff = false;

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_busy) return;
    final topic = _controller.text.trim();
    if (topic.isEmpty) return;

    setState(() {
      _busy = true;
      _currentCards = const [];
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
          _commitGeneration(event.cards!);
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

  void _commitGeneration(List<Flashcard> cards) {
    final self = SeedLoader.instance.selfContributor;
    final peerNoteIds = <String>{
      for (final r in _retrieved)
        if (r.note.contributor != self) r.note.id,
    };
    final gen = _Generation(
      index: _history.length + 1,
      cards: cards,
      retrieved: List.unmodifiable(_retrieved),
      peerNoteIds: peerNoteIds,
      at: DateTime.now(),
    );
    setState(() {
      _history.add(gen);
      _currentCards = cards;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPromptRow(),
          const SizedBox(height: 12),
          _buildGenerationHeader(theme),
          const SizedBox(height: 12),
          Expanded(child: _buildBody(theme)),
          const SizedBox(height: 8),
          _buildAttributionFooter(theme),
        ],
      ),
    );
  }

  Widget _buildPromptRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _ask(),
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              hintText: 'topic',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _busy ? null : _ask,
          icon: const Icon(Icons.auto_awesome),
          label: Text(_history.isEmpty ? 'generate' : 'regenerate'),
        ),
      ],
    );
  }

  Widget _buildGenerationHeader(ThemeData theme) {
    if (_history.isEmpty) return const SizedBox.shrink();
    final latest = _history.last;
    final newCount = _newCardCount(latest);
    final hasDiff = _history.length >= 2;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'gen #${latest.index}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        if (hasDiff && newCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+$newCount new since last',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        const Spacer(),
        if (hasDiff)
          TextButton.icon(
            onPressed: () => setState(() => _showDiff = !_showDiff),
            icon: Icon(_showDiff ? Icons.style : Icons.compare_arrows),
            label: Text(_showDiff ? 'cards' : 'diff'),
          ),
      ],
    );
  }

  Widget _buildAttributionFooter(ThemeData theme) {
    if (_retrieved.isEmpty) return const SizedBox.shrink();
    final self = SeedLoader.instance.selfContributor;
    final peers = _retrieved.where((r) => r.note.contributor != self).length;
    return Text(
      'drew on ${_retrieved.length} note${_retrieved.length == 1 ? '' : 's'}'
      ' ($peers from peer${peers == 1 ? '' : 's'})',
      style: TextStyle(
        fontSize: 14,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
    if (_busy && _currentCards.isEmpty) {
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
    if (_currentCards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'enter a topic and tap generate to make flashcards.\n\n'
            'tip: when a peer joins the mesh, regenerate — the same topic '
            'will produce cards that draw on their notes too.',
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_showDiff && _history.length >= 2) {
      return _DiffView(
        prev: _history[_history.length - 2],
        curr: _history.last,
        peerNoteIds: _history.last.peerNoteIds,
      );
    }
    return _FlashcardStack(
      cards: _currentCards,
      peerNoteIds: _history.isEmpty ? const {} : _history.last.peerNoteIds,
    );
  }

  int _newCardCount(_Generation latest) {
    if (_history.length < 2) return 0;
    final prev = _history[_history.length - 2].cards
        .map((c) => _normalize(c.question))
        .toSet();
    return latest.cards
        .where((c) => !prev.contains(_normalize(c.question)))
        .length;
  }

  static String _normalize(String s) => s.toLowerCase().trim();
}

/// A swipeable, flip-on-tap stack of flashcards. Portrait shows ~one card
/// at a time via PageView; landscape gives the same card more breathing
/// room but keeps the same swipe affordance.
class _FlashcardStack extends StatefulWidget {
  final List<Flashcard> cards;
  final Set<String> peerNoteIds;
  const _FlashcardStack({required this.cards, required this.peerNoteIds});

  @override
  State<_FlashcardStack> createState() => _FlashcardStackState();
}

class _FlashcardStackState extends State<_FlashcardStack> {
  late final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant _FlashcardStack old) {
    super.didUpdateWidget(old);
    if (old.cards != widget.cards) {
      // New generation arrived — snap back to the first card.
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

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
              final card = widget.cards[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: _FlashcardTile(
                  key: ValueKey('card-$i-${card.question}'),
                  card: card,
                  index: i,
                  total: widget.cards.length,
                  drewFromPeers: card.sourceNoteIds
                      .any(widget.peerNoteIds.contains),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.cards.length,
            (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 9,
              height: 9,
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

class _FlashcardTile extends StatefulWidget {
  final Flashcard card;
  final int index;
  final int total;
  final bool drewFromPeers;
  const _FlashcardTile({
    super.key,
    required this.card,
    required this.index,
    required this.total,
    required this.drewFromPeers,
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
    return OrientationBuilder(
      builder: (context, orientation) {
        final landscape = orientation == Orientation.landscape;
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
            padding: EdgeInsets.all(landscape ? 32 : 24),
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (widget.drewFromPeers) ...[
                          const _PeerBadge(),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          isFront ? 'tap to reveal' : 'tap to flip back',
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: landscape ? 24 : 16),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        isFront ? widget.card.question : widget.card.answer,
                        style: TextStyle(
                          fontSize: isFront
                              ? (landscape ? 32 : 24)
                              : (landscape ? 24 : 20),
                          height: 1.4,
                          color: isFront
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSecondaryContainer,
                          fontWeight: isFront
                              ? FontWeight.w600
                              : FontWeight.w400,
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
      },
    );
  }
}

class _PeerBadge extends StatelessWidget {
  const _PeerBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bluetooth, size: 12, color: theme.colorScheme.onTertiary),
          const SizedBox(width: 4),
          Text(
            'peer',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alt-view that pairs the previous generation against the current one so
/// the audience can see exactly what changed. Cards with question text that
/// didn't appear in the prior generation get a NEW badge; cards drawing on
/// peer notes get the peer badge regardless of whether the question is new.
class _DiffView extends StatelessWidget {
  final _Generation prev;
  final _Generation curr;
  final Set<String> peerNoteIds;
  const _DiffView({
    required this.prev,
    required this.curr,
    required this.peerNoteIds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prevQs = prev.cards
        .map((c) => c.question.toLowerCase().trim())
        .toSet();
    final newCount = curr.cards
        .where((c) => !prevQs.contains(c.question.toLowerCase().trim()))
        .length;
    return ListView(
      children: [
        _DiffHeader(
          label: 'before sync (gen #${prev.index})',
          subtitle: '${prev.cards.length} cards · '
              '${prev.retrieved.length} notes (${prev.peerNoteCount} from peers)',
          color: theme.colorScheme.outline,
        ),
        ...prev.cards.map(
          (c) => _DiffCardRow(
            card: c,
            faded: true,
            isNew: false,
            drewFromPeers: false,
          ),
        ),
        const SizedBox(height: 24),
        _DiffHeader(
          label: 'after sync (gen #${curr.index})',
          subtitle: '${curr.cards.length} cards · '
              '${curr.retrieved.length} notes (${curr.peerNoteCount} from peers)'
              '${newCount > 0 ? " · +$newCount new" : ""}',
          color: theme.colorScheme.primary,
        ),
        ...curr.cards.map(
          (c) => _DiffCardRow(
            card: c,
            faded: false,
            isNew: !prevQs.contains(c.question.toLowerCase().trim()),
            drewFromPeers: c.sourceNoteIds.any(peerNoteIds.contains),
          ),
        ),
      ],
    );
  }
}

class _DiffHeader extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  const _DiffHeader({
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 6, height: 28, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffCardRow extends StatelessWidget {
  final Flashcard card;
  final bool faded;
  final bool isNew;
  final bool drewFromPeers;
  const _DiffCardRow({
    required this.card,
    required this.faded,
    required this.isNew,
    required this.drewFromPeers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alpha = faded ? 0.45 : 1.0;
    return Card(
      color: isNew
          ? theme.colorScheme.tertiaryContainer
          : theme.colorScheme.surfaceContainerLow.withValues(alpha: alpha),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isNew) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (drewFromPeers) ...[
                  const _PeerBadge(),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    card.question,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: alpha,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              card.answer,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: alpha),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
