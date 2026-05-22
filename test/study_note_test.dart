import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_rag_demo/models/study_note.dart';

void main() {
  group('StudyNote', () {
    test('seed UUID is deterministic across re-runs', () {
      final t = DateTime.parse('2026-05-21T00:00:01Z');
      final a = StudyNote.seed(
        topic: 'the solar system',
        contributor: 'phone-a',
        body: 'the sun is a yellow dwarf star',
        tags: const ['sun'],
        createdAt: t,
      );
      final b = StudyNote.seed(
        topic: 'the solar system',
        contributor: 'phone-a',
        body: 'the sun is a yellow dwarf star',
        tags: const ['sun'],
        createdAt: t,
      );
      expect(a.id, equals(b.id), reason: 'same (contributor, topic, createdAt) → same UUID');
    });

    test('seed UUID differs for different contributors', () {
      final t = DateTime.parse('2026-05-21T00:00:01Z');
      final a = StudyNote.seed(
        topic: 'the solar system',
        contributor: 'phone-a',
        body: 'x',
        tags: const [],
        createdAt: t,
      );
      final b = StudyNote.seed(
        topic: 'the solar system',
        contributor: 'phone-b',
        body: 'x',
        tags: const [],
        createdAt: t,
      );
      expect(a.id, isNot(equals(b.id)));
    });

    test('round-trips through Ditto doc shape', () {
      final original = StudyNote.seed(
        topic: 'the solar system',
        contributor: 'phone-a',
        body: 'Saturn has rings made of water ice and rock.',
        tags: const ['saturn', 'rings'],
        createdAt: DateTime.parse('2026-05-21T00:00:01Z'),
      ).copyWith(embedding: const [0.1, -0.2, 0.3]);

      final doc = original.toDittoDoc();
      final restored = StudyNote.fromDittoValue(doc);

      expect(restored.id, equals(original.id));
      expect(restored.topic, equals(original.topic));
      expect(restored.contributor, equals(original.contributor));
      expect(restored.body, equals(original.body));
      expect(restored.tags, equals(original.tags));
      expect(restored.embedding, equals(original.embedding));
      expect(restored.createdAt, equals(original.createdAt));
    });

    test('hasEmbedding flips after copyWith', () {
      final t = DateTime.parse('2026-05-21T00:00:01Z');
      final empty = StudyNote.seed(
        topic: 'x',
        contributor: 'p',
        body: 'b',
        tags: const [],
        createdAt: t,
      );
      expect(empty.hasEmbedding, isFalse);
      final filled = empty.copyWith(embedding: const [0.5]);
      expect(filled.hasEmbedding, isTrue);
    });

    test('absent tags field in Ditto doc round-trips to empty list', () {
      final partialDoc = {
        '_id': 'abc',
        'topic': 't',
        'contributor': 'p',
        'body': 'b',
        'embedding': const <double>[],
        'createdAt': '2026-05-21T00:00:01Z',
      };
      final restored = StudyNote.fromDittoValue(partialDoc);
      expect(restored.tags, isEmpty);
    });

    test('absent originalNoteId/Contributor round-trip to empty strings', () {
      final doc = {
        '_id': 'abc',
        'topic': 't',
        'contributor': 'p',
        'body': 'b',
        'embedding': const <double>[],
        'createdAt': '2026-05-21T00:00:01Z',
      };
      final restored = StudyNote.fromDittoValue(doc);
      expect(restored.originalNoteId, isEmpty);
      expect(restored.originalContributor, isEmpty);
      expect(restored.isCloned, isFalse);
    });
  });

  group('StudyNote.cloneFrom', () {
    final peer = StudyNote.seed(
      topic: 'the solar system',
      contributor: 'phone-b',
      body: 'Uranus and Neptune are ice giants.',
      tags: const ['ice-giants'],
      createdAt: DateTime.parse('2026-05-21T00:00:11Z'),
    );

    test('clone preserves peer body and tags by default', () {
      final clone = StudyNote.cloneFrom(peer: peer, myContributor: 'phone-a');
      expect(clone.body, equals(peer.body));
      expect(clone.tags, equals(peer.tags));
      expect(clone.topic, equals(peer.topic));
    });

    test('clone is owned by me (contributor + provenance fields)', () {
      final clone = StudyNote.cloneFrom(peer: peer, myContributor: 'phone-a');
      expect(clone.contributor, equals('phone-a'));
      expect(clone.originalNoteId, equals(peer.id));
      expect(clone.originalContributor, equals('phone-b'));
      expect(clone.isCloned, isTrue);
    });

    test('clone id is deterministic — cloning twice is a no-op for upsert', () {
      final a = StudyNote.cloneFrom(peer: peer, myContributor: 'phone-a');
      final b = StudyNote.cloneFrom(peer: peer, myContributor: 'phone-a');
      expect(a.id, equals(b.id));
    });

    test('different cloners produce different ids for the same peer note',
        () {
      final a = StudyNote.cloneFrom(peer: peer, myContributor: 'phone-a');
      final c = StudyNote.cloneFrom(peer: peer, myContributor: 'phone-c');
      expect(a.id, isNot(equals(c.id)));
    });

    test('clone id differs from peer id', () {
      final clone = StudyNote.cloneFrom(peer: peer, myContributor: 'phone-a');
      expect(clone.id, isNot(equals(peer.id)));
    });

    test('body override edits the clone without touching the peer', () {
      final clone = StudyNote.cloneFrom(
        peer: peer,
        myContributor: 'phone-a',
        body: 'My corrected version: Uranus rotates on its side.',
      );
      expect(clone.body, contains('My corrected version'));
      expect(peer.body, isNot(contains('My corrected version')));
      // Same id even when body is overridden — semantics: "this is my edit
      // of peer.id" regardless of body content.
      final pristine =
          StudyNote.cloneFrom(peer: peer, myContributor: 'phone-a');
      expect(clone.id, equals(pristine.id));
    });

    test('clone round-trips originalNoteId/Contributor through Ditto', () {
      final clone = StudyNote.cloneFrom(peer: peer, myContributor: 'phone-a');
      final doc = clone.toDittoDoc();
      final restored = StudyNote.fromDittoValue(doc);
      expect(restored.originalNoteId, equals(peer.id));
      expect(restored.originalContributor, equals('phone-b'));
      expect(restored.isCloned, isTrue);
    });
  });
}
