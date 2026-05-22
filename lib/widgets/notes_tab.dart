import 'package:ditto_live/ditto_live.dart';
import 'package:flutter/material.dart';

import '../models/study_note.dart';
import '../services/ditto_service.dart';
import '../services/seed_loader.dart';

/// Live list of `StudyNote`s grouped by contributor — "you" (this device)
/// first, peers after. Subscribes to the local Ditto store so notes
/// arriving via mesh sync animate into the list without manual refresh.
///
/// **Acceptance model (selective sync, not cloning).** Long-press a peer
/// note to "save to my notes" — this adds your contributor to the peer
/// document's `acceptedBy` OR-Set. No new document is created; the same
/// `_id` is shared across both phones. The original author sees the
/// acceptance via the same CRDT field ("saved by N peers" subtitle on
/// their note). This avoids the duplication problem the fork-clone model
/// produced when a peer's clone synced back to the original author's
/// device and appeared as a separate doc.
///
/// **Edit applies only to notes you authored.** Long-press your own
/// notes to tweak the body. Cloned-from-peer notes (legacy from the
/// pre-acceptance flow) are still editable since they're under your
/// contributor; future work adds local-overlay editing of accepted peer
/// notes without mutating the original.
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

  Future<void> _toggleAcceptance(StudyNote peer) async {
    final me = SeedLoader.instance.selfContributor;
    final next = peer.isAcceptedBy(me)
        ? peer.withoutAcceptedBy(me)
        : peer.withAcceptedBy(me);
    if (identical(next, peer)) return; // no-op
    await DittoService.instance.upsertNote(next);
    if (!mounted) return;
    final msg = peer.isAcceptedBy(me)
        ? 'removed from your notes'
        : 'saved ${peer.contributor}\'s note';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _editMyNote(StudyNote note) async {
    final controller = TextEditingController(text: note.body);
    final edited = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final viewInsets = MediaQuery.of(sheetCtx).viewInsets;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'edit your note',
                style: Theme.of(sheetCtx).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'topic: ${note.topic}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(sheetCtx)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: null,
                minLines: 4,
                autofocus: true,
                style: const TextStyle(fontSize: 15, height: 1.4),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'note body',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                    child: const Text('cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(sheetCtx).pop(controller.text.trim()),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (edited == null) return;
    if (edited.isEmpty || edited == note.body) return;
    // Clear embedding so the next ensureEmbeddings call re-embeds against
    // the new body. Otherwise the cosine top-k would match against stale
    // vector content while the UI shows the updated text.
    final updated = note.copyWith(body: edited, embedding: const []);
    await DittoService.instance.upsertNote(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('note saved'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showMyNoteActions(StudyNote note) async {
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
              child: Text('your note', style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'topic: ${note.topic}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('edit body'),
              subtitle: const Text(
                'tweak wording for your own note-taking style. '
                'the edit syncs to peers who have saved this note.',
                style: TextStyle(fontSize: 12, height: 1.35),
              ),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _editMyNote(note);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showPeerActions(StudyNote peer) async {
    final theme = Theme.of(context);
    final me = SeedLoader.instance.selfContributor;
    final saved = peer.isAcceptedBy(me);
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
                saved
                    ? Icons.bookmark_remove_outlined
                    : Icons.bookmark_add_outlined,
                color: saved
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              title: Text(
                saved ? 'remove from my notes' : 'save to my notes',
              ),
              subtitle: Text(
                saved
                    ? 'un-accept: future flashcards stop drawing on this note.'
                    : 'this is the same document, not a copy. you are adding '
                        'yourself to its acceptedBy set; the original peer '
                        'sees that you saved it.',
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _toggleAcceptance(peer);
              },
            ),
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
    // "Your notes" = notes you authored (contributor == self).
    // Legacy clone documents created by the older fork flow also live here
    // since they were authored under your contributor.
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
          subtitle: '$self · ${mine.length} note${mine.length == 1 ? '' : 's'}'
              ' · long-press to edit',
          color: theme.colorScheme.primary,
        ),
        ...mine.map(
          (n) => _NoteCard(
            note: n,
            isMine: true,
            savedByMe: false,
            onLongPress: () => _showMyNoteActions(n),
          ),
        ),
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
              savedByMe: n.isAcceptedBy(self),
              onLongPress: () => _showPeerActions(n),
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
  final bool savedByMe;
  final VoidCallback? onLongPress;
  const _NoteCard({
    required this.note,
    required this.isMine,
    required this.savedByMe,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isMine
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
        : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5);
    // For my own notes, surface how many peers have saved this note.
    // For peer notes, show whether I've saved this one (bookmark badge).
    final acceptedCount = note.acceptedBy.length;
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
              if (savedByMe)
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
            savedByMe: savedByMe,
            acceptedCount: acceptedCount,
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
                  if (isMine && note.acceptedBy.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'saved by ${note.acceptedBy.join(', ')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
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
  final bool savedByMe;
  final int acceptedCount;
  const _NoteCardSubtitle({
    required this.note,
    required this.isMine,
    required this.savedByMe,
    required this.acceptedCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String? hintText;
    if (isMine) {
      if (acceptedCount > 0) {
        hintText =
            'saved by $acceptedCount peer${acceptedCount == 1 ? '' : 's'}';
      }
    } else {
      hintText = savedByMe ? 'saved to your notes' : 'long-press to save';
    }
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
