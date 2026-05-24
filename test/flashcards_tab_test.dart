// Widget tests for U10's FlashcardsTab.
//
// The widget consumes a `GenerateFlashcardsFn` callback — production wires
// `RetrievalService.instance.generateFlashcards`, tests inject a fake that
// emits a hand-built event sequence so we can exercise the rate-mode and
// history paths without Cactus or Ditto in the loop.
//
// Scenarios covered:
//   1. Happy path — Retrieved + Cards events render the swipeable stack
//      with per-card source chips + retrieved footer "drew on N (M from
//      peers)".
//   2. Empty-topic Generate is a no-op (generator never invoked).
//   3. Rate-up cards flow into the next call's savedExamples.
//   4. History strip persists prior generations across regenerates.
//   5. No-cards path (Stage 0 stub: only Retrieved + Done) shows the U11
//      placeholder text gracefully.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/models/study_note.dart';
import 'package:mesh_rag/services/retrieval_service.dart';
import 'package:mesh_rag/widgets/flashcards_tab.dart';

void main() {
  group('FlashcardsTab', () {
    /// Build a StudyNote stub for synthesizing RetrievedNote events. Real
    /// embedding values don't matter — the widget only reads `contributor`
    /// + `id` for the chip/footer rendering.
    StudyNote stubNote({
      required String contributor,
      required String id,
      String topic = 'the solar system',
    }) {
      return StudyNote(
        id: id,
        topic: topic,
        contributor: contributor,
        body: 'stub body for $id',
        tags: const [],
        embedding: const [],
        createdAt: DateTime.utc(2026, 1, 1),
      );
    }

    Future<void> pumpTab(
      WidgetTester tester, {
      required GenerateFlashcardsFn generator,
      String selfContributor = 'phone-a',
      String? initialTopic,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlashcardsTab(
              generateFlashcards: generator,
              selfContributor: selfContributor,
              initialTopic: initialTopic,
            ),
          ),
        ),
      );
    }

    testWidgets(
        'happy path: emits Retrieved + Cards → stack renders with chips + footer',
        (tester) async {
      final calls = <_Call>[];
      Stream<FlashcardEvent> gen(String topic,
          {List<Flashcard> savedExamples = const []}) async* {
        calls.add(_Call(topic: topic, savedExamples: savedExamples));
        yield FlashcardEventRetrieved([
          RetrievedNote(
              note: stubNote(contributor: 'phone-a', id: 'aaa-111'),
              score: 0.9),
          RetrievedNote(
              note: stubNote(contributor: 'phone-b', id: 'bbb-222'),
              score: 0.8),
        ]);
        yield FlashcardEventCards(const [
          Flashcard(
            question: 'What is the closest planet to the Sun?',
            answer: 'Mercury.',
            sourceNoteIds: ['aaa-111'],
          ),
          Flashcard(
            question: 'What gives Mars its red color?',
            answer: 'Iron oxide.',
            sourceNoteIds: ['bbb-222'],
          ),
        ]);
        yield const FlashcardEventDone();
      }

      await pumpTab(tester,
          generator: gen, initialTopic: 'the solar system');

      await tester.tap(find.text('generate'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.first.topic, 'the solar system');
      expect(calls.first.savedExamples, isEmpty);

      // Footer reflects 2 retrieved, 1 from peer (phone-b).
      expect(find.text('drew on 2 notes (1 from peer)'), findsOneWidget);

      // Active card is the first question (1/2 indicator visible).
      expect(find.text('What is the closest planet to the Sun?'),
          findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      // First card's source chip ends in '…aa-111' (last 6 of 'aaa-111').
      expect(find.text('…aa-111'), findsOneWidget);
    });

    testWidgets('empty topic: generate is a no-op', (tester) async {
      var callCount = 0;
      Stream<FlashcardEvent> gen(String topic,
          {List<Flashcard> savedExamples = const []}) async* {
        callCount++;
      }

      await pumpTab(tester, generator: gen);
      await tester.tap(find.text('generate'));
      await tester.pump();

      expect(callCount, 0);
    });

    testWidgets('rate-up cards feed into next generation savedExamples',
        (tester) async {
      final calls = <_Call>[];
      Stream<FlashcardEvent> gen(String topic,
          {List<Flashcard> savedExamples = const []}) async* {
        calls.add(_Call(topic: topic, savedExamples: savedExamples));
        yield FlashcardEventRetrieved([
          RetrievedNote(
              note: stubNote(contributor: 'phone-a', id: 'src-1'),
              score: 0.9),
        ]);
        yield FlashcardEventCards(const [
          Flashcard(
            question: 'Q1',
            answer: 'A1',
            sourceNoteIds: ['src-1'],
          ),
          Flashcard(
            question: 'Q2',
            answer: 'A2',
            sourceNoteIds: ['src-1'],
          ),
        ]);
        yield const FlashcardEventDone();
      }

      await pumpTab(tester, generator: gen, initialTopic: 'topic-1');

      // Run 1.
      await tester.tap(find.text('generate'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
      expect(calls[0].savedExamples, isEmpty);

      // Rate the first card up (it's the active one).
      await tester.tap(find.byIcon(Icons.thumb_up_outlined));
      await tester.pump();

      // Run 2 — re-generate.
      await tester.tap(find.text('generate'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(2));
      expect(calls[1].savedExamples, hasLength(1));
      expect(calls[1].savedExamples.first.question, 'Q1');
    });

    testWidgets('history strip persists prior generations across regenerates',
        (tester) async {
      var runIndex = 0;
      Stream<FlashcardEvent> gen(String topic,
          {List<Flashcard> savedExamples = const []}) async* {
        runIndex++;
        yield FlashcardEventRetrieved([
          RetrievedNote(
              note: stubNote(contributor: 'phone-a', id: 'r-$runIndex'),
              score: 0.9),
        ]);
        yield FlashcardEventCards([
          Flashcard(
            question: 'Q$runIndex',
            answer: 'A$runIndex',
            sourceNoteIds: ['r-$runIndex'],
          ),
        ]);
        yield const FlashcardEventDone();
      }

      await pumpTab(tester, generator: gen, initialTopic: 'topic-1');

      // Run 1.
      await tester.tap(find.text('generate'));
      await tester.pumpAndSettle();
      expect(find.text('Q1'), findsOneWidget);

      // Run 2 — the prior run lands in history with its topic + card count.
      await tester.tap(find.text('generate'));
      await tester.pumpAndSettle();

      // Active card is now Q2.
      expect(find.text('Q2'), findsOneWidget);

      // History strip carries the prior run's per-card summary. The topic
      // string itself appears twice (TextField + history label) so we assert
      // on the description text which only the strip renders.
      expect(find.text('1 card · 0 from peers'), findsOneWidget);
    });

    testWidgets(
        'Stage-0 stub path: Retrieved + Done only → no-cards placeholder',
        (tester) async {
      Stream<FlashcardEvent> gen(String topic,
          {List<Flashcard> savedExamples = const []}) async* {
        yield FlashcardEventRetrieved([
          RetrievedNote(
              note: stubNote(contributor: 'phone-a', id: 'only-1'),
              score: 0.9),
        ]);
        yield const FlashcardEventDone();
      }

      await pumpTab(tester, generator: gen, initialTopic: 'the solar system');
      await tester.tap(find.text('generate'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('(no cards yet'),
        findsOneWidget,
      );
      // Footer still reports the retrieval.
      expect(find.text('drew on 1 note (0 from peers)'), findsOneWidget);
    });
  });
}

class _Call {
  final String topic;
  final List<Flashcard> savedExamples;
  _Call({required this.topic, required this.savedExamples});
}
