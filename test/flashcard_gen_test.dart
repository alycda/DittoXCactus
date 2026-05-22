import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_rag_demo/models/study_note.dart';
import 'package:mesh_rag_demo/prompts/flashcard_gen.dart';
import 'package:mesh_rag_demo/services/retrieval_service.dart';

void main() {
  group('FlashcardGenPrompt.build', () {
    StudyNote note(
      String contributor,
      String body, {
      String topic = 'the solar system',
    }) =>
        StudyNote.seed(
          topic: topic,
          contributor: contributor,
          body: body,
          tags: const [],
          createdAt: DateTime.parse('2026-05-21T00:00:00Z'),
        );

    test('builds a system + user pair with N and topic surfaced', () {
      final msgs = FlashcardGenPrompt.build(
        topic: 'the solar system',
        n: 3,
        retrieved: [
          RetrievedNote(note('phone-a', 'the sun is a yellow dwarf star'), 0.91),
          RetrievedNote(note('phone-b', 'neptune has the fastest winds'), 0.87),
        ],
      );
      expect(msgs.length, equals(2));
      expect(msgs[0].role, equals('system'));
      expect(msgs[1].role, equals('user'));
      expect(msgs[1].content, contains('Topic: the solar system'));
      expect(msgs[1].content, contains('Number of flashcards (N): 3'));
      // Notes are present so the LLM can extract from them.
      expect(msgs[1].content, contains('yellow dwarf star'));
      expect(msgs[1].content, contains('fastest winds'));
    });

    test('system prompt forbids reasoning, markdown, and JSON', () {
      final msgs = FlashcardGenPrompt.build(
        topic: 'x',
        n: 1,
        retrieved: const [],
      );
      expect(msgs[0].content, contains('Q:'));
      expect(msgs[0].content, contains('A:'));
      expect(msgs[0].content, contains('SOURCE:'));
      expect(msgs[0].content, contains('Do NOT include any reasoning'));
      expect(msgs[0].content, contains('Do NOT use JSON'));
      expect(msgs[0].content, contains('no markdown'));
    });

    test('empty retrieval instructs output-nothing', () {
      final msgs = FlashcardGenPrompt.build(
        topic: 'unknown',
        n: 3,
        retrieved: const [],
      );
      expect(msgs[1].content, contains('output nothing'));
    });
  });

  group('FlashcardGenPrompt.parse — happy paths', () {
    test('parses two clean Q/A/NOTES blocks', () {
      const raw = '''
Q: What is the sun?
A: A yellow dwarf star, about 4.6 billion years old.
NOTES: n1, n2

Q: What are gas giants?
A: Jupiter and Saturn, the two largest planets.
NOTES: n3
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(2));
      expect(cards[0].question, equals('What is the sun?'));
      expect(cards[0].answer, contains('yellow dwarf'));
      expect(cards[0].sourceNoteIds, equals(['n1', 'n2']));
      expect(cards[1].question, equals('What are gas giants?'));
      expect(cards[1].sourceNoteIds, equals(['n3']));
    });

    test('multiline A: continuation across blank-less newlines', () {
      const raw = '''
Q: Tell me about Saturn
A: Saturn is a gas giant.
It has rings made mostly of water ice.
NOTES: n4
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].answer, contains('rings'));
      expect(cards[0].answer, contains('Saturn is a gas giant'));
    });

    test('handles missing NOTES line as empty list', () {
      const raw = 'Q: Q\nA: A\n';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].sourceNoteIds, isEmpty);
    });

    test('returns empty when there is no Q at all', () {
      expect(FlashcardGenPrompt.parse('I cannot do that.'), isEmpty);
      expect(FlashcardGenPrompt.parse(''), isEmpty);
    });
  });

  group('FlashcardGenPrompt.parse — tolerance', () {
    test('strips <think> reasoning blocks before parsing', () {
      const raw = '''
<think>
The user wants 2 flashcards. Let me think.
</think>

Q: q1
A: a1
NOTES: n1
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].question, equals('q1'));
    });

    test('strips unclosed <think> prefix when Q: appears after', () {
      const raw = '<think>some half-finished reasoning that never closed\n\n'
          'Q: q1\nA: a1\n';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
    });

    test('tolerates "Question:" / "Answer:" long forms', () {
      const raw = 'Question: What?\nAnswer: This.\nSource: n1\n';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].question, equals('What?'));
      expect(cards[0].answer, equals('This.'));
      expect(cards[0].sourceNoteIds, equals(['n1']));
    });

    test('tolerates numeric bullets and dashes before Q:/A:', () {
      const raw = '''
1. Q: First?
   A: yes
   NOTES: n1

2. Q: Second?
   A: also yes
   NOTES: n2
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(2));
      expect(cards[1].question, equals('Second?'));
    });

    test('drops trailing partial card when only Q: was emitted', () {
      const raw = '''
Q: q1
A: a1
NOTES: n1

Q: q2 was never answered
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].question, equals('q1'));
    });

    test('tolerates **Q:** / **A:** markdown-bold wrapped prefixes', () {
      const raw = '''
**Q:** What are the Galilean moons?
**A:** Io, Europa, Ganymede, Callisto.
**SOURCE:** n1

**Q:** Saturn's rings?
**A:** Mostly water ice and rock.
**SOURCE:** n2
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(2));
      expect(cards[0].question, equals('What are the Galilean moons?'));
      expect(cards[0].answer, contains('Io'));
      expect(cards[1].sourceNoteIds, equals(['n2']));
    });

    test('tolerates *italic* and __underline__ wrapped prefixes too', () {
      const raw = '*Q:* x\n*A:* y\n__SOURCE__: n1\n';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(1));
      expect(cards[0].sourceNoteIds, equals(['n1']));
    });

    test('regression: iPhone output with **Q:** and *Note:* answer-line', () {
      // Exact shape from the Pixel/iPhone run: markdown bold around Q,
      // and the model used "*Note:*" instead of "A:" on the third card.
      // Per the parser rules, the third card has no A: so it gets dropped —
      // we still want to recover the first two cards.
      const raw = '''
<think>
Let me think.
</think>

**Q:** What are the Galilean moons?
**A:** Io, Europa, Ganymede (Jupiter has 95 named moons).

**Q:** Describe Saturn's rings composition and discovery.
**A:** Mostly water ice and rock chunks, only tens of meters thick. Discovered by Galileo in 1610.

**Q:** How did Earth's Moon form?
*Note:* It formed about 4.5 billion years ago.
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(2),
          reason: 'first two are well-formed; third has no A: so it drops');
      expect(cards[0].question, contains('Galilean moons'));
      expect(cards[1].question, contains('Saturn'));
    });

    test('regression: full Qwen-style output with think + clean Q/A', () {
      const raw = '''
<think>
Okay, let me think about the notes.
I need to produce 3 flashcards.
</think>

Q: When was Pluto reclassified as a dwarf planet?
A: In 2006, because it had not cleared its orbital neighborhood.
NOTES: 14

Q: What is the heliopause?
A: The boundary where the solar wind slows to match the interstellar medium, ~120 AU from the sun.
NOTES: 12

Q: What are the ice giants?
A: Uranus and Neptune — they have more water, methane, and ammonia ices than Jupiter and Saturn.
NOTES: 11
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards, hasLength(3));
      expect(cards[0].question, contains('Pluto'));
      expect(cards[1].question, contains('heliopause'));
      expect(cards[2].sourceNoteIds, equals(['11']));
    });
  });
}
