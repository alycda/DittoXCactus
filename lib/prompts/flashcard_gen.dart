import 'dart:convert';

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
/// study notes, and parses the streamed JSON output back into `Flashcard`s.
///
/// The contract is extractive: every card must be answerable from the
/// provided notes alone. This is well within a 1.5B model's reach (Anki's
/// flashcard-from-passage prompts run on gemma 270M acceptably); the pivot
/// from recipe synthesis is what makes Stage-0 LLM quality tractable.
class FlashcardGenPrompt {
  FlashcardGenPrompt._();

  static const String _system = '''
You are a careful study buddy. You receive several short notes on the same topic from different students, and you turn them into clear study flashcards.

Rules:
- Output ONLY a JSON array. No preamble, no commentary, no markdown fences.
- Each element has exactly three fields: "question" (string), "answer" (string), "sourceNoteIds" (array of strings).
- Each "answer" must be supported by the provided notes alone. Do NOT introduce facts that are not in the notes.
- For "sourceNoteIds", list the `id` of every note the card draws from. At least one id is required.
- Prefer concise questions (under 20 words) and concise answers (1-3 sentences).
- Cover distinct concepts; do not produce two cards with near-duplicate questions.
- Output exactly N cards, where N is given by the user.
''';

  /// Build the chat messages handed to `CactusService.complete`.
  static List<ChatMessage> build({
    required String topic,
    required int n,
    required List<RetrievedNote> retrieved,
  }) {
    final user = StringBuffer()
      ..writeln('Topic: $topic')
      ..writeln('N: $n')
      ..writeln()
      ..writeln('Notes (each from a separate device):');

    for (var i = 0; i < retrieved.length; i++) {
      final note = retrieved[i].note;
      user
        ..writeln()
        ..writeln('--- Note ${i + 1} ---')
        ..writeln('id: ${note.id}')
        ..writeln('contributor: ${note.contributor}')
        ..writeln('tags: ${note.tags.join(', ')}')
        ..writeln('body: ${note.body}');
    }

    if (retrieved.isEmpty) {
      user.writeln('(no notes retrieved — return an empty JSON array: [])');
    }

    user
      ..writeln()
      ..writeln('Return $n flashcards as a JSON array.');

    return [
      ChatMessage(content: _system, role: 'system'),
      ChatMessage(content: user.toString(), role: 'user'),
    ];
  }

  /// Parse the LLM's raw text into `Flashcard`s. Tolerant of common drift
  /// from a 1.5B model: leading prose, ```json fences, trailing commentary,
  /// and partial output truncated mid-element (we keep whatever cards we
  /// were able to fully parse).
  static List<Flashcard> parse(String raw) {
    final extracted = _extractJsonArray(raw);
    if (extracted == null) return const [];

    final dynamic decoded;
    try {
      decoded = jsonDecode(extracted);
    } on FormatException {
      // Fall back to a salvage parse: incrementally trim trailing tokens
      // and re-try until something parses, since 1.5B truncation often
      // lands mid-object.
      return _salvage(extracted);
    }

    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(_cardFromMap)
        .whereType<Flashcard>()
        .toList();
  }

  /// Find the JSON array slice in `raw`. If the outer `[...]` is balanced,
  /// returns exactly that slice (so trailing prose / fences are dropped). If
  /// the array is truncated (no matching `]`), returns everything from the
  /// opening `[` so `_salvage` can trim to the last complete element.
  static String? _extractJsonArray(String raw) {
    final start = raw.indexOf('[');
    if (start < 0) return null;
    var arrayDepth = 0;
    var inString = false;
    var escape = false;
    for (var i = start; i < raw.length; i++) {
      final c = raw[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (inString) {
        if (c == r'\') {
          escape = true;
          continue;
        }
        if (c == '"') inString = false;
        continue;
      }
      if (c == '"') {
        inString = true;
        continue;
      }
      if (c == '[') arrayDepth++;
      if (c == ']') {
        arrayDepth--;
        if (arrayDepth == 0) {
          return raw.substring(start, i + 1);
        }
      }
    }
    return raw.substring(start);
  }

  /// Last-resort parse: walk the JSON-ish string tracking string state and
  /// object depth, find the position of the last `}` that closes a top-level
  /// object inside the array, and decode `[...top-level objects...]`.
  static List<Flashcard> _salvage(String jsonish) {
    var depth = 0;
    var lastGoodEnd = -1;
    var inString = false;
    var escape = false;
    for (var i = 0; i < jsonish.length; i++) {
      final c = jsonish[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (inString) {
        if (c == r'\') {
          escape = true;
          continue;
        }
        if (c == '"') inString = false;
        continue;
      }
      if (c == '"') {
        inString = true;
        continue;
      }
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) lastGoodEnd = i;
      }
    }
    if (lastGoodEnd < 0) return const [];
    final trimmed = '${jsonish.substring(0, lastGoodEnd + 1)}]';
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(_cardFromMap)
          .whereType<Flashcard>()
          .toList();
    } on FormatException {
      return const [];
    }
  }

  static Flashcard? _cardFromMap(Map m) {
    final q = m['question'];
    final a = m['answer'];
    final ids = m['sourceNoteIds'];
    if (q is! String || a is! String || q.isEmpty || a.isEmpty) return null;
    final idList = (ids is List)
        ? ids.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return Flashcard(question: q, answer: a, sourceNoteIds: idList);
  }
}
