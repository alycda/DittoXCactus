import 'dart:async';

import 'package:flutter/material.dart';

import '../models/study_note.dart';
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
/// - Rate mode: swipe-right (keep) / swipe-left (reject) per card. Kept
///   cards are saved as few-shot exemplars and folded into the prompt on
///   the next regenerate — the model learns the user's preferred style
///   without fine-tuning, all on-device.
///
/// Layout responds to OrientationBuilder so landscape (the natural pose for
/// flipping cards) gets a single big card; portrait keeps the stack.
class FlashcardsTab extends StatefulWidget {
  const FlashcardsTab({super.key});

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

enum CardRating { unrated, up, down }

enum FlashcardsMode { view, rate }

class _Generation {
  final int index;
  final List<Flashcard> cards;
  final List<RetrievedNote> retrieved;
  final Set<String> peerNoteIds;
  final List<Flashcard> savedExamplesUsed; // exemplars folded into this gen
  final DateTime at;
  final List<CardRating> ratings; // mutable; one per card

  _Generation({
    required this.index,
    required this.cards,
    required this.retrieved,
    required this.peerNoteIds,
    required this.savedExamplesUsed,
    required this.at,
  }) : ratings = List<CardRating>.filled(cards.length, CardRating.unrated);

  int get peerNoteCount =>
      retrieved.where((r) => peerNoteIds.contains(r.note.id)).length;

  int get upCount => ratings.where((r) => r == CardRating.up).length;
  int get downCount => ratings.where((r) => r == CardRating.down).length;
  bool get allRated => ratings.every((r) => r != CardRating.unrated);

  /// Lookup table for resolving a card's sourceNoteIds back to the note body
  /// the LLM claimed to draw from. Built lazily.
  late final Map<String, StudyNote> notesById = {
    for (final r in retrieved) r.note.id: r.note,
  };
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  final _controller = TextEditingController(text: 'the solar system');
  final List<_Generation> _history = [];
  // Cumulative across regenerations. Up-rated cards land here; the next
  // generation passes the most-recent slice as few-shot exemplars to the
  // prompt so the model mirrors the user's preferred style.
  final List<Flashcard> _savedGoodCards = [];
  List<Flashcard> _currentCards = const [];
  List<RetrievedNote> _retrieved = const [];
  StreamSubscription<FlashcardEvent>? _sub;
  bool _busy = false;
  String? _error;
  bool _showDiff = false;
  FlashcardsMode _mode = FlashcardsMode.view;

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

    // Snapshot the saved-card slice we're about to use, so the generation
    // can record exactly which exemplars influenced it.
    final examplesForThisGen = _savedGoodCards
        .reversed
        .take(3)
        .toList()
        .reversed
        .toList();

    setState(() {
      _busy = true;
      _currentCards = const [];
      _retrieved = const [];
      _error = null;
    });

    _sub?.cancel();
    _sub = RetrievalService.instance
        .generateFlashcards(topic, savedExamples: examplesForThisGen)
        .listen(
      (event) {
        if (!mounted) return;
        if (event.retrieved != null) {
          setState(() => _retrieved = event.retrieved!);
        } else if (event.cards != null) {
          _commitGeneration(event.cards!, examplesForThisGen);
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

  void _commitGeneration(
    List<Flashcard> cards,
    List<Flashcard> examplesUsed,
  ) {
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
      savedExamplesUsed: List.unmodifiable(examplesUsed),
      at: DateTime.now(),
    );
    setState(() {
      _history.add(gen);
      _currentCards = cards;
      // Flip back to View when a fresh generation arrives — rating only
      // makes sense once you've seen the cards.
      _mode = FlashcardsMode.view;
    });
  }

  /// Persist a rating decision. Up-rated cards become future few-shot
  /// exemplars; dedup by normalized question so saving the same idea twice
  /// across regenerations doesn't crowd the prompt.
  void _rateCard(int generationIndex, int cardIndex, CardRating rating) {
    final gen = _history.firstWhere((g) => g.index == generationIndex);
    setState(() {
      gen.ratings[cardIndex] = rating;
      if (rating == CardRating.up) {
        final card = gen.cards[cardIndex];
        final norm = card.question.toLowerCase().trim();
        final exists = _savedGoodCards
            .any((c) => c.question.toLowerCase().trim() == norm);
        if (!exists) _savedGoodCards.add(card);
      } else if (rating == CardRating.down) {
        // If the user previously up-rated this question and now down-rates,
        // remove it from the saved set so the prompt stops echoing it.
        final card = gen.cards[cardIndex];
        final norm = card.question.toLowerCase().trim();
        _savedGoodCards
            .removeWhere((c) => c.question.toLowerCase().trim() == norm);
      }
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
    return Column(
      children: [
        Row(
          children: [
            // Chips reflow to a second line on narrow widths so the diff
            // button stays accessible. Without Wrap, gen+new+kept+diff
            // overflow by a hair on a Pixel 6a (~379 px wide).
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'gen #${latest.index}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (hasDiff && newCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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
                  if (_savedGoodCards.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bookmark,
                            size: 14,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_savedGoodCards.length} kept',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (hasDiff)
              TextButton.icon(
                onPressed: () => setState(() => _showDiff = !_showDiff),
                icon: Icon(_showDiff ? Icons.style : Icons.compare_arrows),
                label: Text(_showDiff ? 'cards' : 'diff'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<FlashcardsMode>(
          segments: const [
            ButtonSegment(
              value: FlashcardsMode.view,
              label: Text('View'),
              icon: Icon(Icons.style_outlined),
            ),
            ButtonSegment(
              value: FlashcardsMode.rate,
              label: Text('Rate'),
              icon: Icon(Icons.swipe),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            // Leaving diff view when entering Rate, since rate is a single-
            // card surface and diff is a list comparison.
            if (_mode == FlashcardsMode.rate) _showDiff = false;
          }),
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
    if (_mode == FlashcardsMode.rate && _history.isNotEmpty) {
      return _FlashcardRater(
        generation: _history.last,
        peerNoteIds: _history.last.peerNoteIds,
        notesById: _history.last.notesById,
        selfContributor: SeedLoader.instance.selfContributor,
        onRate: (cardIndex, rating) =>
            _rateCard(_history.last.index, cardIndex, rating),
        onRegenerate: _busy ? null : _ask,
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
      notesById: _history.isEmpty ? const {} : _history.last.notesById,
      selfContributor: SeedLoader.instance.selfContributor,
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
  final Map<String, StudyNote> notesById;
  final String selfContributor;
  const _FlashcardStack({
    required this.cards,
    required this.peerNoteIds,
    required this.notesById,
    required this.selfContributor,
  });

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
                  notesById: widget.notesById,
                  selfContributor: widget.selfContributor,
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
  final Map<String, StudyNote> notesById;
  final String selfContributor;
  const _FlashcardTile({
    super.key,
    required this.card,
    required this.index,
    required this.total,
    required this.drewFromPeers,
    required this.notesById,
    required this.selfContributor,
  });

  @override
  State<_FlashcardTile> createState() => _FlashcardTileState();
}

class _FlashcardTileState extends State<_FlashcardTile> {
  bool _showAnswer = false;
  bool _showSources = false;

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
                if (!isFront)
                  _SourceArea(
                    card: widget.card,
                    notesById: widget.notesById,
                    selfContributor: widget.selfContributor,
                    expanded: _showSources,
                    onToggle: () =>
                        setState(() => _showSources = !_showSources),
                    onBackground: theme.colorScheme.onSecondaryContainer,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Renders the source-note transparency block: a header with claimed-vs-
/// resolved-counts (so the audience can see when the model hallucinated a
/// source id), and an expandable list of the actual note bodies the model
/// claimed to draw from. Used by both view-mode tiles and rate-mode faces.
class _SourceArea extends StatelessWidget {
  final Flashcard card;
  final Map<String, StudyNote> notesById;
  final String selfContributor;
  final bool expanded;
  final VoidCallback onToggle;
  final Color onBackground;
  const _SourceArea({
    required this.card,
    required this.notesById,
    required this.selfContributor,
    required this.expanded,
    required this.onToggle,
    required this.onBackground,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final claimed = card.sourceNoteIds;
    final resolved = <StudyNote>[];
    for (final id in claimed) {
      final n = notesById[id];
      if (n != null) resolved.add(n);
    }
    final unmatched = claimed.length - resolved.length;
    // No claim at all and nothing to show — render nothing.
    if (claimed.isEmpty && resolved.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: claimed.isEmpty ? null : onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.menu_book_outlined,
                    size: 16,
                    color: onBackground.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _headerLabel(claimed.length, resolved.length, unmatched),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: onBackground.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  if (unmatched > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$unmatched not found',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (expanded && resolved.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...resolved.map((n) {
              final isMine = n.contributor == selfContributor;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: onBackground.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isMine
                                ? Icons.phone_iphone
                                : Icons.bluetooth_searching,
                            size: 14,
                            color: onBackground.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isMine ? 'you' : 'peer · ${n.contributor}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: onBackground.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        n.body,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: onBackground.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _headerLabel(int claimed, int resolved, int unmatched) {
    if (resolved == 0 && unmatched > 0) {
      return 'claimed $claimed source${claimed == 1 ? '' : 's'} '
          '— none matched retrieval';
    }
    if (expanded) {
      return 'sources ($resolved)';
    }
    return resolved == 1 ? 'show source' : 'show $resolved sources';
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

/// Edit-mode surface. One card at a time. Swipe right to keep (up-rate);
/// swipe left to reject (down-rate). The full Q + A is visible so the user
/// can judge the card on its merits — there's no flip affordance here; the
/// rating decision is the interaction.
///
/// As the user drags, the background tints green or red to telegraph the
/// rating. Past a threshold (~30% of card width) the card flies off in that
/// direction and the next card slides in. Once every card has been rated,
/// a summary appears with a regenerate button.
class _FlashcardRater extends StatefulWidget {
  final _Generation generation;
  final Set<String> peerNoteIds;
  final Map<String, StudyNote> notesById;
  final String selfContributor;
  final void Function(int cardIndex, CardRating rating) onRate;
  final VoidCallback? onRegenerate;
  const _FlashcardRater({
    required this.generation,
    required this.peerNoteIds,
    required this.notesById,
    required this.selfContributor,
    required this.onRate,
    required this.onRegenerate,
  });

  @override
  State<_FlashcardRater> createState() => _FlashcardRaterState();
}

class _FlashcardRaterState extends State<_FlashcardRater> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gen = widget.generation;
    final nextIndex = gen.ratings.indexWhere((r) => r == CardRating.unrated);

    if (nextIndex < 0) {
      return _RateSummary(
        upCount: gen.upCount,
        downCount: gen.downCount,
        onRegenerate: widget.onRegenerate,
      );
    }

    final card = gen.cards[nextIndex];
    final drewFromPeers = card.sourceNoteIds.any(widget.peerNoteIds.contains);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RateProgress(
          rated: gen.upCount + gen.downCount,
          total: gen.cards.length,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Dismissible(
            key: ValueKey('rate-${gen.index}-$nextIndex-${card.question}'),
            direction: DismissDirection.horizontal,
            background: _RateSwipeBackground(
              icon: Icons.bookmark_added,
              label: 'KEEP',
              color: Colors.green,
              alignLeft: true,
            ),
            secondaryBackground: _RateSwipeBackground(
              icon: Icons.thumb_down_alt,
              label: 'SKIP',
              color: Colors.red.shade400,
              alignLeft: false,
            ),
            onDismissed: (direction) {
              final rating = direction == DismissDirection.startToEnd
                  ? CardRating.up
                  : CardRating.down;
              widget.onRate(nextIndex, rating);
            },
            child: _RateCardFace(
              card: card,
              index: nextIndex,
              total: gen.cards.length,
              drewFromPeers: drewFromPeers,
              notesById: widget.notesById,
              selfContributor: widget.selfContributor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _RateHintChip(
              icon: Icons.swipe_left,
              label: 'swipe left → skip',
              color: Colors.red.shade400,
            ),
            _RateHintChip(
              icon: Icons.swipe_right,
              label: 'swipe right → keep',
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'kept cards become few-shot examples next time — the model learns '
          'your style without leaving the device.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _RateProgress extends StatelessWidget {
  final int rated;
  final int total;
  const _RateProgress({required this.rated, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : rated / total,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$rated / $total rated',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _RateSwipeBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool alignLeft;
  const _RateSwipeBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RateCardFace extends StatefulWidget {
  final Flashcard card;
  final int index;
  final int total;
  final bool drewFromPeers;
  final Map<String, StudyNote> notesById;
  final String selfContributor;
  const _RateCardFace({
    required this.card,
    required this.index,
    required this.total,
    required this.drewFromPeers,
    required this.notesById,
    required this.selfContributor,
  });

  @override
  State<_RateCardFace> createState() => _RateCardFaceState();
}

class _RateCardFaceState extends State<_RateCardFace> {
  bool _showSources = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OrientationBuilder(
      builder: (context, orientation) {
        final landscape = orientation == Orientation.landscape;
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
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
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (widget.drewFromPeers) const _PeerBadge(),
                ],
              ),
              SizedBox(height: landscape ? 24 : 16),
              Text(
                widget.card.question,
                style: TextStyle(
                  fontSize: landscape ? 28 : 22,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: theme.dividerColor),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.card.answer,
                        style: TextStyle(
                          fontSize: landscape ? 20 : 17,
                          height: 1.45,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.85),
                        ),
                      ),
                      _SourceArea(
                        card: widget.card,
                        notesById: widget.notesById,
                        selfContributor: widget.selfContributor,
                        expanded: _showSources,
                        onToggle: () =>
                            setState(() => _showSources = !_showSources),
                        onBackground: theme.colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RateHintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _RateHintChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RateSummary extends StatelessWidget {
  final int upCount;
  final int downCount;
  final VoidCallback? onRegenerate;
  const _RateSummary({
    required this.upCount,
    required this.downCount,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              'all cards rated',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$upCount kept, $downCount skipped',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              upCount > 0
                  ? 'next regenerate will fold your $upCount kept card'
                      '${upCount == 1 ? '' : 's'} into the prompt as '
                      'few-shot examples — the model will mirror their style.'
                  : 'no cards kept this round. regenerate to try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('regenerate'),
            ),
          ],
        ),
      ),
    );
  }
}
