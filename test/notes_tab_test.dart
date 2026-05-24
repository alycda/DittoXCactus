// Widget tests for U10's NotesTab.
//
// Covers the two invariants that show up on stage:
//   - self's contributor group is anchored at the top, peers below
//   - long-pressing a peer note that self hasn't yet accepted invokes the
//     accept handler with that note; long-pressing self's own notes does
//     nothing.
//
// The widget is stateless, so we feed it fixed `List<StudyNote>` snapshots
// directly — no DittoService needed.

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
      required List<StudyNote> notes,
      String selfContributor = 'phone-a',
      AcceptNote? onAccept,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesTab(
              notes: notes,
              selfContributor: selfContributor,
              onAccept: onAccept,
            ),
          ),
        ),
      );
    }

    testWidgets('empty notes list renders the waiting placeholder',
        (tester) async {
      await pumpTab(tester, notes: const []);
      expect(find.textContaining('No notes yet'), findsOneWidget);
    });

    testWidgets('self group is anchored above peer groups', (tester) async {
      await pumpTab(tester, notes: [
        note(contributor: 'phone-b', topic: 'mars'),
        note(contributor: 'phone-a', topic: 'mercury'),
      ]);

      final selfHeader =
          tester.getTopLeft(find.text('phone-a (you)')).dy;
      final peerHeader = tester.getTopLeft(find.text('phone-b')).dy;
      expect(selfHeader, lessThan(peerHeader));
    });

    testWidgets('long-press on peer note invokes onAccept', (tester) async {
      final accepted = <StudyNote>[];
      final peerNote = note(contributor: 'phone-b', topic: 'mars');

      await pumpTab(
        tester,
        notes: [peerNote],
        onAccept: (n) async => accepted.add(n),
      );

      await tester.longPress(find.text('mars'));
      await tester.pump();

      expect(accepted, hasLength(1));
      expect(accepted.first.id, peerNote.id);
    });

    testWidgets('long-press on self note does NOT invoke onAccept',
        (tester) async {
      final accepted = <StudyNote>[];
      final selfNote = note(contributor: 'phone-a', topic: 'mercury');

      await pumpTab(
        tester,
        notes: [selfNote],
        onAccept: (n) async => accepted.add(n),
      );

      await tester.longPress(find.text('mercury'));
      await tester.pump();

      expect(accepted, isEmpty);
    });

    testWidgets(
        'already-accepted peer note renders the "kept" badge and does NOT call onAccept',
        (tester) async {
      final accepted = <StudyNote>[];
      final peerNote = note(
        contributor: 'phone-b',
        topic: 'mars',
        acceptedBy: const ['phone-a'],
      );

      await pumpTab(
        tester,
        notes: [peerNote],
        onAccept: (n) async => accepted.add(n),
      );

      expect(find.text('kept'), findsOneWidget);

      await tester.longPress(find.text('mars'));
      await tester.pump();
      expect(accepted, isEmpty);
    });
  });
}
