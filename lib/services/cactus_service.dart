/// Singleton wrapper around the two `CactusLM` instances the app uses —
/// one for completion (`qwen3-1.7`) and one for embedding (`qwen3-0.6-embed`).
///
/// ### Slug rationale (pinned by U6; surfaces here so the next reader doesn't
/// have to dig through the plan):
///
/// EmbeddingGemma 300M was the original embedding pick. We initially shipped
/// the chat-tuned `qwen3-0.6` because we believed the dedicated
/// `qwen3-embedding-0.6` slug "didn't load" — a claim that turned out to be a
/// slug typo on our side. The actual dedicated slug is **`qwen3-0.6-embed`**
/// (suffix style), and on-device retest on 2026-05-26 confirmed it loads
/// + initializes + produces 1024-dim embeddings via Flutter SDK 1.3.0
/// end-to-end. See `_docs/notes/cactus-sdk-quirks.md` § "Issue #35 retraction"
/// and discussion #11 / issue #9 for the full trail.
///
/// **U1 result.** Baselines under
/// `tools/determinism_harness/baselines/latest/` regenerated against this
/// slug on 2026-05-26/27 (Pixel A + B + iPhone 14). Cross-platform R2 gate
/// measured at **1.0000** (was 0.85 with chat-tuned head) — see that
/// directory's README for the audit trail.
///
/// `qwen3-0.6` was also tried as the completion model and produced incoherent
/// flashcards at ~600M parameters. `qwen3-1.7` is the size class that
/// produces coherent cards while still loading under the R5 cold-load budget
/// on the chosen hardware pair.
///
/// The two LMs are independent CactusLM instances because Cactus' Flutter
/// 1.3.0 surface doesn't expose a "single context, two roles" mode.
library mesh_rag.services.cactus_service;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../holdouts/cold_load_timer.dart';

/// Thrown when [CactusService.initialize] is called with `useSpecialist: true`
/// but the bundled `.cact` asset is missing from the build. Distinct from
/// generic init failures so BootScreen can render specialist-specific guidance
/// (`run convert.sh` / `disable USE_SPECIALIST`) instead of "model failed to
/// load."
class MissingSpecialistAssetException implements Exception {
  MissingSpecialistAssetException(this.assetPath);
  final String assetPath;
  @override
  String toString() =>
      'MissingSpecialistAssetException: $assetPath. Build with USE_SPECIALIST=true '
      'requires the merged specialist .cact at $assetPath. Run '
      '`bash tools/specialist_training/convert.sh` to produce it, OR rebuild '
      'without USE_SPECIALIST to use the generalist base.';
}

/// Phase label routed through [CactusService.initialize]'s `onProgress`
/// callback. The BootScreen renders this verbatim, so phrasing should be
/// stable enough that a screenshot of demo-day boot reads the same as a
/// dev-time boot.
typedef CactusProgressLabel = void Function(
  double? progress,
  String status,
  bool isError,
);

/// Stop sequences applied to every completion call. Halts generation
/// the moment the model starts drifting into well-documented quirks
/// that are never legitimate in our Q:/A:/SOURCE: output:
///
///   - `\boxed` — Qwen 2.5 was heavily trained on the MATH dataset
///     and reaches for `\boxed{...}` as a "final answer" delimiter
///     whenever it interprets structured-output prompts as math-mode.
///     See `_docs/notes/model-quirks.md` LaTeX section. The prompt
///     explicitly forbids LaTeX; the model still emits it. Stop
///     sequences are the structural backstop the prompt rule isn't.
///   - `\begin{aligned}` — LaTeX math-display environment opener.
///     Same root cause as `\boxed`. Always followed by garbage.
///   - `\text{` — math-mode text wrapper Qwen reaches for inside
///     a `\boxed{}` body. Catching this earlier than `\boxed`
///     covers the variants the model sometimes inverts the order on.
///
/// Pinned by `feedback_structural_gates`: on small-model paths, gate
/// at the model layer (here) rather than detecting drift at the parse
/// layer (cleanCards). Stop sequences are honored by Cactus's C++
/// context — see cactus 1.3.0 `src/services/context.dart:421`.
const List<String> _kDefaultStopSequences = [
  r'\boxed',
  r'\begin{aligned}',
  r'\text{',
];

class CactusService {
  CactusService._();
  static final CactusService instance = CactusService._();

  /// Default completion slug — used when no override is passed to
  /// [initialize]. The U13 baseline.json pins to this exact value;
  /// changing it invalidates U13's regression check.
  static const String preferredCompletionSlug = 'qwen3-1.7';

  /// Default embedding slug — dedicated similarity-tuned embedder.
  /// Swapped from chat-tuned `qwen3-0.6` per issue #9 once the slug typo
  /// in `cactus-sdk-quirks.md` was retracted (the dedicated slug always
  /// worked; we just had the name wrong).
  /// `assets/seed_notes_{a,b}.json` embeddings were regenerated against
  /// this model via `tools/regen_seed_embeddings.py`.
  ///
  /// Changing this requires regenerating
  /// assets/seed_notes_{a,b}.json (via tools/regen_seed_embeddings.py)
  /// and tools/determinism_harness/baselines/latest/{iphone,pixel-*}.json.
  static const String preferredEmbeddingSlug = 'qwen3-0.6-embed';

  /// Slug used when [initialize] is called with `useSpecialist: true`. The
  /// merged `.cact` blob produced by `tools/specialist_training/convert.sh`
  /// (U6) is copied from the Flutter asset bundle into
  /// `<documents>/models/<specialistCompletionSlug>/` at boot so Cactus's
  /// `initializeModel` finds it locally without invoking
  /// `downloadModel`. The slug is otherwise unregistered in Cactus's remote
  /// catalog — that's intentional. If Cactus's catalog ever gains a model
  /// with this same name, rename the constant to keep them disjoint.
  static const String specialistCompletionSlug = 'qwen3-1.7-merger';

  /// Flutter asset path where the bundled specialist `.cact` lives. The
  /// `convert.sh` wrapper writes `assets/models/qwen3-1.7-merger.cact`;
  /// `pubspec.yaml` bundles the `assets/models/` directory. Missing-asset
  /// behavior is governed by [MissingSpecialistAssetException].
  static const String specialistAssetPath =
      'assets/models/qwen3-1.7-merger.cact';

  final CactusLM _completionLm = CactusLM();
  final CactusLM _embeddingLm = CactusLM();

  bool _initialized = false;
  bool _specialistLoaded = false;
  int _embeddingDimension = 0;
  String _activeCompletionSlug = preferredCompletionSlug;
  String _activeEmbeddingSlug = preferredEmbeddingSlug;

  bool get isInitialized => _initialized;

  /// True when [initialize] was called with `useSpecialist: true` and the
  /// merged specialist `.cact` was successfully staged + loaded. Driven by
  /// boot flow + surfaced for DemoOverlay HUD inspection and for the
  /// recorded-artifact integration tests.
  bool get isSpecialistLoaded => _specialistLoaded;

  /// The dimension of the embedding head, captured on the first successful
  /// [embed] call. Useful for retrieval (U9) to detect a mid-corpus model
  /// swap at the top-k boundary (drops mismatched rows rather than
  /// crashing).
  int get embeddingDimension => _embeddingDimension;

  String get activeCompletionSlug => _activeCompletionSlug;
  String get activeEmbeddingSlug => _activeEmbeddingSlug;

  /// Download + initialize both models sequentially.
  ///
  /// `onProgress` (if supplied) receives messages like:
  ///   - `completion (qwen3-1.7): downloading 42%` (with `progress=0.42`)
  ///   - `completion (qwen3-1.7): initializing context` (with `progress=null`)
  ///   - `embedding (qwen3-0.6-embed): downloading 8%`
  /// `isError=true` surfaces a download failure so BootScreen can render a
  /// "connect to wifi to fetch the model" message instead of crashing.
  ///
  /// Idempotent: repeated calls after the first are no-ops.
  ///
  /// `useSpecialist=true` swaps the completion model for the merged
  /// specialist `.cact` bundled at [specialistAssetPath]. The embedding
  /// model is unchanged — note-merging is the completion-side specialty;
  /// embeddings still use `qwen3-0.6-embed` so existing seed embeddings
  /// + R2 baselines stay valid. `useSpecialist=true` is mutually exclusive
  /// with `completionSlugOverride`; passing both throws [ArgumentError].
  Future<void> initialize({
    String? completionSlugOverride,
    String? embeddingSlugOverride,
    int contextSize = 2048,
    bool useSpecialist = false,
    CactusProgressLabel? onProgress,
  }) async {
    if (_initialized) return;

    if (useSpecialist && completionSlugOverride != null) {
      throw ArgumentError(
        'useSpecialist and completionSlugOverride are mutually exclusive. '
        'Use one or the other — the specialist path bypasses the slug catalog.',
      );
    }

    // Kill telemetry BEFORE any model-download HTTP fires. SDK default is
    // true; airplane-mode demo discipline (R7) makes this behaviorally
    // moot, but the explicit pin closes the loop for U15b's offline
    // witness check.
    CactusConfig.isTelemetryEnabled = false;

    final eSlug = embeddingSlugOverride ?? preferredEmbeddingSlug;
    _activeEmbeddingSlug = eSlug;

    if (useSpecialist) {
      // Specialist path — stage the bundled .cact into Cactus's
      // documents-dir model folder so initializeModel finds it locally
      // (skips downloadModel). Mirrors Cactus 1.3.0's on-disk layout:
      // <documents>/models/<slug>/<slug>.cact.
      onProgress?.call(null, 'specialist ($specialistCompletionSlug): staging asset', false);
      await _stageSpecialistAsset(onProgress: onProgress);
      _activeCompletionSlug = specialistCompletionSlug;
      ColdLoadTimer.instance.mark('cactus_specialist_staged');
    } else {
      final cSlug = completionSlugOverride ?? preferredCompletionSlug;
      _activeCompletionSlug = cSlug;
      // Phase 1/4 — download completion weights.
      await _completionLm.downloadModel(
        model: cSlug,
        downloadProcessCallback: (p, status, isError) =>
            onProgress?.call(p, 'completion ($cSlug): $status', isError),
      );
      ColdLoadTimer.instance.mark('cactus_completion_downloaded');
    }

    // Phase 2/4 — download embedding weights.
    await _embeddingLm.downloadModel(
      model: eSlug,
      downloadProcessCallback: (p, status, isError) =>
          onProgress?.call(p, 'embedding ($eSlug): $status', isError),
    );
    ColdLoadTimer.instance.mark('cactus_embedding_downloaded');

    // Phase 3/4 — initialize completion context (mmaps weights into RAM).
    onProgress?.call(
      null,
      'completion ($_activeCompletionSlug): initializing context',
      false,
    );
    await _completionLm.initializeModel(
      params: CactusInitParams(
        model: _activeCompletionSlug,
        contextSize: contextSize,
      ),
    );

    // Phase 4/4 — initialize embedding context.
    onProgress?.call(null, 'embedding ($eSlug): initializing context', false);
    await _embeddingLm.initializeModel(
      params: CactusInitParams(model: eSlug, contextSize: contextSize),
    );

    _initialized = true;
    _specialistLoaded = useSpecialist;
    onProgress?.call(
      1.0,
      useSpecialist ? 'specialist ready' : 'both models ready',
      false,
    );
  }

  /// Copy the bundled specialist `.cact` from the Flutter asset bundle into
  /// Cactus's expected on-disk layout at `<documents>/models/<slug>/`.
  /// Idempotent — skips the copy if the destination file already exists
  /// at the expected size. Throws [MissingSpecialistAssetException] when
  /// the asset isn't in the bundle (build was made without producing the
  /// `.cact` via convert.sh).
  Future<void> _stageSpecialistAsset({
    CactusProgressLabel? onProgress,
  }) async {
    final ByteData bytes;
    try {
      bytes = await rootBundle.load(specialistAssetPath);
    } on FlutterError {
      throw MissingSpecialistAssetException(specialistAssetPath);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final modelFolder = Directory(
      '${docsDir.path}/models/$specialistCompletionSlug',
    );
    await modelFolder.create(recursive: true);
    final modelFile = File(
      '${modelFolder.path}/$specialistCompletionSlug.cact',
    );

    final bundleSize = bytes.lengthInBytes;
    if (await modelFile.exists()) {
      final existing = await modelFile.length();
      if (existing == bundleSize) {
        // Already staged at the right size — skip the copy.
        onProgress?.call(
          null,
          'specialist ($specialistCompletionSlug): cached',
          false,
        );
        return;
      }
    }

    onProgress?.call(
      0.0,
      'specialist ($specialistCompletionSlug): copying ${bundleSize ~/ (1024 * 1024)} MB',
      false,
    );
    await modelFile.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    onProgress?.call(
      1.0,
      'specialist ($specialistCompletionSlug): staged',
      false,
    );
  }

  // ───── Embedding ───────────────────────────────────────────────────────

  /// Embed `text` into a `List<double>` of length [embeddingDimension].
  ///
  /// Throws [StateError] if [initialize] hasn't completed, if `text` is
  /// empty (Cactus' `generateEmbedding` returns `success=false` on empty
  /// input — documenting the failure here so callers don't pass empty
  /// queries through), or if the underlying Cactus call fails.
  Future<List<double>> embed(String text) async {
    _requireInitialized();
    if (text.isEmpty) {
      throw StateError('CactusService.embed: called with empty text.');
    }
    final r = await _embeddingLm.generateEmbedding(text: text);
    if (!r.success) {
      throw StateError(
          'CactusService.embed: ${r.errorMessage ?? 'unknown failure'}');
    }
    _embeddingDimension = r.dimension;
    return r.embeddings;
  }

  /// Same as [embed] but materializes the result as `Float32List` — the
  /// shape the cosine hot path in [RetrievalService.topK] (U9) wants.
  Future<Float32List> embedF32(String text) async {
    final list = await embed(text);
    return Float32List.fromList(list);
  }

  // ───── Completion ──────────────────────────────────────────────────────

  /// Stream a completion for `messages`. Pinned to [CompletionMode.local];
  /// the SDK default is local but the explicit pin prevents a future SDK
  /// default-change from silently switching to hybrid (which would breach
  /// R9's "no cloud" invariant).
  ///
  /// Returns a single-subscription [Stream] that yields token strings as
  /// they decode. Callers (U11's `RetrievalService.generateFlashcards`)
  /// concat the chunks and parse once the stream completes.
  Stream<String> complete(
    List<ChatMessage> messages, {
    int maxTokens = 256,
    List<String> stopSequences = const [],
  }) async* {
    _requireInitialized();
    final streamed = await _completionLm.generateCompletionStream(
      messages: messages,
      params: CactusCompletionParams(
        maxTokens: maxTokens,
        completionMode: CompletionMode.local,
        stopSequences: [
          ..._kDefaultStopSequences,
          ...stopSequences,
        ],
      ),
    );
    yield* streamed.stream;
  }

  /// Non-streaming variant for evals and tests — collects the full
  /// response into a single string. Not on the demo UI hot path.
  Future<String> completeAll(
    List<ChatMessage> messages, {
    int maxTokens = 256,
    List<String> stopSequences = const [],
  }) async {
    _requireInitialized();
    final r = await _completionLm.generateCompletion(
      messages: messages,
      params: CactusCompletionParams(
        maxTokens: maxTokens,
        completionMode: CompletionMode.local,
        stopSequences: [
          ..._kDefaultStopSequences,
          ...stopSequences,
        ],
      ),
    );
    if (!r.success) {
      throw StateError('CactusService.completeAll: ${r.response}');
    }
    return r.response;
  }

  void _requireInitialized() {
    if (!_initialized) {
      throw StateError('CactusService used before initialize() completed.');
    }
  }
}
