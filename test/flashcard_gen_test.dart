// Parser tolerance + prompt-build tests for U11.
//
// The model under-instruction-following is the dominant failure mode at
// the 1.5B size class, so the parser has to absorb every plausible
// shape the model emits. Each test in the "parse" group locks in one
// specific deviation; if a future model swap regresses, this suite
// surfaces it as a named failure instead of "demo looks weird."
//
// The build tests pin the system preamble and the user-message closing
// imperative — those are load-bearing for grounding (no `(no notes
// available — output nothing.)` ⇒ fabrication risk).

import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/models/study_note.dart';
import 'package:mesh_rag/prompts/flashcard_gen.dart';
import 'package:mesh_rag/services/retrieval_service.dart';

RetrievedNote _retrieved({
  required String id,
  required String body,
  String topic = 'topic',
  String contributor = 'phone-a',
  double score = 0.9,
}) {
  // StudyNote.seed derives _id from (contributor|topic|createdAt); we want
  // the test note's id to match the supplied `id` argument, so seed first
  // and copyWith the id afterwards (the parser doesn't care about
  // contributor/createdAt, only the note id surfaced in the prompt).
  final seed = StudyNote.seed(
    contributor: contributor,
    topic: topic,
    createdAt: DateTime.utc(2026, 1, 1),
    tags: const [],
    body: body,
  );
  return RetrievedNote(note: seed.copyWith(id: id), score: score);
}

void main() {
  group('FlashcardGenPrompt.build', () {
    test('happy path: 3 retrieved notes → assembled prompt is well-formed',
        (() {
      final messages = FlashcardGenPrompt.build(
        topic: 'the Sun',
        n: 3,
        retrieved: [
          _retrieved(id: 'note-a', body: 'The Sun is a G-type star.'),
          _retrieved(id: 'note-b', body: 'Its core fuses hydrogen.'),
          _retrieved(id: 'note-c', body: 'It is ~4.6 billion years old.'),
        ],
      );

      expect(messages.length, 2);
      expect(messages[0].role, 'system');
      expect(messages[1].role, 'user');

      // System preamble pins (a sample of load-bearing lines).
      final sys = messages[0].content;
      expect(sys, contains('careful study buddy'));
      expect(sys, contains('Q: <a clear question>'));
      expect(sys, contains('A: <a short answer'));
      expect(sys, contains('SOURCE:'));
      expect(sys, contains('Do not make up facts'));

      final user = messages[1].content;
      expect(user, contains('Topic: the Sun'));
      expect(user, contains('Number of flashcards (N): 3'));
      // Notes are presented as [<id>] <body> so the id is unambiguous —
      // the model's natural reflex of writing "SOURCE: Note 1" (which
      // the shape filter would drop) shouldn't fire because there's no
      // "Note N" label to grab.
      expect(user, contains('[note-a] The Sun is a G-type star.'));
      expect(user, contains('[note-b] Its core fuses hydrogen.'));
      expect(user, contains('[note-c]'));
      expect(user, isNot(contains('Note 1 (id:')),
          reason: 'old label-leaking format must not regress');
      expect(
        user,
        endsWith(
          'Now output exactly 3 flashcards in the Q: / A: / SOURCE: format, '
          'each about "the Sun". Start with "Q:" on its own line. No reasoning, '
          'no preamble.',
        ),
        reason:
            'Closing imperative substitutes the literal count (and pluralizes) '
            'rather than using the abstract "N" — small models sometimes '
            'reason about the variable name itself.',
      );
    }));

    test('0 retrieved notes → closing line is the no-fabrication imperative',
        (() {
      final messages = FlashcardGenPrompt.build(
        topic: 'sailing',
        n: 3,
        retrieved: const [],
      );
      final user = messages[1].content;
      expect(user, contains('Topic: sailing'));
      expect(user, endsWith('(no notes available — output nothing.)'));
      // Critically, the "now output N flashcards" imperative must NOT be
      // present when we have no notes — that's what protects grounding.
      expect(user, isNot(contains('Now output N flashcards')));
    }));

    test('savedExamples render as numbered Q/A/SOURCE exemplars '
        '(capped at kMaxFewShotExemplars)', () {
      final messages = FlashcardGenPrompt.build(
        topic: 'gravity',
        n: 3,
        retrieved: [_retrieved(id: 'note-x', body: 'b')],
        savedExamples: List.generate(
          5,
          (i) => Flashcard(
            question: 'ex$i-q',
            answer: 'ex$i-a',
            sourceNoteIds: ['ex$i-s'],
          ),
        ),
      );
      final user = messages[1].content;
      expect(user, contains('mirror their style'));
      // First kMaxFewShotExemplars (3) are present; tail dropped.
      expect(user, contains('ex0-q'));
      expect(user, contains('ex1-q'));
      expect(user, contains('ex2-q'));
      expect(user, isNot(contains('ex3-q')));
      expect(user, isNot(contains('ex4-q')));
    });

    test('empty savedExamples → no "mirror their style" section', () {
      final messages = FlashcardGenPrompt.build(
        topic: 't',
        n: 3,
        retrieved: [_retrieved(id: 'n', body: 'b')],
      );
      expect(messages[1].content, isNot(contains('mirror their style')));
    });
  });

  group('FlashcardGenPrompt.parse', () {
    test('happy path: bare Q:/A:/SOURCE: blocks', () {
      const raw = '''
Q: What is the Sun?
A: A G-type main-sequence star.
SOURCE: note-001

Q: How old is the Sun?
A: About 4.6 billion years.
SOURCE: note-001, note-002
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 2);
      expect(cards[0].question, 'What is the Sun?');
      expect(cards[0].answer, 'A G-type main-sequence star.');
      expect(cards[0].sourceNoteIds, ['note-001']);
      expect(cards[1].question, 'How old is the Sun?');
      expect(cards[1].answer, 'About 4.6 billion years.');
      expect(cards[1].sourceNoteIds, ['note-001', 'note-002']);
    });

    test('markdown emphasis around labels (**Q:**, *A:*, _SOURCE:_)', () {
      const raw = '''
**Q:** What is light?
*A:* Electromagnetic radiation visible to the human eye.
_SOURCE:_ note-001
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      expect(cards[0].question, 'What is light?');
      expect(cards[0].answer,
          'Electromagnetic radiation visible to the human eye.');
      expect(cards[0].sourceNoteIds, ['note-001']);
    });

    test('numbered prefixes (1. Q:, 2) A:, etc.) are stripped', () {
      const raw = '''
1. Q: What is mass?
2. A: A measure of inertia.
3. SOURCE: note-001
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      expect(cards[0].question, 'What is mass?');
      expect(cards[0].answer, 'A measure of inertia.');
      expect(cards[0].sourceNoteIds, ['note-001']);
    });

    test('bullet prefixes (- Q:, * A:) are stripped', () {
      const raw = '''
- Q: What is heat?
- A: Energy of motion at the molecular level.
- SOURCE: note-001
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      expect(cards[0].question, 'What is heat?');
      expect(cards[0].answer, 'Energy of motion at the molecular level.');
    });

    test('long-form labels (Question:/Answer:/Notes:/From:) are tolerated',
        () {
      const raw = '''
Question: What is entropy?
Answer: A measure of disorder.
Notes: note-001, note-002
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      expect(cards[0].question, 'What is entropy?');
      expect(cards[0].answer, 'A measure of disorder.');
      expect(cards[0].sourceNoteIds, ['note-001', 'note-002']);
    });

    test('"From:" label also routes to SOURCE', () {
      const raw = '''
Q: What is mass?
A: A measure of inertia.
From: note-x
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.single.sourceNoteIds, ['note-x']);
    });

    test('closed <think>...</think> block before first Q: is stripped', () {
      const raw = '''
<think>
The user is asking about gravity. Let me think about what to say...
I should focus on the basics.
</think>

Q: What is gravity?
A: A force of attraction between masses.
SOURCE: note-grav
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      expect(cards[0].question, 'What is gravity?');
      expect(cards[0].answer, 'A force of attraction between masses.');
      expect(cards[0].sourceNoteIds, ['note-grav']);
    });

    test(
        'unclosed <think> prefix is ignored (anchored at first Q-line); '
        'everything before the first Q: is discarded', () {
      const raw = '''
<think>
Some chain-of-thought reasoning that never closes — Qwen 2.5 does this
when /no_think isn't available. The parser must still find Q: below.

Q: What is friction?
A: Resistance to relative motion between surfaces.
SOURCE: note-frc
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      expect(cards[0].question, 'What is friction?');
      expect(cards[0].answer,
          'Resistance to relative motion between surfaces.');
    });

    test('multi-line continuation under A: is joined into one answer', () {
      const raw = '''
Q: What is the speed of light in a vacuum?
A: Approximately 299,792,458 meters per second,
which is the universal speed limit in physics.
SOURCE: note-c
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      expect(
        cards[0].answer,
        'Approximately 299,792,458 meters per second, '
        'which is the universal speed limit in physics.',
      );
    });

    test('truncated mid-card: complete cards retained, incomplete tail dropped',
        () {
      const raw = '''
Q: Q1?
A: A1.
SOURCE: note-a

Q: Q2?
A: A2.
SOURCE: note-b

Q: Q3 — stream cut here
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 2);
      expect(cards[0].question, 'Q1?');
      expect(cards[1].question, 'Q2?');
    });

    test('truncated with Q + A but no SOURCE → card still complete '
        '(sourceNoteIds empty)', () {
      const raw = '''
Q: Q1?
A: A1.
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      expect(cards.single.sourceNoteIds, isEmpty);
    });

    test('Q: with empty content (just the label) skips the card', () {
      const raw = '''
Q:
A: dangling answer with no question
SOURCE: note-x

Q: Real Q?
A: Real A.
SOURCE: note-y
''';
      final cards = FlashcardGenPrompt.parse(raw);
      // First "card" has empty Q → drop. Second is the real one.
      expect(cards.length, 1);
      expect(cards.single.question, 'Real Q?');
    });

    test('SOURCE list tolerates bracket wrappers and semicolons', () {
      const raw1 = '''
Q: Q?
A: A.
SOURCE: [note-1, note-2]
''';
      expect(
        FlashcardGenPrompt.parse(raw1).single.sourceNoteIds,
        ['note-1', 'note-2'],
      );
      const raw2 = '''
Q: Q?
A: A.
SOURCE: note-1; note-2
''';
      expect(
        FlashcardGenPrompt.parse(raw2).single.sourceNoteIds,
        ['note-1', 'note-2'],
      );
    });

    test(
        'SOURCE entries that are not id-shaped (whitespace, parens, '
        'quotes, sentence fragments) are dropped — regression for the '
        'on-device chip wall', () {
      // Reproduces the on-device bug where the model emitted reasoning
      // text on the SOURCE line and the parser comma-split it into 30+
      // fake "ids". Real id tokens (alphanumeric + dash/underscore only)
      // survive; everything else is filtered out.
      const raw = '''
Q: How many moons does Earth have?
A: One.
SOURCE: my own Notes: nothing, ven here are claims (i.e. unreliable"), But wait — the setup, note-001, sources?, etc.
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      // Only the one well-shaped id survives the filter.
      expect(cards.single.sourceNoteIds, ['note-001']);
    });

    test('SOURCE entries with UUIDv5-shaped ids survive the filter', () {
      const raw = '''
Q: Q?
A: A.
SOURCE: 7c2b8e4a-3d5f-4b2c-8e6d-1a4f9e8c7b30, fcd1eaff-1234-5678-9abc-def012345678
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.single.sourceNoteIds, [
        '7c2b8e4a-3d5f-4b2c-8e6d-1a4f9e8c7b30',
        'fcd1eaff-1234-5678-9abc-def012345678',
      ]);
    });

    test('SOURCE entries with spaces inside a token are dropped', () {
      const raw = '''
Q: Q?
A: A.
SOURCE: note 001, note-002, foo bar baz
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.single.sourceNoteIds, ['note-002']);
    });

    test('CJK fullwidth colon (：) is tolerated as a label separator '
        '(Qwen drifts mid-generation) — regression for the on-device '
        'two-cards-instead-of-three case', () {
      // Reproduces an actual Qwen 2.5 1.7B output: the first two cards
      // used ASCII ":" but the third drifted to U+FF1A "：" (fullwidth).
      // Pre-fix the parser dropped the third card — its lines fell
      // through as continuations of the second card's SOURCE.
      const raw = '''
Q: What is an asteroid?
A: A small celestial body in space made of rocky or metallic fragments.
SOURCE: note-abc

Q: What causes tides?
A: The gravitational pull of the Moon and Sun creates tidal forces on Earth.
SOURCE: note-def

Q: How many moons does Earth have?
A：1
SOURCE：note-ghi
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 3);
      expect(cards[2].question, 'How many moons does Earth have?');
      expect(cards[2].answer, '1');
      expect(cards[2].sourceNoteIds, ['note-ghi']);
    });

    test('fullwidth colon (：) tolerated on Q: label too', () {
      const raw = '''
Q：What is gravity?
A：A force.
SOURCE：note-grav
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 1);
      expect(cards.single.question, 'What is gravity?');
      expect(cards.single.answer, 'A force.');
      expect(cards.single.sourceNoteIds, ['note-grav']);
    });

    test('empty SOURCE line → sourceNoteIds is empty (not [""])', () {
      const raw = '''
Q: Q?
A: A.
SOURCE:
''';
      expect(FlashcardGenPrompt.parse(raw).single.sourceNoteIds, isEmpty);
    });

    test('empty input → no cards', () {
      expect(FlashcardGenPrompt.parse(''), isEmpty);
      expect(FlashcardGenPrompt.parse('   \n\n  '), isEmpty);
    });

    test('output with no Q: at all → no cards (parser drops the noise)', () {
      const raw = '''
I'm sorry, I cannot generate flashcards for that topic.
Please try a different topic.
''';
      expect(FlashcardGenPrompt.parse(raw), isEmpty);
    });

    test('case-insensitive labels (q:, a:, source:)', () {
      const raw = '''
q: lowercase q
a: lowercase a
source: note-x
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.single.question, 'lowercase q');
      expect(cards.single.answer, 'lowercase a');
      expect(cards.single.sourceNoteIds, ['note-x']);
    });

    test(
        'kitchen sink: <think> block + markdown emphasis + numbering + '
        'multi-line A: + truncation in one input', () {
      const raw = '''
<think>
Thinking about gravity and friction...
</think>

1. **Q:** What is gravity?
   **A:** A force of attraction between masses
proportional to mass and inversely proportional
to the square of the distance.
   **SOURCE:** note-grav-1, note-grav-2

2. **Q:** What is friction?
   **A:** Resistance to relative motion between surfaces
in contact.
   **SOURCE:** note-frc

3. **Q:** What is — (truncated)
''';
      final cards = FlashcardGenPrompt.parse(raw);
      expect(cards.length, 2);
      expect(cards[0].question, 'What is gravity?');
      expect(
        cards[0].answer,
        'A force of attraction between masses '
        'proportional to mass and inversely proportional '
        'to the square of the distance.',
      );
      expect(cards[0].sourceNoteIds, ['note-grav-1', 'note-grav-2']);
      expect(cards[1].question, 'What is friction?');
      expect(cards[1].sourceNoteIds, ['note-frc']);
    });
  });
}
