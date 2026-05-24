/// Camera-legible "mesh: alone / mesh: N peer(s)" pill for the [QueryScreen]
/// AppBar.
///
/// The pill is the audience's single visible signal that the BLE handshake
/// succeeded — gray → green is what makes the R1 demo beat land. Styling
/// choices (monospace, ~16pt, fat dot, generous padding) exist because the
/// recording lens crops harder than the on-stage projector; legibility from
/// 6 m beats subtlety here.
///
/// Constructor takes the stream + initial count as injected dependencies so
/// widget tests can drive transitions deterministically without spinning up
/// the real `DittoService`.
library mesh_rag.widgets.mesh_status_widget;

import 'package:flutter/material.dart';

class MeshStatusWidget extends StatelessWidget {
  const MeshStatusWidget({
    super.key,
    required this.peerCountStream,
    this.initialCount = 0,
  });

  /// Live remote-peer count. Provided by `DittoService.peerCount` in the
  /// running app; tests inject a `StreamController<int>.stream`.
  final Stream<int> peerCountStream;

  /// Synchronous initial count, used while [peerCountStream] is awaiting its
  /// first event. `DittoService.currentPeerCount` is the production source.
  final int initialCount;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: peerCountStream,
      initialData: initialCount,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return _Pill(count: count);
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.count});
  final int count;

  bool get _isMeshed => count > 0;

  String get _label {
    if (!_isMeshed) return 'mesh: alone';
    if (count == 1) return 'mesh: 1 peer';
    return 'mesh: $count peers';
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _isMeshed ? Colors.green.shade600 : Colors.grey.shade500;
    final bgColor =
        _isMeshed ? Colors.green.shade50 : Colors.grey.shade200;
    final borderColor =
        _isMeshed ? Colors.green.shade300 : Colors.grey.shade400;
    return Semantics(
      label: _label,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
