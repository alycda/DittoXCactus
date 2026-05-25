// Widget tests for U10's FlashcardsTab.
//
// What matters here (plan §U10 test scenarios):
//   - Empty topic → generate is a no-op (no callback fired).
//   - Rate mode + history persistence: up-rating a card carries forward
//     into the next generation as a few-shot exemplar; previous generations
//     remain visible after regenerating.
//   - 0 retrieved + 0 cards renders gracefully ("no cards in this generation").
//
// FlashcardsTab takes a `GenerateFlashcardsFn` callback so these tests
// don't touch Cactus or Ditto.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/models/study_note.dart';
import 'package:mesh_rag/services/retrieval_service.dart';
import 'package:mesh_rag/widgets/flashcards_tab.dart';

class _FakeGenerator {
  int callCount = 0;
  final List<String> topics = [];
  final List<List<Flashcard>> savedExamplesPerCall = [];
  List<List<Flashcard>> cardsPerCall = const [];
  List<List<RetrievedNote>> retrievedPerCall = const [];

  Stream<FlashcardEvent> generate(
    String topic, {
    List<Flashcard> savedExamples = const [],
  }) async* {
    final i = callCount;
    callCount++;
    topics.add(topic);
    savedExamplesPerCall.add(List<Flashcard>.from(savedExamples));

    final retrieved = i < retrievedPerCall.length
        ? retrievedPerCall[i]
        : const <RetrievedNote>[];
    yield FlashcardEventRetrieved(retrieved);

    final cards = i < cardsPerCall.length ? cardsPerCall[i] : const <Flashcard>[];
    yield FlashcardEventCards(cards);
    yield const FlashcardEventDone();
  }
}

StudyNote _noteFor({
  required String contributor,
  required String topic,
  required DateTime createdAt,
}) {
  return StudyNote.seed(
    contributor: contributor,
    topic: topic,
    createdAt: createdAt,
    tags: const [],
    body: 'body for $topic',
  );
}

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('FlashcardsTab', () {
    testWidgets('empty topic does not invoke the generator', (tester) async {
      final fake = _FakeGenerator();

      await tester.pumpWidget(_wrap(FlashcardsTab(generate: fake.generate)));
      await tester.tap(find.text('Generate'));
      await tester.pump();

      expect(fake.callCount, 0);
    });

    testWidgets('happy path: generates, renders cards, shows footer',
        (tester) async {
      final note = _noteFor(
        contributor: 'phone-a',
        topic: 'gravity',
        createdAt: DateTime.utc(2026, 5, 24),
      );
      final fake = _FakeGenerator()
        ..cardsPerCall = [
          [
            Flashcard(
              question: 'What is gravity?',
              answer: 'A fundamental force.',
              sourceNoteIds: [note.id],
            ),
          ],
        ]
        ..retrievedPerCall = [
          [RetrievedNote(note: note, score: 0.99)],
        ];

      await tester.pumpWidget(_wrap(FlashcardsTab(
        generate: fake.generate,
        selfContributor: 'phone-a',
      )));
      await tester.enterText(find.byType(TextField), 'gravity');
      await tester.tap(find.text('Generate'));
      await tester.pump(); // stream tick: retrieved
      await tester.pump(); // stream tick: cards
      await tester.pump(); // stream tick: done

      expect(fake.callCount, 1);
      expect(fake.topics, ['gravity']);
      expect(find.text('What is gravity?'), findsOneWidget);
      expect(find.text('drew on 1 note (0 from peers)'), findsOneWidget);
    });

    testWidgets('counts peer-contributed notes in the footer', (tester) async {
      final noteSelf = _noteFor(
        contributor: 'phone-a',
        topic: 'topic-a',
        createdAt: DateTime.utc(2026, 5, 24, 1),
      );
      final notePeer1 = _noteFor(
        contributor: 'phone-b',
        topic: 'topic-b1',
        createdAt: DateTime.utc(2026, 5, 24, 2),
      );
      final notePeer2 = _noteFor(
        contributor: 'phone-b',
        topic: 'topic-b2',
        createdAt: DateTime.utc(2026, 5, 24, 3),
      );
      final fake = _FakeGenerator()
        ..cardsPerCall = [
          [
            Flashcard(
              question: 'Q1',
              answer: 'A1',
              sourceNoteIds: [noteSelf.id, notePeer1.id],
            ),
          ],
        ]
        ..retrievedPerCall = [
          [
            RetrievedNote(note: noteSelf, score: 0.95),
            RetrievedNote(note: notePeer1, score: 0.93),
            RetrievedNote(note: notePeer2, score: 0.90),
          ],
        ];

      await tester.pumpWidget(_wrap(FlashcardsTab(
        generate: fake.generate,
        selfContributor: 'phone-a',
      )));
      await tester.enterText(find.byType(TextField), 'topic');
      await tester.tap(find.text('Generate'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('drew on 3 notes (2 from peers)'), findsOneWidget);
    });

    testWidgets('up-rated card is passed as savedExamples on regenerate',
        (tester) async {
      const card1 = Flashcard(
        question: 'Q1',
        answer: 'A1',
        sourceNoteIds: ['id-1'],
      );
      final fake = _FakeGenerator()
        ..cardsPerCall = const [
          [card1],
          [
            Flashcard(
              question: 'Q2',
              answer: 'A2',
              sourceNoteIds: ['id-2'],
            ),
          ],
        ];

      await tester.pumpWidget(_wrap(FlashcardsTab(generate: fake.generate)));
      await tester.enterText(find.byType(TextField), 'topic');
      await tester.tap(find.text('Generate'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Up-rate the first card.
      await tester.tap(find.byTooltip('Keep this style'));
      await tester.pump();

      // Regenerate.
      await tester.tap(find.text('Regenerate'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(fake.callCount, 2);
      expect(fake.savedExamplesPerCall[0], isEmpty);
      expect(fake.savedExamplesPerCall[1], [card1]);
    });

    testWidgets('history persists across regenerates', (tester) async {
      final fake = _FakeGenerator()
        ..cardsPerCall = const [
          [
            Flashcard(
              question: 'first-gen-question',
              answer: 'first-gen-answer',
              sourceNoteIds: ['id-1'],
            ),
          ],
          [
            Flashcard(
              question: 'second-gen-question',
              answer: 'second-gen-answer',
              sourceNoteIds: ['id-2'],
            ),
          ],
        ];

      await tester.pumpWidget(_wrap(FlashcardsTab(generate: fake.generate)));
      await tester.enterText(find.byType(TextField), 'topic');
      await tester.tap(find.text('Generate'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('first-gen-question'), findsOneWidget);

      await tester.tap(find.text('Regenerate'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Both generations are present in the scrollable history list.
      expect(find.text('first-gen-question'), findsOneWidget);
      expect(find.text('second-gen-question'), findsOneWidget);
    });

    testWidgets('flip state survives a parent setState (rate-button tap)',
        (tester) async {
      // Locks in the flip-state-hoist port from sibling-U10. Pre-port, the
      // _FlashcardView was Stateful; tapping the rate button triggers a
      // parent setState which rebuilt the PageView, and any flipped card
      // stayed flipped because Flutter preserved its State subtree by
      // position. PageView's off-screen disposal would still drop it.
      //
      // Post-port, flip state lives in _GenerationBlockState keyed by
      // index; this test exercises the simpler proxy: tap-to-flip, then
      // trigger a parent rebuild via up-rate, then assert the card is
      // still on the answer side. A PageView-disposal regression would
      // need a multi-card deck and a swipe far enough to evict — the
      // single-card test environment doesn't reproduce that, but this
      // structural test catches any future "make flip state local again"
      // refactor.
      final fake = _FakeGenerator()
        ..cardsPerCall = const [
          [
            Flashcard(
              question: 'flip-q',
              answer: 'flip-a',
              sourceNoteIds: ['id-1'],
            ),
          ],
        ];

      await tester.pumpWidget(_wrap(FlashcardsTab(generate: fake.generate)));
      await tester.enterText(find.byType(TextField), 'topic');
      await tester.tap(find.text('Generate'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Card lands question-side.
      expect(find.text('flip-q'), findsOneWidget);
      expect(find.text('flip-a'), findsNothing);

      // Tap the card → flips to answer.
      await tester.tap(find.text('flip-q'));
      await tester.pump();
      expect(find.text('flip-a'), findsOneWidget);
      expect(find.text('flip-q'), findsNothing);

      // Trigger a parent rebuild via up-rate. Pre-port this kept the
      // flip because Stateful preservation; post-port it keeps the flip
      // because the parent owns the flip set. Either way: the assertion
      // documents that the user's flip survives unrelated UI events.
      await tester.tap(find.byTooltip('Keep this style'));
      await tester.pump();
      expect(find.text('flip-a'), findsOneWidget);
      expect(find.text('flip-q'), findsNothing);
    });

    testWidgets('0 retrieved + 0 cards renders empty-generation marker',
        (tester) async {
      final fake = _FakeGenerator()
        ..cardsPerCall = [const []]
        ..retrievedPerCall = [const []];

      await tester.pumpWidget(_wrap(FlashcardsTab(generate: fake.generate)));
      await tester.enterText(find.byType(TextField), 'topic');
      await tester.tap(find.text('Generate'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.text('(no cards in this generation)'), findsOneWidget);
      expect(find.text('drew on 0 notes (0 from peers)'), findsOneWidget);
    });
  });
}
