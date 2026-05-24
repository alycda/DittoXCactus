// Minimal host app for the U1 determinism gate. The interesting work happens
// in integration_test/measure_test.dart — this entry exists only so Flutter's
// integration_test runner has an Android/iOS package to install on the device.
//
// Run the measurement:  flutter test integration_test/measure_test.dart -d <device>

import 'package:flutter/material.dart';

void main() => runApp(const _HarnessApp());

class _HarnessApp extends StatelessWidget {
  const _HarnessApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Determinism Harness',
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Determinism Harness',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                SizedBox(height: 12),
                Text(
                    'This binary is the U1 pre-flight gate host. The measurement '
                    'runs via the integration_test harness, not this UI.\n\n'
                    'flutter test integration_test/measure_test.dart -d <device>'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
