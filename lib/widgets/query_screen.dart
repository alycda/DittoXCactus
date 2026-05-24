/// Two-tab Scaffold + AppBar + bottom NavigationBar — the live UI that
/// follows boot.
///
/// Plan §U10:
///   - Tabs: [NotesTab, FlashcardsTab] inside an `IndexedStack` so tab
///     state survives swap (the FlashcardsTab generation history isn't
///     thrown away when the demonstrator switches to the Notes tab to
///     show B's notes appearing in the list).
///   - Lands on `NotesTab` (index 0): audience compares per-phone notes
///     first, then taps over to `FlashcardsTab` for the generative moment.
///   - `MeshStatusWidget` lives in the AppBar trailing slot.
///
/// This file is the *only* place that reaches into the singleton services.
/// Each child widget takes its dependencies as constructor parameters so
/// widget tests don't need to bring up Ditto/Cactus.
library mesh_rag.widgets.query_screen;

import 'dart:async';

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
  const QueryScreen({super.key});

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  int _tabIndex = 0;
  final StreamController<List<StudyNote>> _notesController =
      StreamController<List<StudyNote>>.broadcast();
  List<StudyNote> _initialNotes = const [];
  StoreObserver? _notesObserver;

  @override
  void initState() {
    super.initState();
    _wireNotesObserver();
  }

  Future<void> _wireNotesObserver() async {
    // Materialize the current corpus once for the initial paint so the
    // NotesTab doesn't show its empty-state while the first observer
    // callback is in flight.
    try {
      final initial = await DittoService.instance.queryAll();
      if (!mounted) return;
      setState(() => _initialNotes = initial);
    } catch (_) {
      // Tolerate the test harness path where Ditto isn't initialized —
      // the initial paint just stays empty, the observer below is a no-op.
    }
    try {
      _notesObserver = DittoService.instance.subscribeToNotes((notes) {
        if (_notesController.isClosed) return;
        _notesController.add(notes);
      });
    } catch (_) {
      // Same tolerance as above; the observer is best-effort.
    }
  }

  @override
  void dispose() {
    _notesObserver?.cancel();
    _notesController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesh RAG'),
        actions: [
          MeshStatusWidget(
            peerCount: DittoService.instance.peerCount,
            initialPeerCount: DittoService.instance.currentPeerCount,
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          NotesTab(
            notesStream: _notesController.stream,
            initialNotes: _initialNotes,
            selfContributor: SeedLoader.instance.selfContributor,
            onAcceptPeerNote: DittoService.instance.upsertNote,
          ),
          FlashcardsTab(
            generate: RetrievalService.instance.generateFlashcards,
            selfContributor: SeedLoader.instance.selfContributor,
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
