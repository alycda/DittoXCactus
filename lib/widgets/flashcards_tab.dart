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

class _GeneratingIndicator extends StatelessWidget {
  const _GeneratingIndicator({required this.partial});
  final String partial;

  @override
  Widget build(BuildContext context) {
    final preview = partial.length > 120
        ? '…${partial.substring(partial.length - 120)}'
        : partial;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              partial.isEmpty ? 'generating…' : 'generating… $preview',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

class _GenerationBlock extends StatelessWidget {
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

  int get _peerCount {
    if (selfContributor == null) return 0;
    return generation.retrieved
        .where((r) => r.note.contributor != selfContributor)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final retrievedCount = generation.retrieved.length;
    final peerCount = _peerCount;
    final footer = 'drew on $retrievedCount '
        '${retrievedCount == 1 ? 'note' : 'notes'} '
        '($peerCount from ${peerCount == 1 ? 'peer' : 'peers'})';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: isLatest ? null : const Color(0xFFFAFAFA),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  if (isLatest)
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
                  controller: PageController(viewportFraction: 0.9),
                  itemCount: generation.cards.length,
                  itemBuilder: (context, i) {
                    final card = generation.cards[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _FlashcardView(
                        card: card,
                        index: i + 1,
                        total: generation.cards.length,
                        isUpRated: isUpRated(card),
                        onRate: (up) => onRate(card, up),
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

class _FlashcardView extends StatefulWidget {
  const _FlashcardView({
    required this.card,
    required this.index,
    required this.total,
    required this.isUpRated,
    required this.onRate,
  });

  final Flashcard card;
  final int index;
  final int total;
  final bool isUpRated;
  final void Function(bool up) onRate;

  @override
  State<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<_FlashcardView> {
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final face = _showAnswer ? widget.card.answer : widget.card.question;
    final faceLabel = _showAnswer ? 'A' : 'Q';
    return GestureDetector(
      onTap: () => setState(() => _showAnswer = !_showAnswer),
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
                  '${widget.index}/${widget.total}',
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
            if (widget.card.sourceNoteIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final id in widget.card.sourceNoteIds)
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
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  onPressed: () => widget.onRate(true),
                  icon: Icon(
                    widget.isUpRated
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    color: widget.isUpRated
                        ? const Color(0xFF2E7D32)
                        : Colors.black54,
                  ),
                  tooltip: 'Keep this style',
                ),
                IconButton(
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  onPressed: () => widget.onRate(false),
                  icon: const Icon(
                    Icons.thumb_down_outlined,
                    color: Colors.black54,
                  ),
                  tooltip: 'Drop this style',
                ),
                const Spacer(),
                Text(
                  _showAnswer ? 'tap to flip → Q' : 'tap to flip → A',
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
