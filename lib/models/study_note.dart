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

  /// Set of contributors who have "saved" / accepted this note into their
  /// retrieval set. Mesh-wide consensus is reached via Ditto CRDT — when
  /// peer-a accepts peer-b's note, peer-a adds itself to acceptedBy, the
  /// add propagates, and now peer-b sees "saved by 1 peer" on their
  /// original document. There is NO new document — same _id, shared.
  ///
  /// Set semantics implemented at the application layer (dedup on insert).
  /// Ditto's underlying field is a list; we treat it as an OR-Set.
  final List<String> acceptedBy;

  /// Legacy: set on documents created by the older fork-clone flow before
  /// we moved to acceptance semantics. Newly-created notes do not populate
  /// these fields. Round-tripped for backward compatibility with existing
  /// Ditto data; UI hides clone-style displays.
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
    this.acceptedBy = const [],
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

  /// Idempotent OR-Set add. Returns a new note with `contributor` added to
  /// `acceptedBy` if not already present, otherwise returns `this` unchanged.
  /// The caller then upserts the returned note to Ditto, which propagates the
  /// acceptance to every replica via CRDT merge.
  StudyNote withAcceptedBy(String contributor) {
    if (acceptedBy.contains(contributor)) return this;
    return copyWith(
      acceptedBy: List<String>.unmodifiable([...acceptedBy, contributor]),
    );
  }

  /// Idempotent OR-Set remove (un-accept). Returns `this` unchanged if the
  /// contributor wasn't accepting this note.
  StudyNote withoutAcceptedBy(String contributor) {
    if (!acceptedBy.contains(contributor)) return this;
    return copyWith(
      acceptedBy: List<String>.unmodifiable(
        acceptedBy.where((c) => c != contributor),
      ),
    );
  }

  bool isAcceptedBy(String contributor) => acceptedBy.contains(contributor);

  Map<String, dynamic> toDittoDoc() => {
        '_id': id,
        'topic': topic,
        'contributor': contributor,
        'body': body,
        'tags': tags,
        'embedding': embedding,
        'createdAt': createdAt.toIso8601String(),
        'acceptedBy': acceptedBy,
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
      acceptedBy: (v['acceptedBy'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toSet() // dedup defensively in case multiple replicas raced
              .toList() ??
          const [],
      originalNoteId: v['originalNoteId']?.toString() ?? '',
      originalContributor: v['originalContributor']?.toString() ?? '',
    );
  }

  StudyNote copyWith({
    List<double>? embedding,
    String? body,
    List<String>? acceptedBy,
  }) =>
      StudyNote(
        id: id,
        topic: topic,
        contributor: contributor,
        body: body ?? this.body,
        tags: tags,
        embedding: embedding ?? this.embedding,
        createdAt: createdAt,
        acceptedBy: acceptedBy ?? this.acceptedBy,
        originalNoteId: originalNoteId,
        originalContributor: originalContributor,
      );

  bool get hasEmbedding => embedding.isNotEmpty;
}
