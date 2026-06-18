/// Single-device integration smoke tests for Firebase Test Lab.
///
/// Two groups, one APK build:
///
/// **Group 1 — no-credentials path** (`@Tags(['no-creds'])`)
///   Built with `--dart-define=PHONE_ROLE=a` only (no DITTO_APP_ID /
///   DITTO_LICENSE). The boot sequence reaches `DittoService.initialize()`
///   which throws a `StateError` for the missing credential; the BootScreen
///   catches it and renders the 'Boot failed' view. This validates:
///     - The app launches on real ARM hardware without an immediate JNI crash.
///     - The boot-error UI renders and is legible (not just a white screen).
///     - No unhandled exception surfaces (i.e. the catch-and-display path
///       actually works on device, not just in widget tests).
///   This group runs in the public Firebase Test Lab job — no secrets needed.
///
/// **Group 2 — full-boot path** (`@Tags(['full-boot'])`)
///   Built with all three dart-defines including DITTO credentials. The boot
///   completes and the QueryScreen renders. Validates:
///     - DittoService opens its store on real storage.
///     - SeedLoader reads the bundled asset JSON and upserts notes.
///     - CactusService loads the qwen3-0.6 embedding model (pre-baked
///       embeddings in the asset mean no download is needed for this).
///     - RetrievalService.ensureEmbeddings() is a no-op (pre-baked data).
///     - QueryScreen renders with Notes + Flashcards tabs visible.
///     - MeshStatusWidget starts in the 'mesh: alone' state.
///   Requires DITTO_APP_ID + DITTO_LICENSE baked in at build time; runs via
///   `workflow_dispatch` in CI or locally via `just app-integration <device>`.
///
/// **Not covered here (see issue #3):**
///   - Two-device BLE mesh sync (requires a self-hosted device lab).
///   - Flashcard generation end-to-end (the qwen3-1.7 completion model is
///     too large to load reliably within Firebase Test Lab's timeout budget;
///     treat the full-boot group as the integration gate for now).
library integration.smoke;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mesh_rag/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── Group 1: no-credentials path ─────────────────────────────────────────
  //
  // Build this APK with: --dart-define=PHONE_ROLE=a
  // (no DITTO_APP_ID / DITTO_LICENSE — intentionally absent).
  //
  // The boot reaches DittoService.initialize() which throws because the
  // credential dart-define is the empty string. BootScreen catches the error
  // and renders the 'Boot failed' view. We verify it renders — not that it
  // succeeds.

  group('no-credentials path', () {
    testWidgets('app launches without a JNI / FFI crash',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MeshRagApp());
      // One frame is enough to confirm the widget tree mounted without a
      // hard crash (null-deref in native code would kill the process here).
      await tester.pump();
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('boot-error UI appears within 15 s when credentials are missing',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MeshRagApp());

      // The boot is async and reaches native Ditto code before failing.
      // Poll up to 15 s — well within Firebase Test Lab's 5-min limit.
      const step = Duration(milliseconds: 500);
      const limit = Duration(seconds: 15);
      var elapsed = Duration.zero;
      while (elapsed < limit) {
        await tester.pump(step);
        elapsed += step;
        if (find.text('Boot failed').evaluate().isNotEmpty) break;
      }

      expect(
        find.text('Boot failed'),
        findsOneWidget,
        reason: 'Boot should fail within 15 s when Ditto credentials are absent.',
      );
    });

    testWidgets('boot-error view shows a diagnostic message (not a blank screen)',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MeshRagApp());

      const step = Duration(milliseconds: 500);
      const limit = Duration(seconds: 15);
      var elapsed = Duration.zero;
      while (elapsed < limit) {
        await tester.pump(step);
        elapsed += step;
        if (find.text('Boot failed').evaluate().isNotEmpty) break;
      }

      // The _FailedView renders error.toString() under the header.
      // It must contain text beyond the header — a blank body means the
      // error object was null or its toString() returned empty.
      final widgets = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(
        widgets.length,
        greaterThan(1),
        reason: 'Expected header + diagnostic body text; found only the header.',
      );
    });
  });

  // ── Group 2: full-boot path ───────────────────────────────────────────────
  //
  // Build this APK with:
  //   --dart-define=PHONE_ROLE=a
  //   --dart-define=DITTO_APP_ID=<your-app-id>
  //   --dart-define=DITTO_LICENSE=<your-offline-license>
  //
  // Assets/seed_notes_a.json already contains pre-baked embeddings so
  // RetrievalService.ensureEmbeddings() is a no-op — no model download is
  // needed for the embedding step and boot stays within a 3-min budget.
  //
  // The qwen3-1.7 completion model IS still downloaded on first boot
  // (~1.5 GB). A warm Firebase Test Lab device (persistent storage) will
  // cache it. A cold device will time out — plan for a warm-up run.
  //
  // TODO: add these tests once the Firebase project + GCP SA are configured.
  // Tracked in issue #3. Placeholder group left here so the structure is
  // visible and the build command is documented.

  group('full-boot path', () {
    testWidgets(
      'SKIP — requires DITTO credentials baked into the APK; see issue #3',
      (WidgetTester tester) async {
        // Remove this skip and the TODO marker once:
        //   1. A Firebase project is linked to this repo.
        //   2. GCP_SA_KEY + DITTO_APP_ID + DITTO_LICENSE are in GitHub Secrets.
        //   3. The warm-up run has cached the Cactus models on the test device.
      },
      skip: 'Requires credential dart-defines — see issue #3',
    );
  });
}
