// Widget tests for U10's MeshStatusWidget.
//
// What's testable here without a real DittoService: the
// peer-count-stream → label/color transition. The pill is the audience's
// single visible signal that BLE pairing landed, so its label/color
// invariants are load-bearing for the R1 demo beat.
//
// Color assertions: we check the dot's BoxDecoration.color (the dot is the
// most legible color carrier on stage; the pill bg is paler).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/widgets/mesh_status_widget.dart';

void main() {
  group('MeshStatusWidget', () {
    Future<void> pumpPill(
      WidgetTester tester, {
      required Stream<int> stream,
      int initial = 0,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MeshStatusWidget(
                peerCountStream: stream,
                initialCount: initial,
              ),
            ),
          ),
        ),
      );
    }

    Color _dotColor(WidgetTester tester) {
      // The dot is the only Container whose BoxDecoration.shape is circle.
      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final c in containers) {
        final deco = c.decoration;
        if (deco is BoxDecoration && deco.shape == BoxShape.circle) {
          return deco.color!;
        }
      }
      fail('no circular dot Container found');
    }

    testWidgets('initial count 0 renders "mesh: alone" in gray',
        (tester) async {
      final ctrl = StreamController<int>.broadcast();
      addTearDown(ctrl.close);

      await pumpPill(tester, stream: ctrl.stream, initial: 0);
      await tester.pump();

      expect(find.text('mesh: alone'), findsOneWidget);
      expect(_dotColor(tester), Colors.grey.shade500);
    });

    testWidgets('initial count 1 renders "mesh: 1 peer" in green',
        (tester) async {
      final ctrl = StreamController<int>.broadcast();
      addTearDown(ctrl.close);

      await pumpPill(tester, stream: ctrl.stream, initial: 1);
      await tester.pump();

      expect(find.text('mesh: 1 peer'), findsOneWidget);
      expect(_dotColor(tester), Colors.green.shade600);
    });

    testWidgets('count > 1 pluralizes the label', (tester) async {
      final ctrl = StreamController<int>.broadcast();
      addTearDown(ctrl.close);

      await pumpPill(tester, stream: ctrl.stream, initial: 3);
      await tester.pump();

      expect(find.text('mesh: 3 peers'), findsOneWidget);
    });

    testWidgets('stream transition 0 → 1 → 2 updates label and color',
        (tester) async {
      final ctrl = StreamController<int>.broadcast();
      addTearDown(ctrl.close);

      await pumpPill(tester, stream: ctrl.stream, initial: 0);
      await tester.pump();
      expect(find.text('mesh: alone'), findsOneWidget);
      expect(_dotColor(tester), Colors.grey.shade500);

      ctrl.add(1);
      await tester.pump(); // delivers the stream event (microtask)
      await tester.pump(); // rebuilds the widget with the new count
      expect(find.text('mesh: 1 peer'), findsOneWidget);
      expect(_dotColor(tester), Colors.green.shade600);

      ctrl.add(2);
      await tester.pump(); // delivers the stream event
      await tester.pump(); // rebuilds
      expect(find.text('mesh: 2 peers'), findsOneWidget);
      expect(_dotColor(tester), Colors.green.shade600);
    });

    testWidgets('stream transition 1 → 0 reverts to alone/gray',
        (tester) async {
      final ctrl = StreamController<int>.broadcast();
      addTearDown(ctrl.close);

      await pumpPill(tester, stream: ctrl.stream, initial: 1);
      await tester.pump();
      expect(find.text('mesh: 1 peer'), findsOneWidget);

      ctrl.add(0);
      await tester.pump(); // delivers the stream event
      await tester.pump(); // rebuilds
      expect(find.text('mesh: alone'), findsOneWidget);
      expect(_dotColor(tester), Colors.grey.shade500);
    });
  });
}
