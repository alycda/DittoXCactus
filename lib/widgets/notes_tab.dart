import 'package:ditto_live/ditto_live.dart';
import 'package:flutter/material.dart';

import '../models/study_note.dart';
import '../services/ditto_service.dart';
import '../services/seed_loader.dart';

/// Live list of `StudyNote`s grouped by contributor — "you" (this device)
/// first, peers after. Subscribes to the local Ditto store so notes
/// arriving via mesh sync animate into the list without manual refresh.
///
/// Each note collapses to a single-line summary (topic · tags) and expands
/// on tap to reveal the full body. Long-press a peer note for a "Save to
/// my notes" action that clones the peer's note into your contributor
/// namespace as a new Ditto document — the original peer's note is
/// untouched, but the clone is yours to edit/curate. This is the explicit
/// fork model: human-in-the-loop trust, no automatic CRDT merging of
/// possibly-wrong peer content into your retrieval set.
class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  StoreObserver? _observer;
  List<StudyNote> _notes = const [];

  @override
  void initState() {
    super.initState();
    if (DittoService.instance.isReady) {
      _observer = DittoService.instance.subscribeToNotes((rows) {
        if (!mounted) return;
        setState(() => _notes = rows);
      });
    }
  }

  @override
  void dispose() {
    _observer?.cancel();
    super.dispose();
  }

  Future<void> _clonePeerNote(StudyNote peer) async {
    final clone = StudyNote.cloneFrom(
      peer: peer,
      myContributor: SeedLoader.instance.selfContributor,
    );
    await DittoService.instance.upsertNote(clone);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('cloned ${peer.contributor}\'s note to your notes'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showPeerActions(StudyNote peer, bool alreadyCloned) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'note from ${peer.contributor}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                peer.body.length > 120
                    ? '${peer.body.substring(0, 120)}…'
                    : peer.body,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                alreadyCloned
                    ? Icons.check_circle_outline
                    : Icons.copy_all_outlined,
                color: alreadyCloned
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              title: Text(
                alreadyCloned ? 'already saved' : 'save to my notes',
              ),
              subtitle: Text(
                alreadyCloned
                    ? 're-saving will overwrite your local copy with the original'
                    : 'creates an independent copy under your name. '
                        'editing your copy will NOT change the peer\'s original.',
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _clonePeerNote(peer);
              },
            ),
            // Future actions land here: "save & edit", "propose merge to peer",
            // "trust score signals", etc. See SEED-A.md deferrals.
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final self = SeedLoader.instance.selfContributor;
    final mine = _notes.where((n) => n.contributor == self).toList();
    final peers = _notes.where((n) => n.contributor != self).toList();
    final peerContribs = {for (final n in peers) n.contributor};

    // Set of peer note ids that we've already cloned into our namespace,
    // so the peer-row UI can mark them as "saved" and the clone action
    // can advertise overwrite semantics.
    final clonedPeerIds = {
      for (final n in mine)
        if (n.isCloned) n.originalNoteId,
    };

    if (_notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'waiting for notes…',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader(
          title: 'your notes',
          subtitle: '$self · ${mine.length} note${mine.length == 1 ? '' : 's'}',
          color: theme.colorScheme.primary,
        ),
        ...mine.map((n) => _NoteCard(note: n, isMine: true)),
        const SizedBox(height: 24),
        _SectionHeader(
          title: 'from peers',
          subtitle: peers.isEmpty
              ? 'no peers in mesh yet'
              : '${peerContribs.join(', ')} · ${peers.length} note${peers.length == 1 ? '' : 's'}'
                  ' · long-press to save',
          color: theme.colorScheme.tertiary,
        ),
        if (peers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Text(
              'bring another phone into BLE range — peer notes will appear here.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          )
        else
          ...peers.map(
            (n) => _NoteCard(
              note: n,
              isMine: false,
              alreadyCloned: clonedPeerIds.contains(n.id),
              onLongPress: () =>
                  _showPeerActions(n, clonedPeerIds.contains(n.id)),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 6, height: 24, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final StudyNote note;
  final bool isMine;
  final bool alreadyCloned;
  final VoidCallback? onLongPress;
  const _NoteCard({
    required this.note,
    required this.isMine,
    this.alreadyCloned = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isMine
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
        : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5);
    return Card(
      color: bg,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          shape: const Border(),
          title: Row(
            children: [
              if (note.isCloned && isMine)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  child: Icon(
                    Icons.call_merge,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (alreadyCloned)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  child: Icon(
                    Icons.bookmark,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              Expanded(
                child: Text(
                  note.body.length > 80
                      ? '${note.body.substring(0, 80)}…'
                      : note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          subtitle: _NoteCardSubtitle(
            note: note,
            isMine: isMine,
            alreadyCloned: alreadyCloned,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    note.body,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'topic: ${note.topic} · ${note.contributor}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  if (note.isCloned)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'cloned from peer · ${note.originalContributor}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCardSubtitle extends StatelessWidget {
  final StudyNote note;
  final bool isMine;
  final bool alreadyCloned;
  const _NoteCardSubtitle({
    required this.note,
    required this.isMine,
    required this.alreadyCloned,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hintText = alreadyCloned
        ? 'saved to your notes'
        : (!isMine ? 'long-press to save' : null);
    if (note.tags.isEmpty && hintText == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: note.tags.map((t) => _TagChip(t)).toList(),
            ),
          if (hintText != null) ...[
            const SizedBox(height: 4),
            Text(
              hintText,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
