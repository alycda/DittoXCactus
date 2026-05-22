import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/study_note.dart';
import 'ditto_service.dart';

/// Reads `assets/seed_notes_<role>.json` and idempotently inserts each
/// note into the Ditto store. Driven by `--dart-define=PHONE_ROLE=a|b`.
class SeedLoader {
  SeedLoader._();
  static final SeedLoader instance = SeedLoader._();

  static const String _envRole = String.fromEnvironment(
    'PHONE_ROLE',
    defaultValue: 'a',
  );

  String get role => _envRole;
  String get assetPath => 'assets/seed_notes_$_envRole.json';

  /// The `contributor` value this device tags its notes with. Matches the
  /// values inside `assets/seed_notes_<role>.json`. Used by the UI to count
  /// how many retrieved notes came from a *peer* device versus this one.
  String get selfContributor => 'phone-$_envRole';

  Future<int> loadAndInsert() async {
    final raw = await rootBundle.loadString(assetPath);
    final List<dynamic> json = jsonDecode(raw) as List<dynamic>;
    final notes = json
        .cast<Map<String, dynamic>>()
        .map(_noteFromSeedJson)
        .toList();
    for (final n in notes) {
      await DittoService.instance.upsertNote(n);
    }
    return notes.length;
  }

  StudyNote _noteFromSeedJson(Map<String, dynamic> v) {
    return StudyNote.seed(
      topic: v['topic'].toString(),
      contributor: v['contributor'].toString(),
      body: v['body'].toString(),
      tags: (v['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: DateTime.parse(v['createdAt'].toString()),
    );
  }
}
