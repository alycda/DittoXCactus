/// Topic input → streaming flashcards stack → rate + regenerate loop.
///
/// The flashcards tab is the **generative half** of the demo: phone A asks
/// "the solar system", retrieval pulls top-k notes from the merged corpus,
/// the LLM streams Q/A/SOURCE cards, the audience sees the per-card chips,
/// and after the BLE handshake brings B's notes in, "regenerate" makes the
/// chip footer flip from `0 from peers` to `M from peers` — R1's visible
/// improvement.
///
/// Rate mode (👍/👎) is a low-stakes interaction surface: up-rated cards
/// from the previous generation seed the next call's `savedExamples`,
/// nudging the model toward the user's preferred shape. History persists
/// every generation as a horizontally-scrollable strip below the active
/// stack, so the audience can scrub back and *see* the corpus expand.
///
/// Stage 0 ship: the U9 `generateFlashcards` stub only emits `Retrieved`
/// + `Done` (no cards yet — that's U11's body). The widget handles this
/// gracefully by showing "(no cards yet — U11 will fill these in)" so the
/// rest of the demo still demos.
library mesh_rag.widgets.flashcards_tab;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/retrieval_service.dart';

/// Function-shape for the generation entry point. The production wiring is
/// `RetrievalService.instance.generateFlashcards`; widget tests inject a
/// fake that emits a hand-built event sequence so the rate/history
/// behaviors are exercisable without Cactus or Ditto.
typedef GenerateFlashcardsFn = Stream<FlashcardEvent> Function(
  String topic, {
  List<Flashcard> savedExamples,
});

/// One past generation, kept in [_FlashcardsTabState._history] so the
/// audience can scrub through the corpus's evolution as peers join.
class _GenerationRun {
  final String topic;
  final List<RetrievedNote> retrieved;
  final List<Flashcard> cards;
  final int peerSourceCount;

  const _GenerationRun({
    required this.topic,
    required this.retrieved,
    required this.cards,
    required this.peerSourceCount,
  });
}

class FlashcardsTab extends StatefulWidget {
  const FlashcardsTab({
    super.key,
    required this.generateFlashcards,
    required this.selfContributor,
    this.initialTopic,
  });

  /// Injected generator. Defaults at the call-site (`QueryScreen`) bind to
  /// `RetrievalService.instance.generateFlashcards`.
  final GenerateFlashcardsFn generateFlashcards;

  /// Local device's contributor key. Used to compute "M from peers" in the
  /// retrieved footer — a source counts as a peer if its contributor differs
  /// from this.
  final String selfContributor;

  /// Pre-fill the topic input — U12's demo overlay passes this to make the
  /// dry-run reproducible.
  final String? initialTopic;

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  late final TextEditingController _topicController;
  StreamSubscription<FlashcardEvent>? _sub;

  // Live generation state (current run).
  bool _generating = false;
  String? _activeTopic;
  List<RetrievedNote> _retrieved = const [];
  List<Flashcard> _cards = const [];
  String _partialBuffer = '';
  Object? _error;

  // Rate-mode state — keyed by card index in the current run.
  final Set<int> _upRated = <int>{};
  final Set<int> _downRated = <int>{};

  // History strip — each completed run becomes one entry.
  final List<_GenerationRun> _history = <_GenerationRun>[];

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(text: widget.initialTopic ?? '');
  }

  @override
  void didUpdateWidget(FlashcardsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // U12's demo overlay swaps initialTopic mid-session to script scenarios;
    // the controller has to follow the prop or the input box silently stales.
    // Only sync when the parent explicitly passes a new initialTopic AND the
    // user hasn't started editing — pulling text out from under live typing
    // would be hostile.
    final next = widget.initialTopic;
    if (next != null &&
        next != oldWidget.initialTopic &&
        _topicController.text == (oldWidget.initialTopic ?? '')) {
      _topicController.text = next;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _topicController.dispose();
    super.dispose();
  }

  /// Up-rated cards from the most recent run are passed to the next
  /// generation as few-shot exemplars. Down-rated cards are dropped
  /// entirely (the model never sees them again).
  List<Flashcard> get _savedExamplesForNextRun {
    if (_cards.isEmpty) return const [];
    return [
      for (var i = 0; i < _cards.length; i++)
        if (_upRated.contains(i)) _cards[i],
    ];
  }

  int _countPeerSources(List<RetrievedNote> retrieved) {
    final self = widget.selfContributor;
    return retrieved.where((r) => r.note.contributor != self).length;
  }

  void _onGeneratePressed() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty || _generating) return;
    _runGeneration(topic);
  }

  void _runGeneration(String topic) {
    // Push the prior completed run into history before starting a new one.
    // Empty-cards runs (Stage-0 stub) still go in so the audience sees the
    // retrieval hit even when generation is a no-op — but errored runs are
    // dropped: a 0-cards/0-peers strip entry would be indistinguishable
    // from a legitimate empty-but-successful run, hiding the failure.
    if (_activeTopic != null && !_generating && _error == null) {
      _history.insert(
        0,
        _GenerationRun(
          topic: _activeTopic!,
          retrieved: _retrieved,
          cards: _cards,
          peerSourceCount: _countPeerSources(_retrieved),
        ),
      );
    }

    final savedExamples = _savedExamplesForNextRun;

    _sub?.cancel();
    setState(() {
      _generating = true;
      _activeTopic = topic;
      _retrieved = const [];
      _cards = const [];
      _partialBuffer = '';
      _upRated.clear();
      _downRated.clear();
      _error = null;
    });

    final stream =
        widget.generateFlashcards(topic, savedExamples: savedExamples);
    _sub = stream.listen(
      _onEvent,
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _error = e;
          _generating = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _generating = false);
      },
    );
  }

  void _onEvent(FlashcardEvent event) {
    if (!mounted) return;
    switch (event) {
      case FlashcardEventRetrieved(:final retrieved):
        setState(() => _retrieved = retrieved);
      case FlashcardEventPartial(:final chunk):
        setState(() => _partialBuffer = '$_partialBuffer$chunk');
      case FlashcardEventCards(:final cards):
        setState(() => _cards = cards);
      case FlashcardEventDone():
        setState(() => _generating = false);
    }
  }

  void _toggleUp(int idx) {
    setState(() {
      if (_upRated.remove(idx)) return;
      _upRated.add(idx);
      _downRated.remove(idx);
    });
  }

  void _toggleDown(int idx) {
    setState(() {
      if (_downRated.remove(idx)) return;
      _downRated.add(idx);
      _upRated.remove(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopicInputRow(
          controller: _topicController,
          generating: _generating,
          onSubmit: _onGeneratePressed,
        ),
        if (_activeTopic != null) ...[
          const Divider(height: 1),
          _RetrievedFooter(
            retrieved: _retrieved,
            peerSourceCount: _countPeerSources(_retrieved),
          ),
        ],
        Expanded(child: _buildBody()),
        if (_history.isNotEmpty) ...[
          const Divider(height: 1),
          _HistoryStrip(history: _history),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _ErrorView(error: _error!);
    }
    if (_activeTopic == null) {
      return const _EmptyView();
    }
    if (_cards.isNotEmpty) {
      return _SwipeableStack(
        cards: _cards,
        selfContributor: widget.selfContributor,
        upRated: _upRated,
        downRated: _downRated,
        onUp: _toggleUp,
        onDown: _toggleDown,
      );
    }
    if (_generating) {
      return _GeneratingView(partial: _partialBuffer);
    }
    // Generation finished but no cards (Stage 0 stub path, or LLM emitted
    // "(no notes available — output nothing.)").
    return const _NoCardsView();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopicInputRow extends StatelessWidget {
  const _TopicInputRow({
    required this.controller,
    required this.generating,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool generating;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !generating,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                hintText: 'topic (e.g. "the solar system")',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: generating ? null : onSubmit,
            icon: Icon(generating ? Icons.hourglass_top : Icons.bolt),
            label: Text(generating ? 'generating…' : 'generate'),
          ),
        ],
      ),
    );
  }
}

class _RetrievedFooter extends StatelessWidget {
  const _RetrievedFooter({
    required this.retrieved,
    required this.peerSourceCount,
  });

  final List<RetrievedNote> retrieved;
  final int peerSourceCount;

  @override
  Widget build(BuildContext context) {
    final n = retrieved.length;
    final label = n == 0
        ? 'no notes retrieved'
        : 'drew on $n note${n == 1 ? "" : "s"} '
            '($peerSourceCount from peer${peerSourceCount == 1 ? "" : "s"})';
    final bg = peerSourceCount > 0
        ? Colors.green.shade50
        : Colors.grey.shade100;
    final fg = peerSourceCount > 0
        ? Colors.green.shade900
        : Colors.black87;
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Enter a topic and tap "generate" to make flashcards.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ),
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView({required this.partial});
  final String partial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          const Text('generating…',
              style: TextStyle(fontSize: 14, color: Colors.black54)),
          if (partial.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  partial,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoCardsView extends StatelessWidget {
  const _NoCardsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '(no cards yet — U11 will land streaming flashcard generation.)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black45),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Generation failed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _SwipeableStack extends StatefulWidget {
  const _SwipeableStack({
    required this.cards,
    required this.selfContributor,
    required this.upRated,
    required this.downRated,
    required this.onUp,
    required this.onDown,
  });

  final List<Flashcard> cards;
  final String selfContributor;
  final Set<int> upRated;
  final Set<int> downRated;
  final void Function(int) onUp;
  final void Function(int) onDown;

  @override
  State<_SwipeableStack> createState() => _SwipeableStackState();
}

class _SwipeableStackState extends State<_SwipeableStack> {
  late final PageController _pageController;
  int _activeIndex = 0;

  // Flip state is hoisted here (keyed by card index in the current deck) so
  // that swiping far away from card N and back does not lose the flip —
  // PageView.builder disposes off-screen page state by default, which would
  // otherwise drop the user back on the question side when they return.
  final Set<int> _flippedCards = <int>{};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(_SwipeableStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset to first card when a fresh deck arrives.
    if (!identical(widget.cards, oldWidget.cards)) {
      setState(() {
        _activeIndex = 0;
        _flippedCards.clear();
      });
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

  void _toggleFlip(int idx) {
    setState(() {
      if (!_flippedCards.remove(idx)) _flippedCards.add(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.cards.length,
            onPageChanged: (i) => setState(() => _activeIndex = i),
            itemBuilder: (context, i) {
              return _FlashcardView(
                card: widget.cards[i],
                selfContributor: widget.selfContributor,
                flipped: _flippedCards.contains(i),
                onTap: () => _toggleFlip(i),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_activeIndex + 1} / ${widget.cards.length}',
                  style: const TextStyle(fontSize: 12)),
              Row(
                children: [
                  _RateButton(
                    icon: Icons.thumb_down_outlined,
                    selectedIcon: Icons.thumb_down,
                    selected: widget.downRated.contains(_activeIndex),
                    color: Colors.red.shade700,
                    onPressed: () => widget.onDown(_activeIndex),
                  ),
                  const SizedBox(width: 8),
                  _RateButton(
                    icon: Icons.thumb_up_outlined,
                    selectedIcon: Icons.thumb_up,
                    selected: widget.upRated.contains(_activeIndex),
                    color: Colors.green.shade700,
                    onPressed: () => widget.onUp(_activeIndex),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(selected ? selectedIcon : icon, color: selected ? color : null),
      iconSize: 22,
    );
  }
}

/// Stateless — the flip state lives in `_SwipeableStackState._flippedCards`
/// keyed by card index, so swiping far away from a flipped card and back
/// preserves the flip even when PageView.builder disposes the off-screen
/// page widgets.
class _FlashcardView extends StatelessWidget {
  const _FlashcardView({
    required this.card,
    required this.selfContributor,
    required this.flipped,
    required this.onTap,
  });

  final Flashcard card;
  final String selfContributor;
  final bool flipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  flipped ? 'A' : 'Q',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      flipped ? card.answer : card.question,
                      style: const TextStyle(fontSize: 18, height: 1.35),
                    ),
                  ),
                ),
                if (card.sourceNoteIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  _SourceChipRow(sourceNoteIds: card.sourceNoteIds),
                ],
                const SizedBox(height: 6),
                Text(
                  flipped ? 'tap to see question' : 'tap to flip',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
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

class _SourceChipRow extends StatelessWidget {
  const _SourceChipRow({required this.sourceNoteIds});
  final List<String> sourceNoteIds;

  // Show the last 6 chars of the UUIDv5 — enough to distinguish per-device
  // ids on stage without dragging the full UUID across the card foot.
  String _short(String id) =>
      id.length <= 6 ? id : '…${id.substring(id.length - 6)}';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final id in sourceNoteIds)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.indigo.shade200, width: 1),
            ),
            child: Text(
              _short(id),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Colors.indigo.shade900,
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({required this.history});
  final List<_GenerationRun> history;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: history.length,
        itemBuilder: (context, i) {
          final run = history[i];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.topic,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${run.cards.length} card${run.cards.length == 1 ? "" : "s"} '
                  '· ${run.peerSourceCount} from peers',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
