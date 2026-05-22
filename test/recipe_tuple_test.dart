import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_rag_demo/models/recipe_tuple.dart';

void main() {
  group('RecipeTuple', () {
    test('seed UUID is deterministic across re-runs', () {
      final t = DateTime.parse('2026-05-21T00:00:01Z');
      final a = RecipeTuple.seed(
        dish: 'chicken tortilla soup',
        contributor: 'phone-a',
        ingredients: const ['salt'],
        steps: const ['stir'],
        createdAt: t,
      );
      final b = RecipeTuple.seed(
        dish: 'chicken tortilla soup',
        contributor: 'phone-a',
        ingredients: const ['salt'],
        steps: const ['stir'],
        createdAt: t,
      );
      expect(a.id, equals(b.id), reason: 'same (contributor, dish, createdAt) → same UUID');
    });

    test('seed UUID differs for different contributors', () {
      final t = DateTime.parse('2026-05-21T00:00:01Z');
      final a = RecipeTuple.seed(
        dish: 'chicken tortilla soup',
        contributor: 'phone-a',
        ingredients: const ['salt'],
        steps: const ['stir'],
        createdAt: t,
      );
      final b = RecipeTuple.seed(
        dish: 'chicken tortilla soup',
        contributor: 'phone-b',
        ingredients: const ['salt'],
        steps: const ['stir'],
        createdAt: t,
      );
      expect(a.id, isNot(equals(b.id)));
    });

    test('round-trips through Ditto doc shape', () {
      final original = RecipeTuple.seed(
        dish: 'pho',
        contributor: 'phone-a',
        ingredients: const ['rice noodles', 'beef broth'],
        steps: const ['simmer'],
        createdAt: DateTime.parse('2026-05-21T00:00:01Z'),
      ).copyWith(embedding: const [0.1, -0.2, 0.3]);

      final doc = original.toDittoDoc();
      final restored = RecipeTuple.fromDittoValue(doc);

      expect(restored.id, equals(original.id));
      expect(restored.dish, equals(original.dish));
      expect(restored.contributor, equals(original.contributor));
      expect(restored.ingredients, equals(original.ingredients));
      expect(restored.steps, equals(original.steps));
      expect(restored.embedding, equals(original.embedding));
      expect(restored.createdAt, equals(original.createdAt));
    });

    test('hasEmbedding flips after copyWith', () {
      final t = DateTime.parse('2026-05-21T00:00:01Z');
      final empty = RecipeTuple.seed(
        dish: 'x',
        contributor: 'p',
        ingredients: const [],
        steps: const [],
        createdAt: t,
      );
      expect(empty.hasEmbedding, isFalse);
      final filled = empty.copyWith(embedding: const [0.5]);
      expect(filled.hasEmbedding, isTrue);
    });
  });
}
