import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_rag_demo/models/study_note.dart';
import 'package:mesh_rag_demo/prompts/flashcard_gen.dart';
import 'package:mesh_rag_demo/services/retrieval_service.dart';

void main() {
  group('FlashcardGenPrompt.build', () {
    StudyNote note(String contributor, String body, {String topic = 'the solar system'}) =>
        StudyNote.seed(
          topic: topic,
          contributor: contributor,
          body: body,
          tags: const ['sun'],
          createdAt: DateTime.parse('2026-05-21T00:00:00Z'),
        );

    test('builds a system + user pair with N and topic surfaced', () {
      final msgs = FlashcardGenPrompt.build(
        topic: 'the solar system',
        n: 5,
        retrieved: [
          RetrievedNote(note('phone-a', 'the sun is a yellow dwarf star'), 0.91),
          RetrievedNote(note('phone-b', 'neptune has the fastest winds'), 0.87),
        ],
      );
      expect(msgs.length, equals(2));
      expect(msgs[0].role, equals('system'));
      expect(msgs[1].role, equals('user'));
      expect(msgs[1].content, contains('Topic: the solar system'));
      expect(msgs[1].content, contains('N: 5'));
      // Each contributor's note must appear so the LLM can attribute.
      expect(msgs[1].content, contains('phone-a'));
      expect(msgs[1].content, contains('phone-b'));
      expect(msgs[1].content, contains('yellow dwarf star'));
      expect(msgs[1].content, contains('fastest winds'));
    });

    test('empty retrieval instructs an empty JSON array', () {
      final msgs = FlashcardGenPrompt.build(
        topic: 'unknown',
        n: 3,
        retrieved: const [],
      );
      expect(msgs[1].content, contains('[]'));
    });

    test('system prompt forbids markdown fences and commentary', () {
      final msgs = FlashcardGenPrompt.build(
        topic: 'x',
        n: 1,
        retrieved: const [],
      );
      expect(msgs[0].content, contains('ONLY a JSON array'));
      expect(msgs[0].content, contains('no markdown'));
    });
  });

  group('FlashcardGenPrompt.parse', () {
    test('parses a clean JSON array', () {
      const raw = '[{"question":"What is the sun?",'
          '"answer":"A yellow dwarf star.",'
          '"sourceNoteIds":["n1","n2"]}]';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].question, equals('What is the sun?'));
      expect(cards[0].answer, equals('A yellow dwarf star.'));
      expect(cards[0].sourceNoteIds, equals(['n1', 'n2']));
    });

    test('tolerates leading prose before the array', () {
      const raw = 'Sure! Here are the flashcards:\n\n'
          '[{"question":"q","answer":"a","sourceNoteIds":["n1"]}]';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].question, equals('q'));
    });

    test('tolerates ```json fences', () {
      const raw = '```json\n'
          '[{"question":"q","answer":"a","sourceNoteIds":["n1"]}]\n'
          '```';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
    });

    test('salvages truncated output: keeps fully-formed cards', () {
      // Looks like the model started a third card but ran out of tokens.
      const raw = '[{"question":"q1","answer":"a1","sourceNoteIds":["n1"]},'
          '{"question":"q2","answer":"a2","sourceNoteIds":["n2"]},'
          '{"question":"q3","ans';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(2));
      expect(cards[1].question, equals('q2'));
    });

    test('drops entries missing required fields', () {
      const raw = '[{"question":"q","answer":""},'
          '{"question":"good","answer":"yes","sourceNoteIds":["n1"]}]';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].question, equals('good'));
    });

    test('returns empty list when there is no JSON array', () {
      expect(FlashcardGenPrompt.parse('I cannot do that.'), isEmpty);
      expect(FlashcardGenPrompt.parse(''), isEmpty);
    });

    test('handles missing sourceNoteIds as empty list', () {
      const raw = '[{"question":"q","answer":"a"}]';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].sourceNoteIds, isEmpty);
    });
  });
}
