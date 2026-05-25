/// Prompt assembly + tolerant Q/A/SOURCE parser for Stage 1 flashcard
/// generation.
///
/// **Plan §U11.** The prompt shape is deliberately plain-text (Q:/A:/SOURCE:)
/// rather than JSON because a 1.5B-class model truncates JSON in a way that
/// poisons downstream parsing — Q:/A:/SOURCE: lines survive truncation: any
/// complete card before the cut is recoverable.
///
/// **Parser tolerance.** The model under-instruction-following is the
/// dominant failure mode at this size class. The parser absorbs:
///   - markdown emphasis around labels (`**Q:**`, `*A:*`)
///   - bullet / number prefixes (`- Q:`, `1. Q:`, `1) Q:`)
///   - long-form labels (`Question:`, `Answer:`, `Source:`, `Notes:`, `From:`)
///   - `<think>...</think>` blocks (Qwen 2.5 chain-of-thought leak;
///     `/no_think` is Qwen3-only so we can't silence it at the model)
///   - unclosed `<think>` prefixes (anchored at the first Q-line)
///   - multi-line continuations under Q:/A:/SOURCE:
///   - mid-card stream truncation (drops the incomplete tail; keeps
///     complete prior cards)
///
/// References:
/// - `_inspiration/repos/software-mansion-labs__react-native-rag/` —
///   prompt assembly + source-attribution pattern.
/// - `_inspiration/repos/deepsense-ai__edge-slm/` — small-LLM-on-mobile
///   template shape.
library mesh_rag.prompts.flashcard_gen;

import 'package:cactus/cactus.dart' show ChatMessage;

import '../services/retrieval_service.dart';

/// Cap how many up-rated exemplars get folded into the user message.
/// The prompt budget is tight on a 2048-token context; 3 exemplars is
/// the largest count that fits comfortably alongside ≤ 5 notes × ~200
/// chars each (plan §U11 Approach).
const int kMaxFewShotExemplars = 3;

/// Static helpers — there's no per-call state worth holding on an instance.
class FlashcardGenPrompt {
  FlashcardGenPrompt._();

  // ───── Build ──────────────────────────────────────────────────────────

  /// Assemble the system + user messages for a flashcard generation call.
  ///
  /// When `retrieved` is empty the user message closes with
  /// `(no notes available — output nothing.)` rather than the
  /// "output N flashcards" imperative. This is a hard-coded out: at
  /// Stage 0 corpus sizes, "no notes" means the device hasn't booted or
  /// the topic is entirely off-corpus — either way fabricating cards
  /// would tank the demo's grounding claim (see CLAUDE.md
  /// `feedback_llm_grounding`).
  static List<ChatMessage> build({
    required String topic,
    required int n,
    required List<RetrievedNote> retrieved,
    List<Flashcard> savedExamples = const [],
  }) {
    return [
      ChatMessage(role: 'system', content: _systemMessage),
      ChatMessage(
        role: 'user',
        content: _buildUserMessage(
          topic: topic,
          n: n,
          retrieved: retrieved,
          savedExamples: savedExamples,
        ),
      ),
    ];
  }

  /// System preamble. Pinned verbatim by the happy-path test so a future
  /// edit to the wording shows up in CI as a deliberate change, not a
  /// silent drift.
  static const String _systemMessage = '''
You are a careful study buddy. You make study flashcards from short notes.

Output rules:
- Output ONLY flashcards. No reasoning, no preamble.
- Each card has three lines in this exact format:
  Q: <a clear question>
  A: <a short answer, one sentence>
  SOURCE: <comma-separated note ids that support the answer>
- No markdown emphasis (no **Q:**, no italics). No JSON. No bullets. No numbering.
- No <think> blocks. No chain-of-thought.
- Do not make up facts. If the notes do not support a claim, do not make the claim.
- Avoid near-duplicate questions.

Example:

Q: What is escape velocity?
A: The minimum speed needed to break free of a body's gravity without further propulsion.
SOURCE: note-abc, note-def

Output exactly N flashcards.''';

  static String _buildUserMessage({
    required String topic,
    required int n,
    required List<RetrievedNote> retrieved,
    required List<Flashcard> savedExamples,
  }) {
    final buf = StringBuffer();
    buf.writeln('Topic: $topic');
    buf.writeln('Number of flashcards (N): $n');

    if (savedExamples.isNotEmpty) {
      final exemplars =
          savedExamples.take(kMaxFewShotExemplars).toList(growable: false);
      buf.writeln();
      buf.writeln(
        'Below are flashcards you produced before that the user kept — '
        'mirror their style:',
      );
      for (final ex in exemplars) {
        buf.writeln();
        buf.writeln('Q: ${ex.question}');
        buf.writeln('A: ${ex.answer}');
        buf.writeln('SOURCE: ${ex.sourceNoteIds.join(', ')}');
      }
    }

    buf.writeln();
    buf.writeln('Notes:');
    if (retrieved.isEmpty) {
      buf.write('(no notes available — output nothing.)');
      return buf.toString();
    }
    for (var i = 0; i < retrieved.length; i++) {
      final note = retrieved[i].note;
      buf.writeln('Note ${i + 1} (id: ${note.id}): ${note.body}');
    }
    buf.writeln();
    buf.write(
      'Now output N flashcards in the Q: / A: / SOURCE: format. '
      'Start with "Q:" on its own line. No reasoning, no preamble.',
    );
    return buf.toString();
  }

  // ───── Parse ──────────────────────────────────────────────────────────

  /// Tolerant Q:/A:/SOURCE: parser. Returns only complete cards
  /// (question + answer both non-empty); incomplete trailing cards are
  /// dropped on stream truncation.
  static List<Flashcard> parse(String raw) {
    final stripped = _stripThinkBlocks(raw);
    final lines = stripped.split('\n');

    final cards = <Flashcard>[];
    String q = '';
    String a = '';
    String s = '';
    _Section section = _Section.beforeQ;

    void commit() {
      if (q.trim().isNotEmpty && a.trim().isNotEmpty) {
        cards.add(Flashcard(
          question: q.trim(),
          answer: a.trim(),
          sourceNoteIds: _splitSourceList(s),
        ));
      }
      q = '';
      a = '';
      s = '';
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        // Blank lines are separators within a multi-line continuation
        // group — don't commit on them. A new Q: line is the only signal
        // that the previous card is closed.
        continue;
      }
      final labeled = _matchLabel(line);
      if (labeled == null) {
        // Continuation line for the active section, if any.
        final body = _stripEmphasis(line.trim());
        switch (section) {
          case _Section.beforeQ:
            // Garbage before the first Q — ignore.
            break;
          case _Section.inQ:
            q = q.isEmpty ? body : '$q $body';
          case _Section.inA:
            a = a.isEmpty ? body : '$a $body';
          case _Section.inSource:
            s = s.isEmpty ? body : '$s, $body';
        }
        continue;
      }
      switch (labeled.kind) {
        case _LabelKind.q:
          commit();
          q = labeled.content;
          section = _Section.inQ;
        case _LabelKind.a:
          if (section == _Section.beforeQ) {
            // A: without a preceding Q: → treat as preamble noise.
            break;
          }
          a = labeled.content;
          section = _Section.inA;
        case _LabelKind.source:
          if (section == _Section.beforeQ) break;
          s = labeled.content;
          section = _Section.inSource;
      }
    }
    commit();
    return cards;
  }

  /// Shape an id-token must match to count as a source. Note ids in this
  /// project are UUIDv5 strings or seed-style `note-...` slugs — both are
  /// alphanumeric with dashes/underscores only.
  ///
  /// On-device U11 surfaced a model that emitted reasoning text on the
  /// SOURCE line (something like `SOURCE: my notes are nothing, even here
  /// are claims (i.e. unreliable), but wait...`). Comma-splitting that
  /// without a shape filter produced 30+ "chips" of garbage. This regex
  /// drops anything containing whitespace, parens, quotes, or other
  /// non-id punctuation — the chip wall disappears, real ids still pass.
  static final RegExp _idShape = RegExp(r'^[a-zA-Z0-9_-]+$');

  static List<String> _splitSourceList(String raw) {
    if (raw.trim().isEmpty) return const [];
    // Tolerate surrounding brackets the model sometimes emits.
    var inner = raw.trim();
    if ((inner.startsWith('[') && inner.endsWith(']')) ||
        (inner.startsWith('(') && inner.endsWith(')'))) {
      inner = inner.substring(1, inner.length - 1);
    }
    return inner
        .split(RegExp(r'[,;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && _idShape.hasMatch(s))
        .toList(growable: false);
  }

  // Strip both closed `<think>...</think>` blocks (greedy, multi-line) and
  // an unclosed leading `<think>` prefix. The unclosed case can't be
  // regex-stripped safely because the prefix could swallow the entire
  // output; instead, the line-walker anchors at the first Q-line and
  // discards everything before it (handled in the main parse loop via
  // _Section.beforeQ + the "garbage before the first Q — ignore" branch).
  static String _stripThinkBlocks(String raw) {
    return raw.replaceAll(
      RegExp(r'<think\b[^>]*>.*?</think>', dotAll: true),
      '',
    );
  }

  static const _bulletPrefix = r'(?:[-*•·]\s+)?';
  static const _numberPrefix = r'(?:\d+[.):]\s+)?';
  static const _emphasisChars = r'[*_]*';
  static const _separator = r'[:.)—–]';

  // Anchored label match. Case-insensitive. The label group is captured
  // for kind-dispatch; the body group is the line tail.
  static final RegExp _labelRe = RegExp(
    '^\\s*$_bulletPrefix$_numberPrefix$_emphasisChars\\s*'
    r'(Q|Question|A|Answer|SOURCE|Source|Sources|From|Notes|Note)'
    '$_emphasisChars\\s*$_separator\\s*$_emphasisChars\\s*(.*)\$',
    caseSensitive: false,
  );

  static _Labeled? _matchLabel(String line) {
    final m = _labelRe.firstMatch(line);
    if (m == null) return null;
    final label = m.group(1)!.toLowerCase();
    final content = _stripEmphasis((m.group(2) ?? '').trim());
    final kind = switch (label) {
      'q' || 'question' => _LabelKind.q,
      'a' || 'answer' => _LabelKind.a,
      _ => _LabelKind.source,
    };
    return _Labeled(kind, content);
  }

  /// Strip trailing markdown emphasis from a body string. The body's been
  /// taken after the label match, so the `**` / `*` / `_` we strip here
  /// is the closing pair of `**Q:**` style emphasis.
  static String _stripEmphasis(String body) {
    var out = body;
    while (out.endsWith('**')) {
      out = out.substring(0, out.length - 2).trimRight();
    }
    while (out.endsWith('*') || out.endsWith('_')) {
      out = out.substring(0, out.length - 1).trimRight();
    }
    return out;
  }
}

enum _Section { beforeQ, inQ, inA, inSource }

enum _LabelKind { q, a, source }

class _Labeled {
  final _LabelKind kind;
  final String content;
  const _Labeled(this.kind, this.content);
}
