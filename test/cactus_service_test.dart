// Pure-Dart pin tests for `CactusService`'s plan-locked default slugs.
//
// These constants are load-bearing across the determinism harness, the U13
// baseline check, and the seed JSON embeddings on disk. A silent rename
// would invalidate baselines/latest/* and pre-computed seed embeddings
// without any other test catching the drift. Mirrors the
// `RetrievalService.defaultK / defaultN` plan-locked-defaults test pattern.

import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_rag/services/cactus_service.dart';

void main() {
  group('CactusService plan-locked default slugs', () {
    test('preferredCompletionSlug pinned to qwen3-1.7', () {
      // Changing this invalidates the U13 baseline regression check.
      expect(CactusService.preferredCompletionSlug, 'qwen3-1.7');
    });

    test('preferredEmbeddingSlug pinned to qwen3-0.6-embed', () {
      // Swapped from chat-tuned qwen3-0.6 per issue #9 on 2026-05-26.
      // Changing this requires regenerating
      // assets/seed_notes_{a,b}.json (via tools/regen_seed_embeddings.py)
      // and tools/determinism_harness/baselines/latest/{iphone,pixel-*}.json.
      expect(CactusService.preferredEmbeddingSlug, 'qwen3-0.6-embed');
    });
  });
}
