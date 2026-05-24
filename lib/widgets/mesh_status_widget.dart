/// AppBar trailing pill that surfaces the mesh state to the audience.
///
/// Plan §U10:
///   - `'mesh: alone'` (gray) when `peerCount == 0`.
///   - `'mesh: N peer(s)'` (green) when `peerCount > 0`.
///   - Camera-legible: font size 16, monospace, big dot, large pill.
///   - **No pulse animation.** The gray → green color flip is the signal;
///     surrounding deck/script handles dramatic timing.
///
/// Pattern reference: bitchat's peer-count UI
/// (`_inspiration/repos/permissionlesstech__bitchat/`) — the visual idiom
/// for "you are in mesh with N peers."
library mesh_rag.widgets.mesh_status_widget;

import 'dart:async';

import 'package:flutter/material.dart';

class MeshStatusWidget extends StatefulWidget {
  const MeshStatusWidget({
    super.key,
    required this.peerCount,
    this.initialPeerCount = 0,
  });

  /// Stream of remote-peer counts. `DittoService.instance.peerCount` in
  /// production; a `StreamController<int>` in tests.
  final Stream<int> peerCount;

  /// Synchronous initial value so the pill paints correctly on first
  /// frame, before the stream has emitted. In production this is
  /// `DittoService.instance.currentPeerCount`.
  final int initialPeerCount;

  @override
  State<MeshStatusWidget> createState() => _MeshStatusWidgetState();
}

class _MeshStatusWidgetState extends State<MeshStatusWidget> {
  late int _count;
  StreamSubscription<int>? _sub;

  @override
  void initState() {
    super.initState();
    _count = widget.initialPeerCount;
    _sub = widget.peerCount.listen((next) {
      if (!mounted) return;
      setState(() => _count = next);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAlone = _count == 0;
    final pillColor =
        isAlone ? const Color(0xFFBDBDBD) : const Color(0xFF66BB6A);
    final dotColor =
        isAlone ? const Color(0xFF424242) : const Color(0xFFFFFFFF);
    final label = isAlone
        ? 'mesh: alone'
        : 'mesh: $_count ${_count == 1 ? 'peer' : 'peers'}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Semantics(
        label: label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
