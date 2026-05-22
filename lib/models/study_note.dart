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

  /// If this note was cloned from a peer's note via `StudyNote.cloneFrom`,
  /// these track the source. Empty for native notes. Cloned notes are
  /// independent Ditto documents — editing this clone does NOT update the
  /// peer's original. That intentional split is why we have "clone" rather
  /// than pure CRDT auto-merge for the trust/sourcing thesis.
  final String originalNoteId;
  final String originalContributor;

  StudyNote({
    required this.id,
    required this.topic,
    required this.contributor,
    required this.body,
    required this.tags,
    required this.embedding,
    required this.createdAt,
    this.originalNoteId = '',
    this.originalContributor = '',
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

  /// Create a local copy of a peer's note under the caller's contributor.
  ///
  /// The clone's id is UUIDv5 over `(myContributor, peer.id)` so cloning the
  /// same peer note twice is a no-op (Ditto upsert sees the same id). The
  /// clone preserves the peer's topic, body, and tags by default; the user
  /// can then edit it without touching the peer's original document. The
  /// clone IS a normal Ditto-synced note — it appears on every peer's
  /// device with `originalNoteId` set so any UI can render a "this is a
  /// clone of …" badge or, later, surface a merge-back proposal.
  factory StudyNote.cloneFrom({
    required StudyNote peer,
    required String myContributor,
    String? body,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    final id = const Uuid().v5(
      Namespace.oid.value,
      'clone|$myContributor|${peer.id}',
    );
    return StudyNote(
      id: id,
      topic: peer.topic,
      contributor: myContributor,
      body: body ?? peer.body,
      tags: tags ?? List<String>.from(peer.tags),
      embedding: const [],
      createdAt: createdAt ?? DateTime.now(),
      originalNoteId: peer.id,
      originalContributor: peer.contributor,
    );
  }

  bool get isCloned => originalNoteId.isNotEmpty;

  Map<String, dynamic> toDittoDoc() => {
        '_id': id,
        'topic': topic,
        'contributor': contributor,
        'body': body,
        'tags': tags,
        'embedding': embedding,
        'createdAt': createdAt.toIso8601String(),
        'originalNoteId': originalNoteId,
        'originalContributor': originalContributor,
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
      originalNoteId: v['originalNoteId']?.toString() ?? '',
      originalContributor: v['originalContributor']?.toString() ?? '',
    );
  }

  StudyNote copyWith({List<double>? embedding, String? body}) => StudyNote(
        id: id,
        topic: topic,
        contributor: contributor,
        body: body ?? this.body,
        tags: tags,
        embedding: embedding ?? this.embedding,
        createdAt: createdAt,
        originalNoteId: originalNoteId,
        originalContributor: originalContributor,
      );

  bool get hasEmbedding => embedding.isNotEmpty;
}
