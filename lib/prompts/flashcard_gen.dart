import 'package:cactus/cactus.dart';

import '../services/retrieval_service.dart';

/// A single Q/A flashcard. Regenerated per query; not persisted in Ditto.
class Flashcard {
  final String question;
  final String answer;
  final List<String> sourceNoteIds;

  const Flashcard({
    required this.question,
    required this.answer,
    required this.sourceNoteIds,
  });

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'sourceNoteIds': sourceNoteIds,
      };
}

/// Builds the prompt for `cactus_complete` from a topic + top-k retrieved
/// study notes, and parses the streamed output back into `Flashcard`s.
///
/// **Why plain text instead of JSON.** Qwen 2.5 1.5B at Q4_K_M produces
/// structurally-broken JSON: single-quoted strings, unquoted object keys,
/// unescaped apostrophes, arrays where strings were requested. Forcing
/// `Q:` / `A:` line format trades parser tolerance for output reliability —
/// no nested syntax, no quote-escaping rules, no closing brackets to miss.
/// Also robust to mid-stream truncation: a half-finished `A:` line is
/// recoverable, a half-finished JSON object is not.
///
/// **`<think>` block stripping.** Qwen 2.5 leaks chain-of-thought into the
/// output even when told not to. `/no_think` only applies to Qwen3. We strip
/// the leak in the parser instead.
class FlashcardGenPrompt {
  FlashcardGenPrompt._();

  static const String _system = '''
You are a careful study buddy. You make study flashcards from short notes.

Output rules:
- Output flashcards ONLY in this exact format:
  Q: <one short question>
  A: <one factual statement, one sentence, 15 words or fewer>
  SOURCE: <comma-separated note ids the card draws from>
- Separate flashcards with a blank line.
- Do NOT include any reasoning, planning, thinking, prefaces, or summaries.
- Do NOT wrap labels in markdown — no "**Q:**", no "*A:*". Plain "Q:" and "A:" only.
- Do NOT use JSON. Do NOT use bullets or numbering.
- Every answer must be supported by the provided notes alone. Do NOT invent facts.
- Cover distinct concepts; do not produce two near-duplicate questions.
- The answer must read naturally in either direction: as the answer to
  the question, AND as a clue whose response is the question's subject.
  Avoid restating the question inside the answer.
- Output exactly N flashcards, where N is given by the user.

Example output (copy this exact shape, plain text, no markdown):

Q: What pushes a comet's plasma tail directly away from the Sun?
A: The solar wind.
SOURCE: abc-123

Q: Which belt is the source of most short-period comets?
A: The Kuiper Belt.
SOURCE: def-456
''';

  /// Build the chat messages handed to `CactusService.complete`.
  ///
  /// [savedExamples] are flashcards the user previously rated as good (in
  /// memory, per device). They're included as few-shot exemplars so the
  /// model mirrors the style the user has signalled they want. Empty by
  /// default — first generation always runs without exemplars.
  static List<ChatMessage> build({
    required String topic,
    required int n,
    required List<RetrievedNote> retrieved,
    List<Flashcard> savedExamples = const [],
  }) {
    final user = StringBuffer()
      ..writeln('Topic: $topic')
      ..writeln('Number of flashcards (N): $n');

    if (savedExamples.isNotEmpty) {
      user
        ..writeln()
        ..writeln(
          'Below are flashcards you produced before that the user kept '
          '(rated as good). Mirror their style, length, and tone in the new '
          'cards. Do not copy them verbatim — just match the shape:',
        );
      for (final ex in savedExamples.take(3)) {
        user
          ..writeln()
          ..writeln('Q: ${ex.question}')
          ..writeln('A: ${ex.answer}');
      }
    }

    user
      ..writeln()
      ..writeln('Notes:');

    for (var i = 0; i < retrieved.length; i++) {
      final note = retrieved[i].note;
      user
        ..writeln()
        ..writeln('Note ${i + 1} (id: ${note.id}):')
        ..writeln(note.body);
    }

    if (retrieved.isEmpty) {
      user.writeln('(no notes available — output nothing.)');
    }

    user
      ..writeln()
      ..writeln('Now output $n flashcards in the Q: / A: / SOURCE: format. '
          'Start with "Q:" on its own line. No reasoning, no preamble.');

    return [
      ChatMessage(content: _system, role: 'system'),
      ChatMessage(content: user.toString(), role: 'user'),
    ];
  }

  /// Parse the LLM's raw text into `Flashcard`s. Tolerant of:
  /// - `<think>...</think>` reasoning leaks (Qwen)
  /// - Missing/early-truncated final card (we keep complete ones)
  /// - Bullet/numeric prefixes the model might add (`1.`, `-`, `*`)
  /// - `Q.` / `Q)` / `Question:` variations and the same for A/NOTES
  /// - Extra blank lines, indentation, surrounding prose
  static List<Flashcard> parse(String raw) {
    final cleaned = _stripThinking(raw);
    final cards = <Flashcard>[];

    String? curQ;
    final curA = StringBuffer();
    var curIds = <String>[];
    String? lastField; // 'q' | 'a' | 'n' — for continuation lines

    void flush() {
      final q = curQ?.trim();
      final a = curA.toString().trim();
      if (q != null && q.isNotEmpty && a.isNotEmpty) {
        cards.add(Flashcard(
          question: q,
          answer: a,
          sourceNoteIds: List.unmodifiable(curIds),
        ));
      }
      curQ = null;
      curA.clear();
      curIds = <String>[];
      lastField = null;
    }

    for (final rawLine in cleaned.split('\n')) {
      // Strip markdown emphasis characters up front. The 1.5B routinely wraps
      // prefixes as `**Q:**`, `*A:*`, `__SOURCE__:` — pre-normalizing kills
      // every variant in one move and keeps the prefix regexes simple. The
      // tradeoff is losing legitimate `*`/`_` in content, which is rare in
      // flashcard text and acceptable for a demo.
      final line = rawLine.replaceAll(RegExp(r'[*_]'), '').trimRight();
      if (line.trim().isEmpty) {
        // A blank line ends a continuation but doesn't yet flush the card —
        // some models put blank lines between Q and A.
        lastField = null;
        continue;
      }

      final qMatch = _qPrefix.firstMatch(line);
      if (qMatch != null) {
        // New card starting. Flush previous if any.
        if (curQ != null) flush();
        curQ = line.substring(qMatch.end).trim();
        lastField = 'q';
        continue;
      }
      final aMatch = _aPrefix.firstMatch(line);
      if (aMatch != null) {
        curA.write(line.substring(aMatch.end).trim());
        lastField = 'a';
        continue;
      }
      final nMatch = _notesPrefix.firstMatch(line);
      if (nMatch != null) {
        final csv = line.substring(nMatch.end).trim();
        curIds = csv
            .split(RegExp(r'[,\s]+'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        lastField = 'n';
        continue;
      }

      // Continuation line: append to whichever field we last opened.
      final clean = line.trim();
      if (lastField == 'q' && curQ != null) {
        curQ = '${curQ!} $clean';
      } else if (lastField == 'a') {
        if (curA.isNotEmpty) curA.write(' ');
        curA.write(clean);
      }
      // For 'n' or null, just drop the stray line — likely prose/garbage.
    }
    flush();

    return cards;
  }

  /// Strip Qwen-style reasoning blocks. Some chat templates emit
  /// `<think>...</think>` (or `<thinking>...`) before the actual answer, which
  /// burns tokens and confuses the parser. Also strips an unclosed `<think>`
  /// prefix if real content appears after it.
  static String _stripThinking(String raw) {
    var out = raw.replaceAll(
      RegExp(r'<think(?:ing)?>[\s\S]*?</think(?:ing)?>', caseSensitive: false),
      '',
    );
    final openTag = RegExp(r'<think(?:ing)?>', caseSensitive: false);
    final openMatch = openTag.firstMatch(out);
    if (openMatch != null) {
      // Find the first Q: anchor and drop everything before it.
      final qIdx = _qPrefix.firstMatch(out)?.start;
      if (qIdx != null && qIdx > openMatch.start) {
        out = out.substring(qIdx);
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Line-prefix regexes. Markdown emphasis chars are stripped from each line
  // before these run (see the parse loop), so the patterns stay simple.
  // Permissive on: punctuation (`:`, `.`, `)`), bullet/number prefixes
  // (`1.`, `- `), and long-form labels (Question/Answer/Source/Notes/From).
  static final RegExp _qPrefix = RegExp(
    r'^\s*(?:[-]\s+|\d+[.)]\s+)?Q(?:uestion)?\s*[:.)]\s*',
    caseSensitive: false,
  );
  static final RegExp _aPrefix = RegExp(
    r'^\s*(?:[-]\s+|\d+[.)]\s+)?A(?:nswer)?\s*[:.)]\s*',
    caseSensitive: false,
  );
  static final RegExp _notesPrefix = RegExp(
    r'^\s*(?:[-]\s+|\d+[.)]\s+)?(?:NOTES?|FROM|SOURCES?)\s*[:.)]\s*',
    caseSensitive: false,
  );
}
