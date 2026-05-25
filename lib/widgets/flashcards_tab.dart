/// Topic input → streaming flashcard generation → swipeable card stack.
///
/// Plan §U10:
///   - Topic field + Generate/Regenerate button.
///   - Consumes a `Stream<FlashcardEvent>` from `RetrievalService.generateFlashcards`.
///   - Each generation lands as a swipeable card row (horizontal PageView)
///     with flip-on-tap (Q ↔ A) and per-card SOURCE chips at the foot.
///   - Aggregate footer per generation: `'drew on N notes (M from peers)'`
///     — the R1 visible-improvement signal that the audience reads.
///   - Rate mode (up/down) feeds back as few-shot exemplars to the next
///     generation; rate state persists across regenerates.
///   - Generation history persists so the audience can see how the cards
///     change when a peer joins (latest generation at top, older below).
///
/// Pattern reference: edge-veda's chip-row source-attribution pattern
/// (`_inspiration/repos/ramanujammv1988__edge-veda/`).
library mesh_rag.widgets.flashcards_tab;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/retrieval_service.dart';

/// Function signature mirrors `RetrievalService.generateFlashcards` so tests
/// can pass in a fake without touching Cactus.
typedef GenerateFlashcardsFn = Stream<FlashcardEvent> Function(
  String topic, {
  List<Flashcard> savedExamples,
});

/// Cap how many up-rated exemplars get fed back into the next generation.
/// U11's prompt budget is tight; mirrors the "up to 3 few-shot exemplars"
/// language in the plan's prompt-assembly approach.
const int _kMaxFewShot = 3;

class FlashcardsTab extends StatefulWidget {
  const FlashcardsTab({
    super.key,
    required this.generate,
    this.selfContributor,
  });

  final GenerateFlashcardsFn generate;

  /// `phone-a` or `phone-b`. When set, used to count "from peers" in the
  /// per-generation footer. Left nullable so tests don't need to know.
  final String? selfContributor;

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  final TextEditingController _topicController = TextEditingController();
  final List<_Generation> _history = [];
  final List<Flashcard> _upRated = [];

  StreamSubscription<FlashcardEvent>? _activeSub;
  bool _isGenerating = false;
  String _partialBuffer = '';
  String? _error;
  List<RetrievedNote> _stagedRetrieved = const [];
  String _stagedTopic = '';

  @override
  void dispose() {
    _activeSub?.cancel();
    _topicController.dispose();
    super.dispose();
  }

  /// Latest up-rated cards, newest first, capped at [_kMaxFewShot].
  List<Flashcard> get _fewShotExemplars {
    if (_upRated.length <= _kMaxFewShot) {
      return List<Flashcard>.from(_upRated.reversed);
    }
    return _upRated.reversed.take(_kMaxFewShot).toList();
  }

  void _onGeneratePressed() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return; // Edge case: empty topic — no-op.
    _activeSub?.cancel();
    setState(() {
      _isGenerating = true;
      _partialBuffer = '';
      _error = null;
      _stagedRetrieved = const [];
      _stagedTopic = topic;
    });
    _activeSub = widget
        .generate(topic, savedExamples: _fewShotExemplars)
        .listen(_onEvent, onError: _onStreamError, onDone: _onStreamDone);
  }

  void _onEvent(FlashcardEvent event) {
    if (!mounted) return;
    switch (event) {
      case FlashcardEventRetrieved(retrieved: final r):
        setState(() => _stagedRetrieved = r);
      case FlashcardEventPartial(chunk: final c):
        setState(() => _partialBuffer += c);
      case FlashcardEventCards(cards: final cards):
        setState(() {
          _history.insert(
            0,
            _Generation(
              topic: _stagedTopic,
              cards: cards,
              retrieved: _stagedRetrieved,
            ),
          );
        });
      case FlashcardEventDone():
        setState(() => _isGenerating = false);
    }
  }

  void _onStreamError(Object error) {
    if (!mounted) return;
    setState(() {
      _error = error.toString();
      _isGenerating = false;
    });
  }

  void _onStreamDone() {
    if (!mounted) return;
    setState(() => _isGenerating = false);
  }

  void _rateCard(Flashcard card, bool up) {
    setState(() {
      if (up) {
        if (!_upRated.contains(card)) _upRated.add(card);
      } else {
        _upRated.remove(card);
      }
    });
  }

  bool _isUpRated(Flashcard card) => _upRated.contains(card);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopicInputBar(
          controller: _topicController,
          isGenerating: _isGenerating,
          hasHistory: _history.isNotEmpty,
          onSubmit: _onGeneratePressed,
        ),
        if (_isGenerating)
          _GeneratingIndicator(partial: _partialBuffer),
        if (_error != null)
          _ErrorBanner(error: _error!),
        Expanded(
          child: _history.isEmpty
              ? const _EmptyHistory()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _history.length,
                  itemBuilder: (context, i) {
                    final gen = _history[i];
                    return _GenerationBlock(
                      key: ValueKey('gen-$i-${gen.topic}'),
                      generation: gen,
                      isLatest: i == 0,
                      selfContributor: widget.selfContributor,
                      onRate: _rateCard,
                      isUpRated: _isUpRated,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Generation {
  final String topic;
  final List<Flashcard> cards;
  final List<RetrievedNote> retrieved;
  const _Generation({
    required this.topic,
    required this.cards,
    required this.retrieved,
  });
}

class _TopicInputBar extends StatelessWidget {
  const _TopicInputBar({
    required this.controller,
    required this.isGenerating,
    required this.hasHistory,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isGenerating;
  final bool hasHistory;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = hasHistory ? 'Regenerate' : 'Generate';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Topic',
                hintText: 'e.g. habitable exoplanets',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: isGenerating ? null : (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: isGenerating ? null : onSubmit,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

/// Streaming-progress row with a tap-to-expand "show thinking" panel.
///
/// **Why expand:** Qwen 2.5 leaks `<think>...</think>` before the visible
/// cards (the parser strips it from the final card stack, but the audience
/// can watch it form in real time when the panel is expanded — which is
/// on-narrative: "the model thinks on the device"). Collapsed by default
/// because the demo's main beat is the card stack, not the chain-of-thought.
///
/// Also: each chunk is `debugPrint`-ed from `RetrievalService.generateFlashcards`
/// so `flutter logs` / logcat / DevTools captures the raw stream even when
/// the panel is collapsed.
class _GeneratingIndicator extends StatefulWidget {
  const _GeneratingIndicator({required this.partial});
  final String partial;

  @override
  State<_GeneratingIndicator> createState() => _GeneratingIndicatorState();
}

class _GeneratingIndicatorState extends State<_GeneratingIndicator> {
  bool _expanded = false;

  // Approximate max-height for the expanded panel — fits ~10 lines of
  // monospace 12pt, which is enough for one <think> block on a phone
  // screen without crowding out the card stack below.
  static const double _expandedMaxHeight = 180;

  @override
  Widget build(BuildContext context) {
    final partial = widget.partial;
    final preview = partial.length > 120
        ? '…${partial.substring(partial.length - 120)}'
        : partial;
    final collapsedLabel =
        partial.isEmpty ? 'generating…' : 'generating… $preview';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      collapsedLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontFamily: 'monospace',
                      ),
                      maxLines: _expanded ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.black54,
                    semanticLabel: _expanded ? 'hide thinking' : 'show thinking',
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            _ExpandedThinkingPanel(
              partial: partial,
              maxHeight: _expandedMaxHeight,
            ),
        ],
      ),
    );
  }
}

class _ExpandedThinkingPanel extends StatefulWidget {
  const _ExpandedThinkingPanel({
    required this.partial,
    required this.maxHeight,
  });

  final String partial;
  final double maxHeight;

  @override
  State<_ExpandedThinkingPanel> createState() =>
      _ExpandedThinkingPanelState();
}

class _ExpandedThinkingPanelState extends State<_ExpandedThinkingPanel> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ExpandedThinkingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to the tail on each new chunk so the audience tracks
    // the streaming frontier instead of staring at the top of <think>.
    if (widget.partial != oldWidget.partial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          child: SelectableText(
            widget.partial.isEmpty ? '(waiting for first token…)' : widget.partial,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFC62828)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFC62828),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Type a topic above and hit Generate.\nFlashcards stream from your local model.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ),
    );
  }
}

class _GenerationBlock extends StatefulWidget {
  const _GenerationBlock({
    super.key,
    required this.generation,
    required this.isLatest,
    required this.selfContributor,
    required this.onRate,
    required this.isUpRated,
  });

  final _Generation generation;
  final bool isLatest;
  final String? selfContributor;
  final void Function(Flashcard card, bool up) onRate;
  final bool Function(Flashcard card) isUpRated;

  @override
  State<_GenerationBlock> createState() => _GenerationBlockState();
}

class _GenerationBlockState extends State<_GenerationBlock> {
  // Flip state is hoisted here (keyed by card index) so that swiping
  // far away from card N and back doesn't lose the flip. PageView.builder
  // disposes off-screen page state by default, which would otherwise drop
  // the user back on the question side when they return.
  //
  // Ported from sibling-U10 (e39e3e30). My _Generation values are immutable
  // once inserted into _history, so didUpdateWidget on the same key won't
  // see a deck swap in practice — but the reset guard is cheap defense in
  // case a future change reuses the same key across decks.
  final Set<int> _flippedIndices = <int>{};

  // Hold the PageController across rebuilds so user-initiated up-rates
  // (which trigger a rebuild via _FlashcardsTabState.setState) don't reset
  // the scroll position. The previous Stateless implementation created a
  // fresh `PageController(viewportFraction: 0.9)` on every build, which
  // jumped the audience back to card 0 every time they tapped 👍.
  late final PageController _pageController =
      PageController(viewportFraction: 0.9);

  @override
  void didUpdateWidget(_GenerationBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.generation.cards, oldWidget.generation.cards)) {
      setState(_flippedIndices.clear);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _peerCount {
    final self = widget.selfContributor;
    if (self == null) return 0;
    return widget.generation.retrieved
        .where((r) => r.note.contributor != self)
        .length;
  }

  void _toggleFlip(int i) {
    setState(() {
      if (!_flippedIndices.remove(i)) _flippedIndices.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final generation = widget.generation;
    final retrievedCount = generation.retrieved.length;
    final peerCount = _peerCount;
    final footer = 'drew on $retrievedCount '
        '${retrievedCount == 1 ? 'note' : 'notes'} '
        '($peerCount from ${peerCount == 1 ? 'peer' : 'peers'})';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: widget.isLatest ? null : const Color(0xFFFAFAFA),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  if (widget.isLatest)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.bolt, size: 14, color: Colors.amber),
                    ),
                  Expanded(
                    child: Text(
                      'topic: ${generation.topic}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                footer,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
            if (generation.cards.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '(no cards in this generation)',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              )
            else
              SizedBox(
                height: 220,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: generation.cards.length,
                  itemBuilder: (context, i) {
                    final card = generation.cards[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _FlashcardView(
                        card: card,
                        index: i + 1,
                        total: generation.cards.length,
                        flipped: _flippedIndices.contains(i),
                        onFlip: () => _toggleFlip(i),
                        isUpRated: widget.isUpRated(card),
                        onRate: (up) => widget.onRate(card, up),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Stateless — flip state lives in [_GenerationBlockState._flippedIndices]
/// so it survives `PageView` lazy-disposal on swipe-back.
class _FlashcardView extends StatelessWidget {
  const _FlashcardView({
    required this.card,
    required this.index,
    required this.total,
    required this.flipped,
    required this.onFlip,
    required this.isUpRated,
    required this.onRate,
  });

  final Flashcard card;
  final int index;
  final int total;
  final bool flipped;
  final VoidCallback onFlip;
  final bool isUpRated;
  final void Function(bool up) onRate;

  @override
  Widget build(BuildContext context) {
    final face = flipped ? card.answer : card.question;
    final faceLabel = flipped ? 'A' : 'Q';
    return GestureDetector(
      onTap: onFlip,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$faceLabel:',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const Spacer(),
                Text(
                  '$index/$total',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  face,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            if (card.sourceNoteIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final id in card.sourceNoteIds)
                    _SourceChip(id: id),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  onPressed: () => onRate(true),
                  icon: Icon(
                    isUpRated ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: isUpRated
                        ? const Color(0xFF2E7D32)
                        : Colors.black54,
                  ),
                  tooltip: 'Keep this style',
                ),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  onPressed: () => onRate(false),
                  icon: const Icon(
                    Icons.thumb_down_outlined,
                    color: Colors.black54,
                  ),
                  tooltip: 'Drop this style',
                ),
                const Spacer(),
                Text(
                  flipped ? 'tap to flip → Q' : 'tap to flip → A',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.id});
  final String id;

  /// Render only the last 8 chars of the UUID to stay camera-legible.
  String get _shortId {
    if (id.length <= 10) return id;
    return '…${id.substring(id.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Text(
        _shortId,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: Color(0xFF0D47A1),
        ),
      ),
    );
  }
}
