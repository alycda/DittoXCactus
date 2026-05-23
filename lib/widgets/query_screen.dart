import 'package:flutter/material.dart';

import 'flashcards_tab.dart';
import 'mesh_status_widget.dart';
import 'notes_tab.dart';

/// The Stage-0.5 demo shell: a two-tab scaffold (Notes, Flashcards) with
/// the mesh-status pill always visible in the app bar. Notes shows each
/// device's contribution to the corpus; Flashcards is where the
/// learning-together moment plays out.
class QueryScreen extends StatefulWidget {
  const QueryScreen({super.key});

  @override
  State<QueryScreen> createState() => _QueryScreenState();
}

class _QueryScreenState extends State<QueryScreen> {
  int _index = 0; // land on Notes — audience compares per-phone notes first

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Together'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: MeshStatusWidget()),
          ),
        ],
      ),
      body: IndexedStack(
        // Keep both tab states alive so swapping doesn't lose generation
        // history or scroll position in the notes list.
        index: _index,
        children: const [NotesTab(), FlashcardsTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
