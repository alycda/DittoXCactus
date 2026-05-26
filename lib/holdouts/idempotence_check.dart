/// Convergence + idempotence detection for **Holdouts 3 + 4 (R3 + R4)** —
/// the two holdouts that prove the mesh-RAG thesis end-to-end at the
/// CRDT layer:
///
/// > **R4 (bidirectional merge).** After two devices meet over BLE, both
/// > converge to the union of their corpora. Notes A had → visible on B,
/// > and vice versa.
///
/// > **R3 (sync idempotence).** Re-meeting with no edits in between
/// > produces *zero* observable change: same note set, same per-note
/// > content, same ordered top-k for any fixture query.
///
/// **This file is pure logic on snapshots.** It does not touch Ditto, BLE,
/// or any platform channel. The on-device runner (`tools/holdout_34/`)
/// captures snapshots from `DittoService.queryAll` at each holdout phase
/// and feeds them in here for the verdict. Keeping the math pure mirrors
/// the U14 (cold-load timer) and U1/U13 (determinism harness) pattern:
/// the holdout's verdict is a JSON-shaped report a CI step (or the
/// recorded artifact reviewer) can consume without re-running the
/// physical handshake.
///
/// ## Convergence semantics (R4)
///
/// Given pre-meet snapshots `A_pre`, `B_pre` and post-meet snapshots
/// `A_post`, `B_post`, the holdout passes when:
///
/// 1. `idSet(A_post) == idSet(B_post) == idSet(A_pre) ∪ idSet(B_pre)`
/// 2. For every shared id, `A_post[id] == B_post[id]` by [StudyNote]
///    structural equality (bitwise on the round-trippable fields —
///    `id, topic, contributor, body, tags, embedding, createdAt,
///    acceptedBy, originalNoteId, originalContributor`).
///
/// ## Idempotence semantics (R3)
///
/// Given a post-meet snapshot and a post-re-meet snapshot **with no
/// authoring in between** plus the ordered top-k for a fixture query
/// captured before and after the re-meet:
///
/// 1. `idSet(postRemeet) == idSet(postMeet)`
/// 2. For every id, `postRemeet[id] == postMeet[id]` by structural
///    equality.
/// 3. The ordered top-k id list for the fixture query is unchanged.
///    Any reorder, addition, or removal counts as drift.
///
/// Top-k stability is reported as `topKDriftCount` — the count of
/// positions where the ordered lists disagree. Zero = perfectly stable.
///
/// ## What this file does NOT verify
///
/// - **BLE handshake liveness.** That's an environmental precondition;
///   the runner waits for `DittoService.currentPeerCount == 1` before
///   capturing the post-meet snapshot.
/// - **Embedding determinism (R2).** Covered by the determinism harness
///   at `tools/determinism_harness/`. Here we trust the embedding column
///   as recorded.
/// - **Top-k correctness.** The fixture query's expected ordering is the
///   caller's concern (the U16 rehearsed-queries doc owns that
///   contract). This file only checks that the order is *stable* across
///   the re-meet.
library mesh_rag.holdouts.idempotence_check;

import '../models/study_note.dart';

/// R4 verdict: did both devices converge to the union of corpora?
class ConvergenceResult {
  /// True iff both devices have the full union AND shared ids have
  /// structurally-equal content on both sides.
  final bool pass;

  /// `|A_pre ∪ B_pre|` — the cardinality both devices should report.
  final int expectedUnionSize;
  final int actualASize;
  final int actualBSize;

  /// Ids that should have landed on A but didn't (sorted lex-asc).
  final List<String> missingFromA;
  final List<String> missingFromB;

  /// Ids that exist on both sides post-meet but with structurally
  /// different content (sorted lex-asc). A non-empty list is the
  /// CRDT-merge red flag: the union sizes can match while the bodies
  /// or embeddings disagree.
  final List<String> divergedIds;

  const ConvergenceResult({
    required this.pass,
    required this.expectedUnionSize,
    required this.actualASize,
    required this.actualBSize,
    required this.missingFromA,
    required this.missingFromB,
    required this.divergedIds,
  });

  Map<String, dynamic> toJson() => {
        'pass': pass,
        'expected_union_size': expectedUnionSize,
        'actual_a_size': actualASize,
        'actual_b_size': actualBSize,
        'missing_from_a': missingFromA,
        'missing_from_b': missingFromB,
        'diverged_ids': divergedIds,
      };
}

/// R3 verdict: did the re-meet preserve state bitwise + top-k stable?
class IdempotenceResult {
  final bool pass;

  /// Ids that appeared after the re-meet (should be empty for R3 PASS).
  final List<String> idsAdded;

  /// Ids that disappeared after the re-meet (should be empty).
  final List<String> idsRemoved;

  /// Ids present on both sides but with structurally different content
  /// post-vs-pre re-meet.
  final List<String> contentChangedIds;

  /// Number of positions where the ordered top-k id list disagrees.
  /// Zero = perfectly stable (R3 PASS for the top-k axis).
  final int topKDriftCount;

  /// Length of the top-k lists being compared. If they differ in
  /// length, `topKDriftCount` is at least `|len_a - len_b|` plus any
  /// position-wise disagreement up to the shared prefix length.
  final int topKLength;

  const IdempotenceResult({
    required this.pass,
    required this.idsAdded,
    required this.idsRemoved,
    required this.contentChangedIds,
    required this.topKDriftCount,
    required this.topKLength,
  });

  Map<String, dynamic> toJson() => {
        'pass': pass,
        'ids_added': idsAdded,
        'ids_removed': idsRemoved,
        'content_changed_ids': contentChangedIds,
        'topk_drift_count': topKDriftCount,
        'topk_length': topKLength,
      };
}

class IdempotenceCheck {
  IdempotenceCheck._();

  /// R4: union convergence check. Pure function over four snapshots.
  ///
  /// Both `postA` and `postB` must contain every id in
  /// `idSet(preA) ∪ idSet(preB)`, and any id present on both
  /// post-meet sides must carry structurally-equal content (full
  /// [StudyNote] equality).
  static ConvergenceResult detectConvergence({
    required List<StudyNote> preA,
    required List<StudyNote> preB,
    required List<StudyNote> postA,
    required List<StudyNote> postB,
  }) {
    final expectedUnion = <String>{
      ...preA.map((n) => n.id),
      ...preB.map((n) => n.id),
    };

    final aById = _index(postA);
    final bById = _index(postB);

    final missingFromA = expectedUnion.difference(aById.keys.toSet()).toList()
      ..sort();
    final missingFromB = expectedUnion.difference(bById.keys.toSet()).toList()
      ..sort();

    // For ids present on both post-meet sides, detect content
    // divergence (CRDT-merge sanity). We diff the intersection rather
    // than the expected union so that a "missing from A" id doesn't
    // *also* register as diverged.
    final sharedIds = aById.keys.toSet().intersection(bById.keys.toSet());
    final divergedIds = <String>[];
    for (final id in sharedIds) {
      if (aById[id] != bById[id]) {
        divergedIds.add(id);
      }
    }
    divergedIds.sort();

    final pass = missingFromA.isEmpty &&
        missingFromB.isEmpty &&
        divergedIds.isEmpty;

    return ConvergenceResult(
      pass: pass,
      expectedUnionSize: expectedUnion.length,
      actualASize: postA.length,
      actualBSize: postB.length,
      missingFromA: List.unmodifiable(missingFromA),
      missingFromB: List.unmodifiable(missingFromB),
      divergedIds: List.unmodifiable(divergedIds),
    );
  }

  /// R3: idempotence check on a single device, between post-meet and
  /// post-re-meet snapshots taken with *no authoring* in between.
  ///
  /// Three axes:
  ///   - id set: no adds, no removes
  ///   - per-id content: every shared id maps to structurally-equal
  ///     [StudyNote]
  ///   - top-k stability: caller supplies the ordered id list for a
  ///     fixture query before and after the re-meet; any reorder/add/
  ///     remove counts as drift
  ///
  /// The check passes when *all three* axes show zero change.
  static IdempotenceResult detectIdempotence({
    required List<StudyNote> postMeet,
    required List<StudyNote> postRemeet,
    required List<String> topKPreRemeet,
    required List<String> topKPostRemeet,
  }) {
    final pre = _index(postMeet);
    final post = _index(postRemeet);

    final preIds = pre.keys.toSet();
    final postIds = post.keys.toSet();

    final idsAdded = postIds.difference(preIds).toList()..sort();
    final idsRemoved = preIds.difference(postIds).toList()..sort();

    final contentChangedIds = <String>[];
    for (final id in preIds.intersection(postIds)) {
      if (pre[id] != post[id]) {
        contentChangedIds.add(id);
      }
    }
    contentChangedIds.sort();

    final driftCount = _orderedDiffCount(topKPreRemeet, topKPostRemeet);

    final pass = idsAdded.isEmpty &&
        idsRemoved.isEmpty &&
        contentChangedIds.isEmpty &&
        driftCount == 0;

    return IdempotenceResult(
      pass: pass,
      idsAdded: List.unmodifiable(idsAdded),
      idsRemoved: List.unmodifiable(idsRemoved),
      contentChangedIds: List.unmodifiable(contentChangedIds),
      topKDriftCount: driftCount,
      topKLength: topKPostRemeet.length,
    );
  }

  /// Convenience: roll the R3 + R4 verdict into one JSON-shaped report.
  /// The verdict CLI (`tools/holdout_34/verdict.dart`) emits exactly
  /// this shape.
  static Map<String, dynamic> buildReport({
    required ConvergenceResult convergence,
    required IdempotenceResult idempotence,
  }) =>
      {
        'test': 'holdout_34',
        'pass': convergence.pass && idempotence.pass,
        'convergence': convergence.toJson(),
        'idempotence': idempotence.toJson(),
      };

  /// Count positions where two ordered id lists disagree. Lists of
  /// different lengths contribute `|len_a - len_b|` to the drift on
  /// top of any prefix mismatches. Exposed for the verdict CLI's
  /// drift detail; the rest of the file uses it internally too.
  static int orderedDiffCountForTest(List<String> a, List<String> b) =>
      _orderedDiffCount(a, b);
}

Map<String, StudyNote> _index(List<StudyNote> notes) {
  final out = <String, StudyNote>{};
  for (final n in notes) {
    out[n.id] = n;
  }
  return out;
}

int _orderedDiffCount(List<String> a, List<String> b) {
  final shared = a.length < b.length ? a.length : b.length;
  var diffs = 0;
  for (var i = 0; i < shared; i++) {
    if (a[i] != b[i]) diffs++;
  }
  diffs += (a.length - b.length).abs();
  return diffs;
}
