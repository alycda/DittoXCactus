/// Small top-right HUD for on-stage demonstrator confidence (U12).
///
/// **Not the main UI.** The mesh-status pill (in the AppBar) is what the
/// audience reads. The overlay is for the demonstrator + the recording —
/// it shows peer count, note count, and last-query latency so a stalled
/// sync or zero-retrieval result surfaces before it shows on the audience
/// screen.
///
/// Toggle: build-time dart-define `DEMO_OVERLAY=true`. Disabled by default
/// so a normal release build is clean. The justfile recipe
/// `app-run-a-demo` passes the flag.
///
/// Pattern reference: bitchat's peer-count UI
/// (`_inspiration/repos/permissionlesstech__bitchat/`) — visual idiom
/// stayed close so the overlay reads as part of the same family as the
/// AppBar pill, just in a debug typography.
library mesh_rag.widgets.demo_overlay;

import 'package:flutter/material.dart';

/// `--dart-define=DEMO_OVERLAY=true` enables the HUD. Any other value
/// (or unset) leaves the overlay off entirely — [DemoOverlay] returns
/// `SizedBox.shrink()` so it's a no-op in production builds.
const bool kDemoOverlayEnabled =
    bool.fromEnvironment('DEMO_OVERLAY', defaultValue: false);

/// Stack-positioned HUD. Drop into a `Stack` above the Scaffold body, or
/// pass it as one of the `Scaffold.body` children when the body is itself
/// a Stack.
///
/// Inputs are passed as plain values rather than singletons-by-reference
/// so the same widget can be driven by tests with a `StatefulBuilder`.
class DemoOverlay extends StatelessWidget {
  const DemoOverlay({
    super.key,
    required this.peerCount,
    required this.noteCount,
    this.lastQueryLatencyMs,
  });

  /// Latest remote-peer count. `DittoService.instance.currentPeerCount`
  /// in production.
  final int peerCount;

  /// Notes currently materialized in the local store.
  final int noteCount;

  /// Last `generateFlashcards` round-trip latency in ms, or `null` if no
  /// generation has run yet this session.
  final int? lastQueryLatencyMs;

  @override
  Widget build(BuildContext context) {
    if (!kDemoOverlayEnabled) return const SizedBox.shrink();
    return Positioned(
      top: 8,
      right: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC212121),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _line('peers', '$peerCount'),
              _line('notes', '$noteCount'),
              _line(
                'last',
                lastQueryLatencyMs == null
                    ? '—'
                    : '${lastQueryLatencyMs}ms',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Color(0xFFBDBDBD),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFEEEEEE),
          ),
        ),
      ],
    );
  }
}
