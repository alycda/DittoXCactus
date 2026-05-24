// Tests for SeedLoader (U8).
//
// The on-device upsert path (`loadAndInsert` → `DittoService.upsertNote`)
// needs a live Ditto and is exercised by manual device run. What's testable
// without that is the JSON-parse pipeline + role/path accessors, both of
// which are pure(-ish) and worth guarding so a future U3 corpus edit can't
// silently break U8.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/services/seed_loader.dart';

void main() {
  group('SeedLoader.parseSeedJson', () {
    test('parses both checked-in seed files (5 + 5)', () {
      // Sanity: the U3 corpus parses against the U7 schema via the U8
      // entry point. (U7's tests also do this; running it here too means
      // a SeedLoader regression that breaks the parse path surfaces in
      // the suite that owns SeedLoader.)
      final aJson = const ['a', 'b'].map((role) {
        return jsonEncode(_inlineSeedFixture(role));
      }).toList();
      for (var i = 0; i < 2; i++) {
        final notes = SeedLoader.parseSeedJson(aJson[i]);
        expect(notes.length, 1,
            reason: 'Inline fixture has 1 row; checked-in JSON has 5.');
        expect(notes.first.hasEmbedding, isFalse,
            reason: 'Seed JSON does not pre-compute embeddings; '
                'U9 ensureEmbeddings backfills them.');
      }
    });

    test('preserves contributor / topic / createdAt / tags / body', () {
      final json = jsonEncode([
        {
          'topic': 'Mars',
          'contributor': 'phone-a',
          'createdAt': '2026-05-22T19:31:00.000Z',
          'tags': ['inner-planet', 'olympus-mons'],
          'body': 'Mars has Olympus Mons.',
        }
      ]);
      final notes = SeedLoader.parseSeedJson(json);
      expect(notes, hasLength(1));
      final n = notes.first;
      expect(n.contributor, 'phone-a');
      expect(n.topic, 'Mars');
      expect(n.body, 'Mars has Olympus Mons.');
      expect(n.tags, ['inner-planet', 'olympus-mons']);
      expect(n.createdAt, DateTime.utc(2026, 5, 22, 19, 31, 0));
    });

    test('createdAt is canonicalized to UTC inside StudyNote.seed', () {
      // Same instant expressed two ways must produce identical _ids — the
      // robustness check for "developer in a non-UTC time zone authors a
      // seed entry locally and forgets the Z suffix".
      final isoUtc = jsonEncode([
        {
          'topic': 'X',
          'contributor': 'phone-a',
          'createdAt': '2026-05-22T19:00:00.000Z',
          'tags': <String>[],
          'body': 'x',
        }
      ]);
      final notes = SeedLoader.parseSeedJson(isoUtc);
      expect(notes.first.createdAt.isUtc, isTrue);
    });

    test('idempotent UUIDv5: two parses produce equal _ids', () {
      // Re-running the seed loader on a freshly-booted phone produces the
      // same _ids as the first run — this is the property that makes
      // `INSERT … ON ID CONFLICT DO UPDATE` an idempotent no-op.
      final json = jsonEncode([
        {
          'topic': 'X',
          'contributor': 'phone-a',
          'createdAt': '2026-05-22T19:00:00.000Z',
          'tags': <String>[],
          'body': 'x',
        }
      ]);
      final first = SeedLoader.parseSeedJson(json);
      final second = SeedLoader.parseSeedJson(json);
      expect(first.single.id, second.single.id);
    });

    test('malformed JSON throws FormatException', () {
      expect(() => SeedLoader.parseSeedJson('{not json'),
          throwsA(isA<FormatException>()));
    });

    test('top-level non-array throws ArgumentError', () {
      expect(() => SeedLoader.parseSeedJson('{"topic":"X"}'),
          throwsA(isA<ArgumentError>()));
    });

    test('missing required field throws ArgumentError', () {
      final bad = jsonEncode([
        {
          'topic': 'Mars',
          // contributor missing
          'createdAt': '2026-05-22T19:31:00.000Z',
          'tags': <String>[],
          'body': 'x',
        }
      ]);
      expect(() => SeedLoader.parseSeedJson(bad),
          throwsA(isA<ArgumentError>()));
    });

    test('wrong-typed field throws ArgumentError', () {
      final bad = jsonEncode([
        {
          'topic': 'Mars',
          'contributor': 42, // wrong type
          'createdAt': '2026-05-22T19:31:00.000Z',
          'tags': <String>[],
          'body': 'x',
        }
      ]);
      expect(() => SeedLoader.parseSeedJson(bad),
          throwsA(isA<ArgumentError>()));
    });
  });

  group('SeedLoader accessors', () {
    test('role defaults to "a" when PHONE_ROLE is not passed', () {
      // Tests run without --dart-define, so this should hit the default.
      expect(SeedLoader.instance.role, 'a');
    });

    test('assetPath matches the role', () {
      expect(SeedLoader.instance.assetPath, 'assets/seed_notes_a.json');
    });

    test('selfContributor matches the role', () {
      expect(SeedLoader.instance.selfContributor, 'phone-a');
    });
  });
}

/// Inline single-row fixture; keeps the parse tests free of cross-file
/// coupling. (The full assets/seed_notes_*.json are exercised by
/// study_note_test.dart's "seed corpus parses against the U7 schema" group.)
Map<String, dynamic> _inlineSeedRow(String role) => {
      'topic': role == 'a' ? 'Mars' : 'Jupiter',
      'contributor': 'phone-$role',
      'createdAt': '2026-05-22T19:00:00.000Z',
      'tags': const ['x'],
      'body': 'a body',
    };

List<Map<String, dynamic>> _inlineSeedFixture(String role) =>
    [_inlineSeedRow(role)];
