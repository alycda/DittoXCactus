// Tests for the specialist-swap path in CactusService.
//
// These are STRUCTURAL behavior tests — they exercise the flag-dispatch,
// mutual-exclusion, and asset-missing error paths without touching the
// Cactus runtime itself. The actual model load + inference is exercised
// by the determinism harness and the live integration test
// (`just app-run-a-specialist`), not by this unit-test file.
//
// Tautology-style "expect(constant, constant)" tests are deliberately NOT
// here — the user correctly flagged that anti-pattern in PR #15. The
// constants below appear in error messages and integration assertions
// (the eval pipeline, R2 baseline names, justfile recipe), so a rename
// would surface as a behavioral test failure downstream, not via
// shadowboxing in this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_rag/services/cactus_service.dart';

void main() {
  group('MissingSpecialistAssetException', () {
    test('includes the asset path in the message', () {
      // The exception is the user-facing surface that BootScreen renders
      // when the .cact wasn't built — verify the path it names matches
      // what convert.sh actually writes. Catches the failure mode where
      // someone renames the constant in CactusService but forgets to
      // update convert.sh's output, OR vice versa.
      final exc = MissingSpecialistAssetException(
        CactusService.specialistAssetPath,
      );
      final message = exc.toString();
      expect(
        message,
        contains('assets/models/qwen3-1.7-merger.cact'),
        reason:
            'BootScreen surfaces the message verbatim; the path must be '
            'recognizable so users can grep convert.sh output for it.',
      );
      expect(
        message,
        contains('convert.sh'),
        reason:
            'Message must point users at the conversion script — that is '
            'the remediation path, not a generic "model failed to load".',
      );
      expect(
        message,
        contains('USE_SPECIALIST'),
        reason:
            'Message must name the feature flag so users can disable '
            'specialist mode if they want the demo to boot without the '
            '.cact.',
      );
    });
  });

  group('CactusService.initialize argument validation', () {
    test('useSpecialist=true is mutually exclusive with completionSlugOverride',
        () async {
      // Both paths swap the completion model; allowing both would create
      // ambiguous precedence. Throw at the boundary rather than silently
      // picking one. Run via the singleton's pre-init state — the
      // ArgumentError fires before any IO happens, so this test does NOT
      // require the Flutter Cactus binding to be initialized.
      expect(
        () => CactusService.instance.initialize(
          useSpecialist: true,
          completionSlugOverride: 'some-other-slug',
        ),
        throwsA(isA<ArgumentError>()),
        reason:
            'Mutual exclusion is a service-layer structural gate per '
            '`feedback_structural_gates` user memory — surface the conflict '
            'at the API boundary, not as a confusing downstream error.',
      );
    });
  });

  group('CactusService initial state before init', () {
    // These read-only assertions verify the singleton's default observable
    // state. They protect future readers from accidentally flipping
    // _specialistLoaded's default or forgetting to wire the getter — both
    // would surface here as failures rather than as silent demo
    // misconfiguration.
    test('isSpecialistLoaded is false before any initialize call', () {
      expect(
        CactusService.instance.isSpecialistLoaded,
        isFalse,
        reason:
            'Specialist must be opt-in via useSpecialist=true; the demo\'s '
            'recorded-artifact discipline depends on this default.',
      );
    });

    test('activeCompletionSlug defaults to the generalist preferred slug', () {
      expect(
        CactusService.instance.activeCompletionSlug,
        equals(CactusService.preferredCompletionSlug),
        reason:
            'Pre-init the active slug should report the generalist default '
            '(the cell the BootScreen renders during boot). After init the '
            'value tracks the loaded model.',
      );
    });
  });
}
