import 'package:cactus/cactus.dart';

import '../services/retrieval_service.dart';

/// Stage-0 synthesis prompt: takes a topic and N retrieved study notes,
/// asks the on-device small LLM to produce a single normalized merged
/// answer that visibly draws on those notes.
///
/// Named "recipe_merge" because Stage 0's seed corpus framed notes as
/// recipes-in-a-virtual-potluck; the term outlasts the seed swap. The
/// pivot to flashcards (later commit) reuses the same retrieved-set shape
/// but generates a different output structure.
class RecipeMergePrompt {
  RecipeMergePrompt._();

  static List<ChatMessage> build({
    required String topic,
    required List<RetrievedNote> retrieved,
  }) {
    final notesBlock = retrieved.asMap().entries.map((e) {
      final i = e.key + 1;
      final n = e.value.note;
      return '($i) [${n.contributor}, score=${e.value.score.toStringAsFixed(3)}]\n'
          '    topic: ${n.topic}\n'
          '    body: ${n.body}';
    }).join('\n\n');

    final system =
        'You answer questions about "$topic" by synthesizing the study notes '
        'below into a coherent paragraph. Cite which notes contributed '
        '(e.g., "Note 1, Note 3").';

    final user =
        'Topic: $topic\n\n'
        'Retrieved notes:\n$notesBlock\n\n'
        'Produce a single normalized answer that draws on these notes.';

    return [
      ChatMessage(role: 'system', content: system),
      ChatMessage(role: 'user', content: user),
    ];
  }
}
