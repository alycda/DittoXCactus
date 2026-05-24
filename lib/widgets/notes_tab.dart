/// Live notes list grouped by contributor — the Stage 0 ship surface.
///
/// Renders the merged corpus the way the audience reads it: self's notes at
/// the top (anchored), peer notes appearing below as BLE sync fills them in.
/// Long-press on a peer note writes through the [StudyNote.acceptedBy] OR-Set
/// so this device claims the peer's note as its own — the "save it" gesture
/// the demo script narrates in beat 2.5.
///
/// This widget is intentionally stateless: parent ([QueryScreen]) owns the
/// subscription to `DittoService.subscribeToNotes` and rebuilds with the
/// latest snapshot. Keeping subscriptions in the parent makes tests trivial
/// (pass a fixed `List<StudyNote>`) and avoids a second observer per tab
/// rebuild.
library mesh_rag.widgets.notes_tab;

import 'package:flutter/material.dart';

import '../models/study_note.dart';

/// Optional accept handler — called when the user long-presses a note that
/// `self` has not already accepted. `null` disables the gesture (used by the
/// notes-only render path in tests).
typedef AcceptNote = Future<void> Function(StudyNote note);

class NotesTab extends StatelessWidget {
  const NotesTab({
    super.key,
    required this.notes,
    required this.selfContributor,
    this.onAccept,
  });

  /// Current merged corpus snapshot. Parent re-renders on each
  /// `subscribeToNotes` change.
  final List<StudyNote> notes;

  /// Local device's contributor key (`phone-a` / `phone-b`) — used to (a)
  /// pull self's notes to the top group and (b) write into the OR-Set on
  /// accept.
  final String selfContributor;

  final AcceptNote? onAccept;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No notes yet.\nWaiting for the seed loader…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ),
      );
    }

    final grouped = _groupByContributor(notes, selfContributor);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, groupIndex) {
        final group = grouped[groupIndex];
        return _ContributorGroup(
          contributor: group.contributor,
          isSelf: group.contributor == selfContributor,
          notes: group.notes,
          selfContributor: selfContributor,
          onAccept: onAccept,
        );
      },
    );
  }
}

/// Group notes by contributor; self first, peers alphabetical after.
/// Within a group, notes sort by `createdAt` desc (newest first) so the
/// audience sees the freshest seed at the top.
List<_NotesGroup> _groupByContributor(
  List<StudyNote> notes,
  String selfContributor,
) {
  final byContributor = <String, List<StudyNote>>{};
  for (final n in notes) {
    byContributor.putIfAbsent(n.contributor, () => []).add(n);
  }
  for (final list in byContributor.values) {
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  final keys = byContributor.keys.toList()
    ..sort((a, b) {
      if (a == selfContributor) return -1;
      if (b == selfContributor) return 1;
      return a.compareTo(b);
    });
  return [
    for (final k in keys) _NotesGroup(contributor: k, notes: byContributor[k]!),
  ];
}

class _NotesGroup {
  const _NotesGroup({required this.contributor, required this.notes});
  final String contributor;
  final List<StudyNote> notes;
}

class _ContributorGroup extends StatelessWidget {
  const _ContributorGroup({
    required this.contributor,
    required this.isSelf,
    required this.notes,
    required this.selfContributor,
    required this.onAccept,
  });

  final String contributor;
  final bool isSelf;
  final List<StudyNote> notes;
  final String selfContributor;
  final AcceptNote? onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Icon(
                isSelf ? Icons.smartphone : Icons.devices_other,
                size: 18,
                color: isSelf ? Colors.indigo : Colors.teal,
              ),
              const SizedBox(width: 6),
              Text(
                isSelf ? '$contributor (you)' : contributor,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${notes.length}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        for (final n in notes)
          _NoteTile(
            note: n,
            isSelf: isSelf,
            alreadyAccepted: n.acceptedBy.contains(selfContributor),
            onAccept: (isSelf || onAccept == null) ? null : onAccept,
          ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.isSelf,
    required this.alreadyAccepted,
    required this.onAccept,
  });

  final StudyNote note;
  final bool isSelf;
  final bool alreadyAccepted;
  final AcceptNote? onAccept;

  @override
  Widget build(BuildContext context) {
    final canAccept = onAccept != null && !alreadyAccepted;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onLongPress: canAccept ? () => onAccept!(note) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.topic,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (alreadyAccepted)
                    const _AcceptedBadge()
                  else if (canAccept)
                    Text(
                      'long-press to keep',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                note.body,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    for (final t in note.tags)
                      Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AcceptedBadge extends StatelessWidget {
  const _AcceptedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 12, color: Colors.green.shade700),
          const SizedBox(width: 2),
          Text(
            'kept',
            style: TextStyle(
              fontSize: 10,
              color: Colors.green.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
