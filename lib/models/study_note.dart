import 'package:uuid/uuid.dart';

/// A single study-note document in the Ditto `notes` collection.
///
/// `embedding` is filled lazily by `RetrievalService.ensureEmbeddings()` on
/// first launch; it can be empty for freshly-inserted notes.
class StudyNote {
  final String id;
  final String topic;
  final String contributor;
  final String body;
  final List<String> tags;
  final List<double> embedding;
  final DateTime createdAt;

  StudyNote({
    required this.id,
    required this.topic,
    required this.contributor,
    required this.body,
    required this.tags,
    required this.embedding,
    required this.createdAt,
  });

  /// UUIDv5 over `(contributor, topic, createdAt)` so re-running the seed
  /// loader is a no-op (Ditto's `ON ID CONFLICT DO UPDATE` finishes the job).
  factory StudyNote.seed({
    required String topic,
    required String contributor,
    required String body,
    required List<String> tags,
    required DateTime createdAt,
  }) {
    final id = const Uuid().v5(
      Namespace.oid.value,
      '$contributor|$topic|${createdAt.toIso8601String()}',
    );
    return StudyNote(
      id: id,
      topic: topic,
      contributor: contributor,
      body: body,
      tags: tags,
      embedding: const [],
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toDittoDoc() => {
        '_id': id,
        'topic': topic,
        'contributor': contributor,
        'body': body,
        'tags': tags,
        'embedding': embedding,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StudyNote.fromDittoValue(Map<String, dynamic> v) {
    return StudyNote(
      id: v['_id'].toString(),
      topic: v['topic'].toString(),
      contributor: v['contributor'].toString(),
      body: v['body'].toString(),
      tags: (v['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      embedding: (v['embedding'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [],
      createdAt: DateTime.parse(v['createdAt'].toString()),
    );
  }

  StudyNote copyWith({List<double>? embedding}) => StudyNote(
        id: id,
        topic: topic,
        contributor: contributor,
        body: body,
        tags: tags,
        embedding: embedding ?? this.embedding,
        createdAt: createdAt,
      );

  bool get hasEmbedding => embedding.isNotEmpty;
}
