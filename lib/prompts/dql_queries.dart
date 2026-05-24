/// DQL strings for the `notes` collection.
///
/// Kept in one place so that schema migrations (U7 + future units) only have
/// to touch this file rather than chasing query strings across services.
/// The plan's per-source citations for shape decisions live in
/// `_docs/plans/001-feat-mesh-rag-demo.md` §Key Technical Decisions (the
/// `notes` tuple layout) and §U5 (the subscription + observer pattern).
library mesh_rag.prompts.dql_queries;

abstract final class NotesQueries {
  NotesQueries._();

  /// Subscription target. Stage 0 syncs the entire `notes` collection — there
  /// is no privacy filter, no soft-delete column, and no per-peer view yet
  /// (see plan §Scope Boundaries: privacy and ACL are explicitly out).
  static const String syncSubscription = 'SELECT * FROM notes';

  /// Used by the UI's live observer (U10's notes tab) and by
  /// [RetrievalService.topK] (U9) to materialize the full corpus into Dart
  /// memory before the brute-force cosine pass.
  static const String selectAll = 'SELECT * FROM notes';

  /// Single-row read by `_id`. Argument: `:id` (string).
  static const String selectById = 'SELECT * FROM notes WHERE _id = :id';

  /// Returns rows whose embedding has not yet been backfilled. Used by
  /// [RetrievalService.ensureEmbeddings] (U8 second pass) to find work.
  static const String selectMissingEmbedding =
      'SELECT * FROM notes WHERE embedding IS NULL';

  /// Insert-or-update. Argument: `:doc` (Map<String, dynamic>; the document
  /// itself, including `_id`).
  ///
  /// `ON ID CONFLICT DO UPDATE` makes seed re-runs idempotent — the seed
  /// loader (U8) writes the same UUIDv5-derived `_id` on each launch, so
  /// the second launch is a no-op write rather than a duplicate.
  static const String upsert =
      'INSERT INTO notes DOCUMENTS (:doc) ON ID CONFLICT DO UPDATE';

  /// Backfill a single document's embedding once Cactus has loaded.
  /// Arguments: `:id` (string), `:embedding` (List<double>).
  static const String setEmbedding =
      'UPDATE notes SET embedding = :embedding WHERE _id = :id';
}
