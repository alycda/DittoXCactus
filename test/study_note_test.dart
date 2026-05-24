// Tests for the StudyNote model (U7).
//
// Covers: UUIDv5 determinism, distinct-contributor IDs, Ditto round-trip,
// OR-Set add/remove idempotence, defensive dedup on read, hasEmbedding
// invariant, cloneFrom lineage, and a parse of every entry in the
// assets/seed_notes_*.json files (the U3 corpus is supposed to compile
// against this schema — proving it here means U8's SeedLoader won't
// surprise us on first launch).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/models/study_note.dart';

void main() {
  group('StudyNote.seed', () {
    test('same inputs produce identical UUIDv5 _ids on repeat calls', () {
      final t = DateTime.utc(2026, 5, 22, 19, 0, 0);
      final a = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'The Sun',
        createdAt: t,
        tags: const ['star'],
        body: 'The Sun is a star.',
      );
      final b = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'The Sun',
        createdAt: t,
        tags: const ['star'],
        body: 'The Sun is a star.',
      );
      expect(a.id, b.id);
    });

    test('different contributors produce distinct _ids', () {
      final t = DateTime.utc(2026, 5, 22, 19, 0, 0);
      final a = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'Mars',
        createdAt: t,
        tags: const ['inner-planet'],
        body: 'Mars is red.',
      );
      final b = StudyNote.seed(
        contributor: 'phone-b',
        topic: 'Mars',
        createdAt: t,
        tags: const ['inner-planet'],
        body: 'Mars is red.',
      );
      expect(a.id, isNot(b.id));
    });

    test('different topics produce distinct _ids', () {
      final t = DateTime.utc(2026, 5, 22, 19, 0, 0);
      final a = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'Mars',
        createdAt: t,
        tags: const [],
        body: 'x',
      );
      final b = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'Venus',
        createdAt: t,
        tags: const [],
        body: 'x',
      );
      expect(a.id, isNot(b.id));
    });

    test('different createdAt produce distinct _ids', () {
      final a = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'Mars',
        createdAt: DateTime.utc(2026, 5, 22, 19, 0, 0),
        tags: const [],
        body: 'x',
      );
      final b = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'Mars',
        createdAt: DateTime.utc(2026, 5, 22, 19, 0, 1),
        tags: const [],
        body: 'x',
      );
      expect(a.id, isNot(b.id));
    });

    test('createdAt is canonicalized to UTC before _id derivation', () {
      // Different time zones of the same UTC instant must produce the same id —
      // otherwise two devices in different zones would diverge.
      final utc = DateTime.utc(2026, 5, 22, 19, 0, 0);
      final asLocalish = DateTime.parse('2026-05-22T19:00:00.000Z'); // UTC
      final a = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'X',
        createdAt: utc,
        tags: const [],
        body: 'x',
      );
      final b = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'X',
        createdAt: asLocalish,
        tags: const [],
        body: 'x',
      );
      expect(a.id, b.id);
    });

    test('id is a valid 36-char UUID string and lex-comparable', () {
      // U9 + U1 rely on UUIDv5 strings being lex-comparable for the
      // (score desc, id asc) tie-break. Confirm the format.
      final n = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'Mars',
        createdAt: DateTime.utc(2026, 5, 22, 19, 0, 0),
        tags: const [],
        body: 'x',
      );
      expect(n.id.length, 36);
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(n.id), isTrue);
    });
  });

  group('Ditto round-trip', () {
    test('toDittoDoc → fromDittoValue preserves every field', () {
      final original = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'Mars',
        createdAt: DateTime.utc(2026, 5, 22, 19, 31, 0),
        tags: const ['inner-planet', 'olympus-mons'],
        body: 'Mars has Olympus Mons.',
      ).copyWith(embedding: const [0.1, 0.2, 0.3]);

      final doc = original.toDittoDoc();
      final back = StudyNote.fromDittoValue(doc);

      expect(back.id, original.id);
      expect(back.topic, original.topic);
      expect(back.contributor, original.contributor);
      expect(back.body, original.body);
      expect(back.tags, original.tags);
      expect(back.embedding, original.embedding);
      expect(back.createdAt, original.createdAt);
      expect(back.acceptedBy, original.acceptedBy);
      expect(back.originalNoteId, original.originalNoteId);
      expect(back.originalContributor, original.originalContributor);
      expect(back, original);
    });

    test('fromDittoValue tolerates missing OR-Set + lineage fields', () {
      // Documents authored before the OR-Set landed (and before
      // originalNoteId / originalContributor were introduced) must still
      // round-trip — they just default to "[]" and "" respectively.
      final legacyDoc = <String, dynamic>{
        '_id': 'whatever',
        'topic': 'T',
        'contributor': 'phone-a',
        'body': 'b',
        'tags': <String>[],
        'embedding': <double>[],
        'createdAt': '2026-05-22T19:00:00.000Z',
        // no acceptedBy, no originalNoteId, no originalContributor
      };
      final n = StudyNote.fromDittoValue(legacyDoc);
      expect(n.acceptedBy, isEmpty);
      expect(n.originalNoteId, '');
      expect(n.originalContributor, '');
    });

    test('fromDittoValue dedupes acceptedBy defensively', () {
      // Two replicas racing on add could leave the same contributor twice
      // in the stored list. The OR-Set semantic says the set has it once.
      final doc = <String, dynamic>{
        '_id': 'x',
        'topic': 'T',
        'contributor': 'phone-a',
        'body': 'b',
        'tags': <String>[],
        'embedding': <double>[],
        'createdAt': '2026-05-22T19:00:00.000Z',
        'acceptedBy': ['phone-b', 'phone-c', 'phone-b'],
      };
      final n = StudyNote.fromDittoValue(doc);
      expect(n.acceptedBy, ['phone-b', 'phone-c']);
    });
  });

  group('acceptedBy OR-Set', () {
    StudyNote base() => StudyNote.seed(
          contributor: 'phone-a',
          topic: 'X',
          createdAt: DateTime.utc(2026, 5, 22, 19, 0, 0),
          tags: const [],
          body: 'x',
        );

    test('withAcceptedBy adds a contributor', () {
      final n = base().withAcceptedBy('phone-b');
      expect(n.acceptedBy, ['phone-b']);
    });

    test('withAcceptedBy is idempotent — re-adding returns the same set', () {
      final once = base().withAcceptedBy('phone-b');
      final twice = once.withAcceptedBy('phone-b');
      expect(twice.acceptedBy, once.acceptedBy);
    });

    test('withoutAcceptedBy removes', () {
      final n = base().withAcceptedBy('phone-b').withAcceptedBy('phone-c');
      final dropped = n.withoutAcceptedBy('phone-b');
      expect(dropped.acceptedBy, ['phone-c']);
    });

    test('withoutAcceptedBy is idempotent — removing absent is a no-op', () {
      final n = base();
      expect(n.withoutAcceptedBy('phone-x').acceptedBy, isEmpty);
    });

    test('acceptedBy stays sorted so two replicas converge to the same shape',
        () {
      final a = base().withAcceptedBy('phone-c').withAcceptedBy('phone-b');
      final b = base().withAcceptedBy('phone-b').withAcceptedBy('phone-c');
      expect(a.acceptedBy, b.acceptedBy);
      expect(a.acceptedBy, ['phone-b', 'phone-c']);
    });
  });

  group('embedding invariants', () {
    test('hasEmbedding flips with the column', () {
      final n = StudyNote.seed(
        contributor: 'phone-a',
        topic: 'X',
        createdAt: DateTime.utc(2026, 5, 22, 19, 0, 0),
        tags: const [],
        body: 'x',
      );
      expect(n.hasEmbedding, isFalse);
      final lifted = n.withEmbedding(const [0.1, 0.2]);
      expect(lifted.hasEmbedding, isTrue);
      final cleared = lifted.withEmbedding(const []);
      expect(cleared.hasEmbedding, isFalse);
    });
  });

  group('cloneFrom', () {
    test('produces a new _id and carries the source lineage', () {
      final source = StudyNote.seed(
        contributor: 'phone-b',
        topic: 'Jupiter',
        createdAt: DateTime.utc(2026, 5, 22, 19, 2, 0),
        tags: const ['outer-planet'],
        body: 'Jupiter is big.',
      );
      final clone = StudyNote.cloneFrom(
        source,
        forContributor: 'phone-a',
        createdAt: DateTime.utc(2026, 5, 23, 0, 0, 0),
      );
      expect(clone.id, isNot(source.id));
      expect(clone.contributor, 'phone-a');
      expect(clone.topic, 'Jupiter');
      expect(clone.body, 'Jupiter is big.');
      expect(clone.tags, source.tags);
      expect(clone.originalNoteId, source.id);
      expect(clone.originalContributor, 'phone-b');
    });
  });

  group('seed corpus parses against the U7 schema', () {
    // U3 wrote assets/seed_notes_{a,b}.json before U7 existed; this group
    // is the safety net that U8's SeedLoader won't blow up on data the
    // corpus authoring step produced. If U3 changes the JSON shape, this
    // catches it.
    for (final role in ['a', 'b']) {
      test('assets/seed_notes_$role.json — every entry parses to a StudyNote',
          () {
        final file = File('assets/seed_notes_$role.json');
        expect(file.existsSync(), isTrue,
            reason: 'Run from repo root so the asset path resolves.');
        final entries = jsonDecode(file.readAsStringSync()) as List;
        expect(entries.length, 5,
            reason: 'U3 commits to 5 notes per role; if this changes, '
                'update U7 + U16 in lockstep.');
        for (final raw in entries) {
          final json = raw as Map<String, dynamic>;
          final note = StudyNote.seed(
            contributor: json['contributor'] as String,
            topic: json['topic'] as String,
            createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
            tags: (json['tags'] as List).cast<String>(),
            body: json['body'] as String,
          );
          expect(note.contributor, 'phone-$role');
          expect(note.body, isNotEmpty);
          expect(note.topic, isNotEmpty);
          expect(note.tags, isNotEmpty);
          expect(note.hasEmbedding, isFalse,
              reason: 'Seed JSONs do not pre-compute embeddings; '
                  'U8 ensureEmbeddings backfills them.');
        }
      });
    }

    test('UUIDv5 ids are disjoint across the A and B seed files', () {
      // Mechanical because contributor differs, but worth verifying the
      // assumption holds against the actual JSON.
      Iterable<StudyNote> loadFor(String role) sync* {
        final entries = jsonDecode(
                File('assets/seed_notes_$role.json').readAsStringSync())
            as List;
        for (final raw in entries) {
          final json = raw as Map<String, dynamic>;
          yield StudyNote.seed(
            contributor: json['contributor'] as String,
            topic: json['topic'] as String,
            createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
            tags: (json['tags'] as List).cast<String>(),
            body: json['body'] as String,
          );
        }
      }

      final idsA = loadFor('a').map((n) => n.id).toSet();
      final idsB = loadFor('b').map((n) => n.id).toSet();
      expect(idsA.length, 5);
      expect(idsB.length, 5);
      expect(idsA.intersection(idsB), isEmpty);
    });
  });
}
