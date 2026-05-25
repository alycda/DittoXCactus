// Widget tests for U10's NotesTab.
//
// Covers the two invariants that show up on stage:
//   - self's contributor group is anchored at the top, peers below
//   - long-pressing a peer note that self hasn't yet accepted invokes the
//     accept handler with that note (now in the acceptedBy OR-Set);
//     long-pressing self's own notes or already-accepted peer notes is
//     a no-op
//
// My NotesTab is Stream-driven (vs sibling-U10's prop-driven version),
// so the test pumps with `initialNotes` populated and an inert stream —
// no DittoService needed.
//
// Ported from sibling-U10 (e39e3e30) — see HackMD walkthrough row 18:
// https://hackmd.io/@alyssaditto/BJXvHrMeGl

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/models/study_note.dart';
import 'package:mesh_rag/widgets/notes_tab.dart';

void main() {
  group('NotesTab', () {
    StudyNote note({
      required String contributor,
      required String topic,
      DateTime? createdAt,
      List<String> acceptedBy = const [],
    }) {
      return StudyNote.seed(
        contributor: contributor,
        topic: topic,
        createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
        tags: const [],
        body: 'stub body for $topic ($contributor)',
        acceptedBy: acceptedBy,
      );
    }

    Future<void> pumpTab(
      WidgetTester tester, {
      required List<StudyNote> initialNotes,
      String selfContributor = 'phone-a',
      AcceptPeerNoteFn? onAccept,
    }) async {
      final controller = StreamController<List<StudyNote>>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesTab(
              notesStream: controller.stream,
              initialNotes: initialNotes,
              selfContributor: selfContributor,
              onAcceptPeerNote: onAccept ?? (_) async {},
            ),
          ),
        ),
      );
    }

    testWidgets('empty notes list renders the waiting placeholder',
        (tester) async {
      await pumpTab(tester, initialNotes: const []);
      expect(find.textContaining('No notes yet'), findsOneWidget);
    });

    testWidgets('self group is anchored above peer groups', (tester) async {
      await pumpTab(tester, initialNotes: [
        note(contributor: 'phone-b', topic: 'mars'),
        note(contributor: 'phone-a', topic: 'mercury'),
      ]);

      final selfHeader = tester.getTopLeft(find.text('phone-a (you)')).dy;
      final peerHeader = tester.getTopLeft(find.text('phone-b')).dy;
      expect(selfHeader, lessThan(peerHeader));
    });

    testWidgets('long-press on peer note invokes onAcceptPeerNote with self '
        'in the OR-Set', (tester) async {
      final accepted = <StudyNote>[];
      final peerNote = note(contributor: 'phone-b', topic: 'mars');

      await pumpTab(
        tester,
        initialNotes: [peerNote],
        onAccept: (n) async => accepted.add(n),
      );

      await tester.longPress(find.text('mars'));
      await tester.pump();

      expect(accepted, hasLength(1));
      // _id is UUIDv5 over (contributor|topic|createdAt) — adding to the
      // acceptedBy OR-Set doesn't change it.
      expect(accepted.first.id, peerNote.id);
      // OR-Set should now contain self.
      expect(accepted.first.acceptedBy, contains('phone-a'));
    });

    testWidgets('long-press on self note does NOT invoke onAcceptPeerNote',
        (tester) async {
      final accepted = <StudyNote>[];
      final selfNote = note(contributor: 'phone-a', topic: 'mercury');

      await pumpTab(
        tester,
        initialNotes: [selfNote],
        onAccept: (n) async => accepted.add(n),
      );

      await tester.longPress(find.text('mercury'));
      await tester.pump();

      expect(accepted, isEmpty);
    });

    testWidgets(
        'already-accepted peer note renders the kept-badge icon and does '
        'NOT call onAcceptPeerNote on long-press', (tester) async {
      final accepted = <StudyNote>[];
      final peerNote = note(
        contributor: 'phone-b',
        topic: 'mars',
        acceptedBy: const ['phone-a'],
      );

      await pumpTab(
        tester,
        initialNotes: [peerNote],
        onAccept: (n) async => accepted.add(n),
      );

      // The "kept" badge is an Icons.check_circle in self's brand green
      // next to the topic on already-accepted peer notes.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.longPress(find.text('mars'));
      await tester.pump();

      expect(accepted, isEmpty);
    });

    testWidgets('stream emits replace the initial snapshot', (tester) async {
      final controller = StreamController<List<StudyNote>>.broadcast();
      addTearDown(controller.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesTab(
              notesStream: controller.stream,
              initialNotes: [note(contributor: 'phone-a', topic: 'mercury')],
              selfContributor: 'phone-a',
              onAcceptPeerNote: (_) async {},
            ),
          ),
        ),
      );
      expect(find.text('mercury'), findsOneWidget);

      controller.add([
        note(contributor: 'phone-a', topic: 'mercury'),
        note(contributor: 'phone-b', topic: 'mars'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('mercury'), findsOneWidget);
      expect(find.text('mars'), findsOneWidget);
      expect(find.text('phone-b'), findsOneWidget);
    });
  });
}
