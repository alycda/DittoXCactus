import 'package:flutter/material.dart';

import '../services/ditto_service.dart';

/// Top-bar pill showing peer count + a colored dot. Camera-legible at arm's
/// length: large text, big dot, no decorative chrome. Drives the "alone →
/// connected" transition the audience watches in U9.
class MeshStatusWidget extends StatefulWidget {
  const MeshStatusWidget({super.key});

  @override
  State<MeshStatusWidget> createState() => _MeshStatusWidgetState();
}

class _MeshStatusWidgetState extends State<MeshStatusWidget> {
  int _peers = 0;

  @override
  void initState() {
    super.initState();
    DittoService.instance.peerCount.listen((n) {
      if (mounted) setState(() => _peers = n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final connected = _peers > 0;
    final color = connected ? Colors.green : Colors.grey;
    final label = connected ? 'mesh: $_peers peer${_peers == 1 ? '' : 's'}' : 'mesh: alone';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
