/// Live notes list, grouped by contributor (self first, peers after).
///
/// Plan §U10:
///   - Subscribes to `DittoService.subscribeToNotes` for live updates as
///     peers come into range and Ditto syncs their G-Set.
///   - Long-press surfaces the "accept this peer note" action which calls
///     `DittoService.upsertNote(note.withAcceptedBy(self))` — writes through
///     the OR-Set, no UI confirmation dialog (Stage 0 speed).
///   - Demo-day visible signal: when phone B comes into range, B's notes
///     appear in the "peers" sections *before* any regeneration runs.
///     That's the magic moment the script hangs on.
library mesh_rag.widgets.notes_tab;

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/study_note.dart';

/// Function signature for "accept this peer note" — injected so tests don't
/// need a real Ditto.
typedef AcceptPeerNoteFn = Future<void> Function(StudyNote note);

class NotesTab extends StatefulWidget {
  const NotesTab({
    super.key,
    required this.notesStream,
    required this.initialNotes,
    required this.selfContributor,
    required this.onAcceptPeerNote,
  });

  final Stream<List<StudyNote>> notesStream;
  final List<StudyNote> initialNotes;

  /// `phone-a` or `phone-b` — the SeedLoader's selfContributor.
  final String selfContributor;

  final AcceptPeerNoteFn onAcceptPeerNote;

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  late List<StudyNote> _notes;
  StreamSubscription<List<StudyNote>>? _sub;

  @override
  void initState() {
    super.initState();
    _notes = widget.initialNotes;
    _sub = widget.notesStream.listen((next) {
      if (!mounted) return;
      setState(() => _notes = next);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Map<String, List<StudyNote>> _grouped() {
    final groups = <String, List<StudyNote>>{};
    for (final note in _notes) {
      groups.putIfAbsent(note.contributor, () => []).add(note);
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.topic.toLowerCase().compareTo(b.topic.toLowerCase()));
    }
    return groups;
  }

  List<String> _orderedContributors(Map<String, List<StudyNote>> groups) {
    final self = widget.selfContributor;
    final others = groups.keys.where((c) => c != self).toList()..sort();
    return [if (groups.containsKey(self)) self, ...others];
  }

  @override
  Widget build(BuildContext context) {
    if (_notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No notes yet. Seed corpus is loading…',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
      );
    }
    final groups = _grouped();
    final order = _orderedContributors(groups);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: order.length,
      itemBuilder: (context, i) {
        final contributor = order[i];
        final isSelf = contributor == widget.selfContributor;
        return _ContributorSection(
          contributor: contributor,
          isSelf: isSelf,
          notes: groups[contributor]!,
          onAcceptPeerNote: widget.onAcceptPeerNote,
          selfContributor: widget.selfContributor,
        );
      },
    );
  }
}

class _ContributorSection extends StatelessWidget {
  const _ContributorSection({
    required this.contributor,
    required this.isSelf,
    required this.notes,
    required this.onAcceptPeerNote,
    required this.selfContributor,
  });

  final String contributor;
  final bool isSelf;
  final List<StudyNote> notes;
  final AcceptPeerNoteFn onAcceptPeerNote;
  final String selfContributor;

  @override
  Widget build(BuildContext context) {
    final headerColor =
        isSelf ? const Color(0xFF1A237E) : const Color(0xFF2E7D32);
    final headerLabel = isSelf ? '$contributor (you)' : contributor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: headerColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                headerLabel,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: headerColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        for (final note in notes)
          _NoteTile(
            note: note,
            isSelf: isSelf,
            selfContributor: selfContributor,
            onAcceptPeerNote: onAcceptPeerNote,
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.isSelf,
    required this.selfContributor,
    required this.onAcceptPeerNote,
  });

  final StudyNote note;
  final bool isSelf;
  final String selfContributor;
  final AcceptPeerNoteFn onAcceptPeerNote;

  bool get _alreadyAccepted => note.acceptedBy.contains(selfContributor);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onLongPress: isSelf || _alreadyAccepted
            ? null
            : () => _handleAccept(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.topic,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!isSelf && _alreadyAccepted)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Color(0xFF2E7D32),
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
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in note.tags)
                      _Chip(label: '#$tag'),
                  ],
                ),
              ],
              if (!isSelf && !_alreadyAccepted) ...[
                const SizedBox(height: 6),
                const Text(
                  'long-press to accept',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAccept(BuildContext context) async {
    final updated = note.withAcceptedBy(selfContributor);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await onAcceptPeerNote(updated);
      messenger.showSnackBar(
        SnackBar(
          content: Text('accepted: ${note.topic}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('accept failed: $e')),
      );
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
    );
  }
}
