import 'package:cactus/cactus.dart';

import '../services/retrieval_service.dart';

/// Builds the prompt for `cactus_complete` from a query + top-k retrieved
/// `RetrievedRecipe`s. The synthesis instruction is deliberately small —
/// no chain-of-thought, no critic step. Stage 0 is "tell me the recipe."
class RecipeMergePrompt {
  RecipeMergePrompt._();

  static const String _system = '''
You are a careful home cook. You receive several variants of the same dish and synthesize them into one coherent recipe.

Rules:
- Prefer ingredients that appear in multiple variants. If a variant introduces an ingredient no other variant has, mention it but flag it as optional.
- For each ingredient, write `[from <contributor>]` after it, naming the variant(s) that supplied it. Use the contributor name verbatim from the variants.
- If two variants disagree on a step, briefly say so.
- Output a short merged recipe: 1-line description, then "Ingredients:" bullet list, then "Steps:" numbered list. No preamble.
''';

  static List<ChatMessage> build({
    required String query,
    required List<RetrievedRecipe> retrieved,
  }) {
    final user = StringBuffer()
      ..writeln('Question: $query')
      ..writeln()
      ..writeln('Variants (each from a separate device):');

    for (var i = 0; i < retrieved.length; i++) {
      final r = retrieved[i].recipe;
      user
        ..writeln()
        ..writeln('--- Variant ${i + 1} (contributor: ${r.contributor}, dish: ${r.dish}) ---')
        ..writeln('Ingredients: ${r.ingredients.join(', ')}')
        ..writeln('Steps:');
      for (var j = 0; j < r.steps.length; j++) {
        user.writeln('  ${j + 1}. ${r.steps[j]}');
      }
    }

    if (retrieved.isEmpty) {
      user.writeln('(no variants retrieved — say "I don\'t know yet" and stop.)');
    }

    return [
      ChatMessage(content: _system, role: 'system'),
      ChatMessage(content: user.toString(), role: 'user'),
    ];
  }
}
