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
import 'demo_overlay.dart';
import 'flashcards_tab.dart';
import 'mesh_status_widget.dart';
import 'notes_tab.dart';

class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key, this.initialTopic});

  /// Pre-fill the FlashcardsTab topic input. U12's demo choreography uses
  /// this to start every dry-run from the same on-stage state — type-then-
  /// tap-Generate becomes a single tap.
  final String? initialTopic;

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  int _tabIndex = 0;
  final StreamController<List<StudyNote>> _notesController =
      StreamController<List<StudyNote>>.broadcast();
  List<StudyNote> _notes = const [];
  StoreObserver? _notesObserver;

  // Demo-overlay state (U12). Updated by the peer-count stream and by
  // FlashcardsTab's onLatency callback. Both are no-ops when the overlay
  // is disabled (kDemoOverlayEnabled == false) but kept live regardless so
  // a developer toggling the flag at runtime via dart-define gets correct
  // values immediately.
  int _peerCount = DittoService.instance.currentPeerCount;
  int? _lastQueryLatencyMs;
  StreamSubscription<int>? _peerSub;

  @override
  void initState() {
    super.initState();
    _wireNotesObserver();
    _peerSub = DittoService.instance.peerCount.listen((n) {
      if (!mounted) return;
      setState(() => _peerCount = n);
    });
  }

  Future<void> _wireNotesObserver() async {
    // Materialize the current corpus once for the initial paint so the
    // NotesTab doesn't show its empty-state while the first observer
    // callback is in flight.
    try {
      final initial = await DittoService.instance.queryAll();
      if (!mounted) return;
      setState(() => _notes = initial);
    } catch (_) {
      // Tolerate the test harness path where Ditto isn't initialized —
      // the initial paint just stays empty, the observer below is a no-op.
    }
    // Defer the observer registration to the next post-frame callback.
    // Ditto SDK versions vary on whether `registerObserver` fires its
    // initial snapshot synchronously during registration; today my path
    // is safe because the `_notesController.add(...)` doesn't call
    // setState directly, but the demo-overlay state setter we added in
    // U12 does — without the postFrameCallback guard, a synchronous
    // initial snapshot would now trip Flutter's "setState called during
    // initState" assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _notesObserver = DittoService.instance.subscribeToNotes((notes) {
          if (!mounted) return;
          if (!_notesController.isClosed) _notesController.add(notes);
          setState(() => _notes = notes);
        });
      } catch (_) {
        // Tolerate the test harness path where Ditto isn't initialized.
      }
    });
  }

  @override
  void dispose() {
    _peerSub?.cancel();
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
      body: Stack(
        children: [
          IndexedStack(
            index: _tabIndex,
            children: [
              NotesTab(
                notesStream: _notesController.stream,
                initialNotes: _notes,
                selfContributor: SeedLoader.instance.selfContributor,
                onAcceptPeerNote: DittoService.instance.upsertNote,
              ),
              FlashcardsTab(
                generate: RetrievalService.instance.generateFlashcards,
                selfContributor: SeedLoader.instance.selfContributor,
                initialTopic: widget.initialTopic,
                onLatency: (ms) {
                  if (!mounted) return;
                  setState(() => _lastQueryLatencyMs = ms);
                },
              ),
            ],
          ),
          DemoOverlay(
            peerCount: _peerCount,
            noteCount: _notes.length,
            lastQueryLatencyMs: _lastQueryLatencyMs,
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
