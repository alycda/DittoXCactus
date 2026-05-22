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
/// on tap to reveal the full body. The audience can read off each phone's
/// contribution and verify the post-sync card improvements against the
/// actual underlying notes.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final self = SeedLoader.instance.selfContributor;
    final mine = _notes.where((n) => n.contributor == self).toList();
    final peers = _notes.where((n) => n.contributor != self).toList();
    final peerContribs = {for (final n in peers) n.contributor};

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
              : '${peerContribs.join(', ')} · ${peers.length} note${peers.length == 1 ? '' : 's'}',
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
          ...peers.map((n) => _NoteCard(note: n, isMine: false)),
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
  const _NoteCard({required this.note, required this.isMine});

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
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          note.body.length > 80 ? '${note.body.substring(0, 80)}…' : note.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15),
        ),
        subtitle: note.tags.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: note.tags.map((t) => _TagChip(t)).toList(),
                ),
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
              ],
            ),
          ),
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
