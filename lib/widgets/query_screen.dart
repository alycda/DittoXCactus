/// Two-tab home: [NotesTab] (the live merged corpus, audience reads here
/// first) + [FlashcardsTab] (the generative moment), with [MeshStatusWidget]
/// pinned to the AppBar as the BLE-pairing tell.
///
/// Lands on the Notes tab (index 0) so the audience compares per-phone notes
/// before the generative pivot. Tab state survives swap because the two
/// tabs live inside an `IndexedStack`, not a `PageView`.
///
/// `QueryScreen` owns the live subscription to `DittoService.subscribeToNotes`
/// so children stay stateless against the merged corpus snapshot — keeps the
/// tabs trivially widget-testable with a fixed `List<StudyNote>`.
library mesh_rag.widgets.query_screen;

import 'package:ditto_live/ditto_live.dart';
import 'package:flutter/material.dart';

import '../models/study_note.dart';
import '../services/ditto_service.dart';
import '../services/retrieval_service.dart';
import '../services/seed_loader.dart';
import 'flashcards_tab.dart';
import 'mesh_status_widget.dart';
import 'notes_tab.dart';

class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key, this.initialTopic});

  /// Pre-fill the FlashcardsTab topic input. U12's demo overlay uses this
  /// to make dry-runs repeatable from a known starting state.
  final String? initialTopic;

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  int _tabIndex = 0;
  StoreObserver? _notesObserver;
  List<StudyNote> _notes = const [];

  @override
  void initState() {
    super.initState();
    // Defer the initial subscription to the first post-frame callback. Ditto
    // SDK versions vary on whether registerObserver fires its initial
    // snapshot synchronously during registration; if it does and we set
    // _notes from inside initState, Flutter trips the "setState called
    // during initState" assertion. addPostFrameCallback guarantees the
    // first onChange lands after the first build has completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notesObserver = DittoService.instance.subscribeToNotes((notes) {
        if (!mounted) return;
        setState(() => _notes = notes);
      });
    });
  }

  @override
  void dispose() {
    _notesObserver?.stop();
    super.dispose();
  }

  Future<void> _acceptPeerNote(StudyNote note) async {
    final self = SeedLoader.instance.selfContributor;
    final updated = note.withAcceptedBy(self);
    // OR-Set semantics: if `self` is already in the set the helper returns
    // the same instance, so don't re-write a no-op.
    if (identical(updated, note)) return;
    try {
      await DittoService.instance.upsertNote(updated);
    } catch (e) {
      // The InkWell onLongPress callback up the tree discards the returned
      // Future, so without this catch the rejection becomes an unhandled
      // async error in the zone and the user gets no on-screen feedback
      // that the "keep this note" gesture failed.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not keep note: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selfContributor = SeedLoader.instance.selfContributor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh RAG'),
        actions: [
          MeshStatusWidget(
            peerCountStream: DittoService.instance.peerCount,
            initialCount: DittoService.instance.currentPeerCount,
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          NotesTab(
            notes: _notes,
            selfContributor: selfContributor,
            onAccept: _acceptPeerNote,
          ),
          FlashcardsTab(
            generateFlashcards:
                RetrievalService.instance.generateFlashcards,
            selfContributor: selfContributor,
            initialTopic: widget.initialTopic,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notes_outlined),
            selectedIcon: Icon(Icons.notes),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Flashcards',
          ),
        ],
      ),
    );
  }
}
