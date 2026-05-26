// Widget tests for the U12 DemoOverlay.
//
// The overlay's toggle is a build-time dart-define
// (`--dart-define=DEMO_OVERLAY=true`) read at compile time via
// `bool.fromEnvironment`. Default builds (including this test binary)
// have it disabled, so the overlay returns `SizedBox.shrink()` and
// renders nothing — which is exactly what we want to lock in: a release
// build doesn't leak the debug HUD into the audience-visible UI.
//
// The "enabled" path is exercised by the demo-flag justfile recipe
// (manual on-device verification) — running it through tests would
// require a separate compile-time variant, which isn't worth the cost
// for a debug-only widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mesh_rag/widgets/demo_overlay.dart';

void main() {
  group('DemoOverlay', () {
    test('kDemoOverlayEnabled defaults to false', () {
      expect(kDemoOverlayEnabled, isFalse);
    });

    testWidgets('renders nothing when DEMO_OVERLAY is unset (production path)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                DemoOverlay(peerCount: 2, noteCount: 7, lastQueryLatencyMs: 1234),
              ],
            ),
          ),
        ),
      );
      // The values would render as 'peers 2', 'notes 7', 'last 1234ms' if
      // the overlay were active. Production toggle off → no text.
      expect(find.text('peers 2'), findsNothing);
      expect(find.text('notes 7'), findsNothing);
      expect(find.text('1234ms'), findsNothing);
    });
  });
}
