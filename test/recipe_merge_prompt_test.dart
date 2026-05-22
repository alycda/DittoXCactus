import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_rag_demo/models/recipe_tuple.dart';
import 'package:mesh_rag_demo/prompts/recipe_merge.dart';
import 'package:mesh_rag_demo/services/retrieval_service.dart';

void main() {
  group('RecipeMergePrompt', () {
    RecipeTuple variant(String contributor, List<String> ingredients) =>
        RecipeTuple.seed(
          dish: 'chicken tortilla soup',
          contributor: contributor,
          ingredients: ingredients,
          steps: const ['stir', 'simmer'],
          createdAt: DateTime.parse('2026-05-21T00:00:00Z'),
        );

    test('builds a system + user pair', () {
      final msgs = RecipeMergePrompt.build(
        query: 'what is chicken tortilla soup',
        retrieved: [
          RetrievedRecipe(variant('phone-a', const ['chicken', 'tomato']), 0.91),
          RetrievedRecipe(variant('phone-b', const ['black beans', 'tomato']), 0.87),
        ],
      );
      expect(msgs.length, equals(2));
      expect(msgs[0].role, equals('system'));
      expect(msgs[1].role, equals('user'));
      // Each variant's contributor must appear so the LLM can attribute.
      expect(msgs[1].content, contains('phone-a'));
      expect(msgs[1].content, contains('phone-b'));
      // Shared ingredient (tomato) is present from both — synthesizer can fold it.
      expect(msgs[1].content, contains('tomato'));
    });

    test('empty retrieval falls back to "I don\'t know yet"', () {
      final msgs = RecipeMergePrompt.build(
        query: 'soup',
        retrieved: const [],
      );
      expect(msgs[1].content.toLowerCase(), contains("don't know"));
    });
  });
}
