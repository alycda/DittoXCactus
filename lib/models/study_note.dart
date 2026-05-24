/// Canonical study-note shape — the unit the demo syncs as a G-Set CRDT.
///
/// The notes collection IS the load-bearing claim of the demo (mesh-RAG with
/// vector index as a grow-only set), so this file's invariants matter:
///
/// 1. `_id` is content-addressed (UUIDv5 over
///    `'<contributor>|<topic>|<createdAt-iso8601>'`). Same inputs on any
///    device, any run → same `_id`. The seed loader (U8) re-runs are no-ops
///    by Ditto's `ON ID CONFLICT DO UPDATE` semantics.
/// 2. UUIDv5 strings are lex-comparable, which the cosine tie-break in U9's
///    `topK` depends on (R2 + R3 invariants).
/// 3. `acceptedBy` is an application-layer OR-Set: idempotent add/remove,
///    duplicates deduped on read. The UI's long-press "accept peer note"
///    flow (U10) writes through `withAcceptedBy`.
/// 4. `embedding` is `List<double>` on disk and converted to `Float32List`
///    on the cosine hot path (U9). Length mismatches are dropped at the
///    `topK` boundary, not raised — silent guard against a model swap.
///
/// References:
/// - `_docs/research/index/_per_source/article-ditto-blog-dittos-delta-state-crdts.md`
///   (Ditto's delta-state CRDT model + HLC-tagged trees)
/// - `_docs/research/index/_per_source/paper-1106.4374.md`
///   (Shapiro et al., G-Set foundations)
library mesh_rag.models.study_note;

import 'package:uuid/uuid.dart';

/// Project-specific UUIDv5 namespace. Frozen here so the seeded `_id`s are
/// stable across machines + the U13 baseline.json comparison still holds
/// if a future agent rebuilds the seed corpus from `assets/seed_notes_*.json`.
/// Random v4 generated 2026-05-23 and pinned.
const String _meshRagNamespace = '7c2b8e4a-3d5f-4b2c-8e6d-1a4f9e8c7b30';

const Uuid _uuid = Uuid();

class StudyNote {
  /// UUIDv5 over `'<contributor>|<topic>|<createdAt-iso8601>'`. Lex-asc
  /// comparable; required by U9's tie-break invariant.
  final String id;
  final String topic;

  /// Author-device identifier (`phone-a` / `phone-b` for the demo). Doubles
  /// as the OR-Set element when this device accepts a peer's note.
  final String contributor;
  final String body;
  final List<String> tags;

  /// `[]` until backfilled by U8's `ensureEmbeddings`. U9's `topK` skips
  /// rows whose `embedding.length` differs from the query embedding's.
  final List<double> embedding;
  final DateTime createdAt;

  /// OR-Set of contributors who have accepted this note locally. Sorted +
  /// deduplicated on read so two replicas that converge to the same set
  /// produce a bitwise-identical serialization.
  final List<String> acceptedBy;

  /// `cloneFrom` provenance — empty by default. Carried so any document
  /// the fork-clone predecessor authored (before the OR-Set landed)
  /// still round-trips through `fromDittoValue` without losing fields.
  final String originalNoteId;
  final String originalContributor;

  const StudyNote({
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

  bool get hasEmbedding => embedding.isNotEmpty;

  /// UTC ISO-8601 (the value the UUIDv5 namespace was derived against). Use
  /// this when serializing — never `createdAt.toIso8601String()` directly,
  /// which would emit local-time strings on devices in non-UTC time zones
  /// and break re-derivation of `_id`.
  String get createdAtIso => createdAt.toUtc().toIso8601String();

  /// Idempotent seed factory. Same `(contributor, topic, createdAt)` →
  /// bitwise-identical `_id` on every machine, every run.
  ///
  /// `createdAt` is canonicalized to UTC before the UUIDv5 input is built so
  /// devices in different time zones still produce the same id.
  factory StudyNote.seed({
    required String contributor,
    required String topic,
    required DateTime createdAt,
    required List<String> tags,
    required String body,
    List<double> embedding = const [],
    List<String> acceptedBy = const [],
    String originalNoteId = '',
    String originalContributor = '',
  }) {
    final isoUtc = createdAt.toUtc().toIso8601String();
    final id = _uuid.v5(_meshRagNamespace, '$contributor|$topic|$isoUtc');
    return StudyNote(
      id: id,
      topic: topic,
      contributor: contributor,
      body: body,
      tags: List<String>.unmodifiable(tags),
      embedding: List<double>.unmodifiable(embedding),
      createdAt: createdAt.toUtc(),
      acceptedBy: _dedupedSorted(acceptedBy),
      originalNoteId: originalNoteId,
      originalContributor: originalContributor,
    );
  }

  /// Parse a Ditto document value back into a [StudyNote]. Tolerant of
  /// legacy documents (`acceptedBy` / `originalNoteId` /
  /// `originalContributor` missing → defaults). Dedupes `acceptedBy`
  /// defensively in case two replicas raced on add.
  factory StudyNote.fromDittoValue(Map<String, dynamic> value) {
    final tags =
        ((value['tags'] as List?) ?? const []).map((v) => v as String).toList();
    final embedding = ((value['embedding'] as List?) ?? const [])
        .map((v) => (v as num).toDouble())
        .toList();
    final acceptedRaw = ((value['acceptedBy'] as List?) ?? const [])
        .map((v) => v as String)
        .toList();
    return StudyNote(
      id: value['_id'] as String,
      topic: value['topic'] as String,
      contributor: value['contributor'] as String,
      body: value['body'] as String,
      tags: List<String>.unmodifiable(tags),
      embedding: List<double>.unmodifiable(embedding),
      createdAt: DateTime.parse(value['createdAt'] as String).toUtc(),
      acceptedBy: _dedupedSorted(acceptedRaw),
      originalNoteId: (value['originalNoteId'] as String?) ?? '',
      originalContributor: (value['originalContributor'] as String?) ?? '',
    );
  }

  /// Serialize for `DittoService.upsertNote` → DQL
  /// `INSERT INTO notes DOCUMENTS (:doc) ON ID CONFLICT DO UPDATE`.
  ///
  /// Keys match the column names retrieved by `fromDittoValue` — round-trip
  /// preservation is a tested invariant.
  Map<String, dynamic> toDittoDoc() => {
        '_id': id,
        'topic': topic,
        'contributor': contributor,
        'body': body,
        'tags': tags,
        'embedding': embedding,
        'createdAt': createdAtIso,
        'acceptedBy': acceptedBy,
        'originalNoteId': originalNoteId,
        'originalContributor': originalContributor,
      };

  StudyNote copyWith({
    String? id,
    String? topic,
    String? contributor,
    String? body,
    List<String>? tags,
    List<double>? embedding,
    DateTime? createdAt,
    List<String>? acceptedBy,
    String? originalNoteId,
    String? originalContributor,
  }) {
    return StudyNote(
      id: id ?? this.id,
      topic: topic ?? this.topic,
      contributor: contributor ?? this.contributor,
      body: body ?? this.body,
      tags: tags == null ? this.tags : List<String>.unmodifiable(tags),
      embedding: embedding == null
          ? this.embedding
          : List<double>.unmodifiable(embedding),
      createdAt: createdAt ?? this.createdAt,
      acceptedBy:
          acceptedBy == null ? this.acceptedBy : _dedupedSorted(acceptedBy),
      originalNoteId: originalNoteId ?? this.originalNoteId,
      originalContributor: originalContributor ?? this.originalContributor,
    );
  }

  /// Lift this note with a freshly-computed embedding. `[]` clears.
  StudyNote withEmbedding(List<double> nextEmbedding) =>
      copyWith(embedding: nextEmbedding);

  /// OR-Set add: returns `this` unchanged when `contributor` is already in
  /// the set (idempotent).
  StudyNote withAcceptedBy(String contributor) {
    if (acceptedBy.contains(contributor)) return this;
    final next = [...acceptedBy, contributor];
    return copyWith(acceptedBy: next);
  }

  /// OR-Set remove: returns `this` unchanged when `contributor` is not in
  /// the set (idempotent).
  StudyNote withoutAcceptedBy(String contributor) {
    if (!acceptedBy.contains(contributor)) return this;
    final next = acceptedBy.where((c) => c != contributor).toList();
    return copyWith(acceptedBy: next);
  }

  /// Carry-forward for the fork-clone authoring path. New code prefers
  /// `withAcceptedBy` (the OR-Set semantics), but `cloneFrom` keeps the
  /// shape working for any legacy document that still references it.
  ///
  /// Generates a fresh `_id` (UUIDv5 over the new contributor + same topic
  /// + new createdAt) and tags the result with `original{NoteId,
  /// Contributor}` so the lineage isn't lost.
  factory StudyNote.cloneFrom(
    StudyNote source, {
    required String forContributor,
    DateTime? createdAt,
  }) {
    final ts = (createdAt ?? DateTime.now()).toUtc();
    return StudyNote.seed(
      contributor: forContributor,
      topic: source.topic,
      createdAt: ts,
      tags: source.tags,
      body: source.body,
      originalNoteId: source.id,
      originalContributor: source.contributor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StudyNote) return false;
    return id == other.id &&
        topic == other.topic &&
        contributor == other.contributor &&
        body == other.body &&
        _listEq(tags, other.tags) &&
        _listEq(embedding, other.embedding) &&
        createdAt == other.createdAt &&
        _listEq(acceptedBy, other.acceptedBy) &&
        originalNoteId == other.originalNoteId &&
        originalContributor == other.originalContributor;
  }

  @override
  int get hashCode => Object.hash(
        id,
        topic,
        contributor,
        body,
        Object.hashAll(tags),
        Object.hashAll(embedding),
        createdAt,
        Object.hashAll(acceptedBy),
        originalNoteId,
        originalContributor,
      );

  @override
  String toString() =>
      'StudyNote(id: $id, topic: $topic, contributor: $contributor, '
      'hasEmbedding: $hasEmbedding, acceptedBy: $acceptedBy)';
}

List<String> _dedupedSorted(List<String> xs) {
  final set = <String>{...xs};
  final out = set.toList()..sort();
  return List<String>.unmodifiable(out);
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
