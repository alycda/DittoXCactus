// Smoke test for U4's boot skeleton.
//
// U7 / U9 / U11 will land study_note_test.dart, retrieval_service_test.dart,
// and flashcard_gen_test.dart respectively. This file exists so `flutter
// test` clears with at least one passing suite while the project shell is
// still skeletal — and so the next U5+ patch has a guard rail if it
// breaks the boot UI by accident.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/main.dart';

void main() {
  group('MeshRagApp', () {
    testWidgets('builds at all', (WidgetTester tester) async {
      await tester.pumpWidget(const MeshRagApp());
      // Three pumps because the boot future advances synchronously through
      // its labelled phases (no real awaits in the U4 skeleton). One pump
      // mounts the tree; the rest let the boot setState calls settle.
      await tester.pump();
      // The MaterialApp should be in the tree regardless of boot state.
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets(
        'failed boot surfaces a StateError when PHONE_ROLE is unset/empty',
        (WidgetTester tester) async {
      // The widget test runs without --dart-define, so kPhoneRole is "".
      // BootScreen._validatePhoneRole() must surface this as a StateError
      // and the failed-view text must include the actual error message —
      // not crash the app, not silently advance to QueryScreen.
      await tester.pumpWidget(const MeshRagApp());
      await tester.pump(); // boot starts
      await tester.pump(); // failed-view renders

      expect(find.text('Boot failed'), findsOneWidget);
      expect(find.textContaining('PHONE_ROLE'), findsOneWidget);
    });
  });
}
