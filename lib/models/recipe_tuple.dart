import 'package:uuid/uuid.dart';

/// A single recipe document in the Ditto `recipes` collection.
///
/// `embedding` is filled lazily by `RetrievalService.ensureEmbeddings()` on
/// first launch; it can be empty for freshly-inserted tuples.
class RecipeTuple {
  final String id;
  final String dish;
  final String contributor;
  final List<String> ingredients;
  final List<String> steps;
  final List<double> embedding;
  final DateTime createdAt;

  RecipeTuple({
    required this.id,
    required this.dish,
    required this.contributor,
    required this.ingredients,
    required this.steps,
    required this.embedding,
    required this.createdAt,
  });

  /// UUIDv5 over `(contributor, dish, createdAt)` so re-running the seed
  /// loader is a no-op (Ditto's `ON ID CONFLICT DO UPDATE` finishes the job).
  factory RecipeTuple.seed({
    required String dish,
    required String contributor,
    required List<String> ingredients,
    required List<String> steps,
    required DateTime createdAt,
  }) {
    final id = const Uuid().v5(
      Namespace.oid.value,
      '$contributor|$dish|${createdAt.toIso8601String()}',
    );
    return RecipeTuple(
      id: id,
      dish: dish,
      contributor: contributor,
      ingredients: ingredients,
      steps: steps,
      embedding: const [],
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toDittoDoc() => {
        '_id': id,
        'dish': dish,
        'contributor': contributor,
        'ingredients': ingredients,
        'steps': steps,
        'embedding': embedding,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RecipeTuple.fromDittoValue(Map<String, dynamic> v) {
    return RecipeTuple(
      id: v['_id'].toString(),
      dish: v['dish'].toString(),
      contributor: v['contributor'].toString(),
      ingredients: (v['ingredients'] as List).map((e) => e.toString()).toList(),
      steps: (v['steps'] as List).map((e) => e.toString()).toList(),
      embedding: (v['embedding'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [],
      createdAt: DateTime.parse(v['createdAt'].toString()),
    );
  }

  RecipeTuple copyWith({List<double>? embedding}) => RecipeTuple(
        id: id,
        dish: dish,
        contributor: contributor,
        ingredients: ingredients,
        steps: steps,
        embedding: embedding ?? this.embedding,
        createdAt: createdAt,
      );

  bool get hasEmbedding => embedding.isNotEmpty;
}
