/// Cold-load latency instrumentation for **Holdout 5 (R5)** — the demo
/// promises end-to-end app-launch-to-first-card in ≤ 10 seconds on the
/// slowest target device (Pixel 6a, release build).
///
/// **This file is the instrument, not the verdict.** The instrumentation
/// is mode-agnostic — it just records `Stopwatch.elapsedMilliseconds` at
/// named phase boundaries. The R5 *verification* (≤ 10 s assertion) only
/// holds in release mode; debug Flutter is JIT-compiled and 3-10x slower
/// than the AOT release build. The 10 s bar was set against the release
/// target.
///
/// **Known release-mode blocker (2026-05-25):** `ditto_live` 5.0.0
/// crashes Android in release mode; fix queued for 5.0.1 / 5.1. The R5
/// ≤ 10 s measurement is therefore deferred to one of:
///   - bump to a Ditto 5.0.x-rc that fixes the crash, OR
///   - iOS-only verification (bug is Android-only), OR
///   - wait for the upstream Ditto release.
///
/// The instrumentation lands now anyway: even in debug, the per-phase
/// numbers give relative visibility ("model load 5.2s vs Ditto init
/// 0.2s") that drives the H5 remediation playbook ordering even before
/// the absolute bar can be verified.
///
/// ## Usage
///
/// ```dart
/// void main() {
///   ColdLoadTimer.instance.start();
///   ColdLoadTimer.instance.mark('app_init_done');
///   runApp(...);
/// }
/// ```
///
/// And at each boot-phase boundary:
///
/// ```dart
/// await DittoService.instance.initialize();
/// ColdLoadTimer.instance.mark('ditto_initialized');
/// ```
///
/// At any point — `ColdLoadTimer.instance.report()` returns a JSON-shaped
/// `Map<String, dynamic>` with `device`, `total_ms`, and `phases`.
library mesh_rag.holdouts.cold_load_timer;

import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;

class ColdLoadTimer {
  ColdLoadTimer._();
  static final ColdLoadTimer instance = ColdLoadTimer._();

  /// Phase markers the boot path *should* hit in order. Used in the
  /// JSON report so consumers (and tests) can detect "boot didn't get
  /// past phase X" by checking which keys are present.
  ///
  /// Order is documentation only; [mark] accepts any phase name. The
  /// list is referenced by [test/holdouts/cold_load_timer_test.dart].
  static const List<String> expectedPhases = [
    'app_init_done',
    'ditto_initialized',
    'sync_started',
    'corpus_seeded',
    'cactus_completion_downloaded',
    'cactus_embedding_downloaded',
    'cactus_initialized',
    'embeddings_backfilled',
    'first_query_submitted',
    'first_top_k_returned',
    'first_card_buffered',
    'first_card_displayed',
  ];

  Stopwatch? _stopwatch;
  final Map<String, int> _phases = {};

  /// Begin a fresh cold-load measurement. Resets any prior phase data.
  /// Call once at app entry, right before `runApp`.
  void start() {
    _stopwatch = Stopwatch()..start();
    _phases.clear();
  }

  /// Record a phase boundary. No-op if [start] was never called (so
  /// hot-reload paths and integration-test setups don't blow up on a
  /// stray mark call). The first call to [mark] for a given phase wins
  /// — re-marking the same phase is ignored, so a boot retry doesn't
  /// overwrite the original timing.
  void mark(String phase) {
    final sw = _stopwatch;
    if (sw == null) return;
    if (_phases.containsKey(phase)) return;
    final elapsedMs = sw.elapsedMilliseconds;
    _phases[phase] = elapsedMs;
    if (kDebugMode) {
      debugPrint('[ColdLoadTimer] $phase: ${elapsedMs}ms');
    }
  }

  /// Snapshot the current measurement as a JSON-shaped Map. Safe to
  /// call multiple times (it doesn't stop the underlying Stopwatch).
  /// `total_ms` reflects elapsed-since-start at the moment of the
  /// report call, not at any phase boundary.
  Map<String, dynamic> report({String device = 'unknown'}) {
    final sw = _stopwatch;
    return buildReport(
      device: device,
      totalMs: sw?.elapsedMilliseconds ?? 0,
      phases: _phases,
    );
  }

  /// Reset the timer state. Mostly for test isolation; production
  /// callers should not need this (`start` resets too).
  @visibleForTesting
  void reset() {
    _stopwatch = null;
    _phases.clear();
  }

  /// True iff every name in [expectedPhases] has been marked.
  bool get hasCompletedAllExpectedPhases =>
      expectedPhases.every(_phases.containsKey);

  /// Pure builder for the JSON report. Separated from the timer state
  /// so tests can exercise the JSON shape with synthetic phase data,
  /// avoiding `dart:async`/Stopwatch flakiness. Mirrors the shape
  /// documented in plan §U14 Approach: `{ device, total_ms, phases }`.
  @visibleForTesting
  static Map<String, dynamic> buildReport({
    required String device,
    required int totalMs,
    required Map<String, int> phases,
  }) {
    return {
      'device': device,
      'total_ms': totalMs,
      'phases': Map<String, int>.from(phases),
    };
  }
}
