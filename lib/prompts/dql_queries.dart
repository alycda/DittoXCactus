/// Centralized DQL strings for the `recipes` collection.
///
/// Keeping them here makes the queries easy to lock when the Ditto SDK lands a
/// breaking syntax change and lets U7's sync-verification screen reach for the
/// same constants the rest of the app uses.
class RecipeQueries {
  RecipeQueries._();

  static const String collection = 'recipes';

  static const String selectAll = 'SELECT * FROM recipes';

  static const String selectById = 'SELECT * FROM recipes WHERE _id = :id';

  /// Insert or merge: if a row with the same UUID already exists (e.g. from a
  /// previous launch or from a peer that already inserted it), Ditto applies
  /// the doc as an update — making the seed insert idempotent.
  static const String upsert =
      'INSERT INTO recipes DOCUMENTS (:doc) ON ID CONFLICT DO UPDATE';

  /// Used by ensureEmbeddings to fill in the embedding column after a tuple
  /// first appears in the local store.
  static const String setEmbedding =
      'UPDATE recipes SET embedding = :embedding WHERE _id = :id';

  static const String syncSubscription = 'SELECT * FROM recipes';
}
