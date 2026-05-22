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
  });
}
