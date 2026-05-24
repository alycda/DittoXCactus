// Widget tests for U10's MeshStatusWidget.
//
// What matters here (plan §U10):
//   - peer count = 0 → label "mesh: alone", gray pill.
//   - peer count = 1 → label "mesh: 1 peer" (singular), green pill.
//   - peer count = 2+ → label "mesh: N peers" (plural).
//   - Stream-driven transitions repaint without rebuilding the parent.
//
// The pill colors are pinned to specific Material hex values in the widget;
// asserting on those colors here is what makes the gray → green flip a
// regression-checked contract instead of a "looked fine on my laptop"
// detail. If a future visual refresh changes the hex, update both the
// widget AND this test in the same diff.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/widgets/mesh_status_widget.dart';

const _alonePillColor = Color(0xFFBDBDBD);
const _meshPillColor = Color(0xFF66BB6A);

// Wrap as a top-level body widget rather than as an AppBar action, so a
// tight AppBar trailing constraint can't silently clip the pill out of
// the test tree. Layout under a real AppBar is exercised by the smoke
// test in boot_screen_test.dart and the manual demo run.
Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.topRight, child: child),
      ),
    );

Container _pillContainer(WidgetTester tester) {
  // The pill is the innermost decorated Container in the widget — the
  // outer Padding doesn't carry a decoration, so `findsAtLeast` + filter.
  final containers = tester
      .widgetList<Container>(find.descendant(
        of: find.byType(MeshStatusWidget),
        matching: find.byType(Container),
      ))
      .where((c) => c.decoration is BoxDecoration)
      .toList();
  // Pill (outer) + dot (inner) both have BoxDecorations; pill is first.
  return containers.first;
}

Color _pillColor(WidgetTester tester) {
  final container = _pillContainer(tester);
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  group('MeshStatusWidget', () {
    testWidgets('renders "mesh: alone" with gray pill at peerCount=0',
        (tester) async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(_wrap(MeshStatusWidget(
        peerCount: controller.stream,
      )));
      await tester.pump();

      expect(find.text('mesh: alone'), findsOneWidget);
      expect(_pillColor(tester), _alonePillColor);
    });

    testWidgets('transitions gray → green when peerCount goes 0 → 1',
        (tester) async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(_wrap(MeshStatusWidget(
        peerCount: controller.stream,
      )));
      await tester.pumpAndSettle();
      expect(_pillColor(tester), _alonePillColor);

      controller.add(1);
      await tester.pumpAndSettle();

      expect(find.text('mesh: 1 peer'), findsOneWidget);
      expect(find.text('mesh: alone'), findsNothing);
      expect(_pillColor(tester), _meshPillColor);
    });

    testWidgets('pluralizes "peers" for N >= 2', (tester) async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(_wrap(MeshStatusWidget(
        peerCount: controller.stream,
        initialPeerCount: 3,
      )));
      await tester.pumpAndSettle();

      expect(find.text('mesh: 3 peers'), findsOneWidget);
      expect(_pillColor(tester), _meshPillColor);

      controller.add(2);
      await tester.pumpAndSettle();
      expect(find.text('mesh: 2 peers'), findsOneWidget);
    });

    testWidgets('falling back to peerCount=0 returns to gray', (tester) async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(_wrap(MeshStatusWidget(
        peerCount: controller.stream,
        initialPeerCount: 1,
      )));
      await tester.pumpAndSettle();
      expect(_pillColor(tester), _meshPillColor);

      controller.add(0);
      await tester.pumpAndSettle();
      expect(find.text('mesh: alone'), findsOneWidget);
      expect(_pillColor(tester), _alonePillColor);
    });
  });
}
