/// Loads `assets/seed_notes_<role>.json` and idempotently upserts each
/// entry into Ditto. If a seed row carries a pre-baked `embedding`
/// field, it is passed through verbatim; otherwise the embedding
/// column is left empty and U9's `RetrievalService.ensureEmbeddings`
/// backfills it after Cactus is ready (two-phase corpus preload — see
/// plan §U8 Approach).
///
/// **Pre-baked embeddings (R5 cold-load lever):** the on-device
/// embedding-backfill of 5 short notes was clocked at ~9.7s on
/// Pixel 6a (78% of cold-load total). Shipping the embedding bytes
/// in the seed JSON drops that to ~0ms. Backing tool:
/// `--dart-define=BAKE_EMBEDDINGS=true` boot mode writes the
/// embedded JSON to the device docs dir for `adb pull` back to
/// `assets/`. See `_docs/model-quirks.md` (R5 lever §) and
/// `just bake-seeds-*` recipes for the workflow.
///
/// Idempotence comes for free from two layers:
///   1. `StudyNote.seed` derives `_id` from `(contributor, topic, createdAt)`
///      so the same JSON row always produces the same UUIDv5 on every device.
///   2. `DittoService.upsertNote` runs DQL
///      `INSERT INTO notes DOCUMENTS (:doc) ON ID CONFLICT DO UPDATE`, so
///      re-inserting the same id is a no-op write.
///
/// Together: relaunch the app, the seed runs again, the corpus count stays
/// the same. Demo-day chaos (force-close, reboot, screen-share crash) is
/// survivable without manual cleanup.
library mesh_rag.services.seed_loader;

import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../models/study_note.dart';
import 'ditto_service.dart';

class SeedLoader {
  SeedLoader._();
  static final SeedLoader instance = SeedLoader._();

  /// Reads `--dart-define=PHONE_ROLE`. Defaults to `'a'` so a developer who
  /// forgets the flag still boots somewhere instead of failing with a
  /// confusing FFI error — but `main.dart`'s `_validatePhoneRole()` runs
  /// before this and rejects any value other than `'a'` or `'b'` at runtime.
  String get role =>
      const String.fromEnvironment('PHONE_ROLE', defaultValue: 'a');

  /// Pubspec-declared asset path for this device's seed corpus.
  String get assetPath => 'assets/seed_notes_$role.json';

  /// `phone-a` / `phone-b` — the value the JSON's `contributor` field
  /// should match and the value U10's NotesTab groups self-vs-peer by.
  String get selfContributor => 'phone-$role';

  /// Load this device's seed JSON, parse to [StudyNote]s, and upsert each
  /// via [DittoService.upsertNote]. Returns the count of notes processed
  /// (== fixture size; re-runs land the same count because upsert is
  /// idempotent).
  Future<int> loadAndInsert() async {
    final raw = await rootBundle.loadString(assetPath);
    final notes = parseSeedJson(raw);
    for (final note in notes) {
      await DittoService.instance.upsertNote(note);
    }
    return notes.length;
  }

  /// Pure-function parse: JSON string → list of [StudyNote]s with
  /// embeddings cleared. Static + visibleForTesting so unit tests can hit
  /// it without a Flutter binding (no `rootBundle.loadString`).
  ///
  /// Throws [FormatException] (from `jsonDecode`) for malformed JSON, or
  /// [ArgumentError] if a row is missing a required field.
  @visibleForTesting
  static List<StudyNote> parseSeedJson(String jsonText) {
    final list = jsonDecode(jsonText);
    if (list is! List) {
      throw ArgumentError(
          'Seed JSON must be a top-level array; got ${list.runtimeType}.');
    }
    return list.map<StudyNote>((entry) {
      if (entry is! Map<String, dynamic>) {
        throw ArgumentError('Seed entry must be an object; got $entry.');
      }
      // Pre-baked embedding (optional). When present, U9's
      // ensureEmbeddings becomes a no-op on this row and cold-load
      // skips the per-note inference cost. See the library docstring.
      final embeddingField = entry['embedding'];
      List<double> embedding = const [];
      if (embeddingField is List) {
        embedding = embeddingField.map((v) => (v as num).toDouble()).toList();
      } else if (embeddingField != null) {
        throw ArgumentError(
            'Seed entry "embedding" must be a list of numbers when present; '
            'got ${embeddingField.runtimeType}.');
      }
      return StudyNote.seed(
        contributor: _required<String>(entry, 'contributor'),
        topic: _required<String>(entry, 'topic'),
        createdAt:
            DateTime.parse(_required<String>(entry, 'createdAt')).toUtc(),
        tags: (_required<List>(entry, 'tags')).cast<String>(),
        body: _required<String>(entry, 'body'),
        embedding: embedding,
      );
    }).toList(growable: false);
  }

  static T _required<T>(Map<String, dynamic> entry, String key) {
    final v = entry[key];
    if (v is! T) {
      throw ArgumentError(
          'Seed entry missing or wrong-typed field "$key" (expected $T, '
          'got ${v.runtimeType}).');
    }
    return v;
  }
}
