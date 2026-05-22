import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/recipe_tuple.dart';
import 'ditto_service.dart';

/// Reads `assets/seed_recipes_<role>.json` and idempotently inserts each
/// tuple into the Ditto store. Driven by `--dart-define=PHONE_ROLE=a|b`.
class SeedLoader {
  SeedLoader._();
  static final SeedLoader instance = SeedLoader._();

  static const String _envRole = String.fromEnvironment(
    'PHONE_ROLE',
    defaultValue: 'a',
  );

  String get role => _envRole;
  String get assetPath => 'assets/seed_recipes_$_envRole.json';

  Future<int> loadAndInsert() async {
    final raw = await rootBundle.loadString(assetPath);
    final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
    final recipes = json
        .cast<Map<String, dynamic>>()
        .map(_recipeFromSeedJson)
        .toList();
    for (final r in recipes) {
      await DittoService.instance.upsertRecipe(r);
    }
    return recipes.length;
  }

  RecipeTuple _recipeFromSeedJson(Map<String, dynamic> v) {
    return RecipeTuple.seed(
      dish: v['dish'].toString(),
      contributor: v['contributor'].toString(),
      ingredients: (v['ingredients'] as List).map((e) => e.toString()).toList(),
      steps: (v['steps'] as List).map((e) => e.toString()).toList(),
      createdAt: DateTime.parse(v['createdAt'].toString()),
    );
  }
}
