# Cactus 1.3.0 SDK quirks observed on-device

Companion to [`model-quirks.md`](model-quirks.md), but for the **SDK layer**
rather than the LLM weights. These are behaviors of the `cactus` Flutter
package itself — not of Qwen — that the demo had to work around or that the
writeup's *specialists vs generalists* thread cites as evidence.

For the broader thesis arc this connects to, see memory entry
`project_writeup_thesis_arc`.

---

## `Supabase.getModel` fires regardless of `isTelemetryEnabled` (R7 seam)

**What you'll see in logs:**

```
I/flutter (14549): [generateFlashcards] --- raw stream begin ---
I/flutter (14549): Error fetching model information: SocketException:
                   Failed host lookup: 'vlqqczxwyaodtcdmdmlw.supabase.co'
                   (OS Error: No address associated with hostname, errno = 7)
```

Triggered on every Cactus model resolution (first init per model slug). The
call is a GET to
`https://vlqqczxwyaodtcdmdmlw.supabase.co/functions/v1/get-models?slug=...&sdk_name=flutter&sdk_version=...`
sending the model slug, SDK name, and SDK version. In airplane mode it fails
with a SocketException and falls back to `ModelCache.loadModel(slug)`. Online,
the call succeeds and data leaves the device.

**Where it lives:**
[`lib/src/services/api/supabase.dart:135-158`](https://pub.dev/packages/cactus/versions/1.3.0)
inside cactus 1.3.0. Compare with the same file's `sendLogRecord` (line 19)
and `registerDevice` (line 97), which both early-return when
`CactusConfig.isTelemetryEnabled == false`. `getModel` has no such guard.

**Our app's pin:**
[`lib/services/cactus_service.dart:94`](../../lib/services/cactus_service.dart#L94)
sets `CactusConfig.isTelemetryEnabled = false` before any model init runs.
This kills the log-record path and the device-registration path, but not the
model-info lookup.

**Why the demo still holds R7 functionally:**
1. In airplane mode the DNS lookup fails before any payload leaves the
   device. The error is a `debugPrint`, not a thrown exception, so
   downstream flow continues via the local model cache.
2. Cactus weights are downloaded once (online boot) and cached locally; the
   getModel call returns from cache on subsequent boots when the cache is
   warm — but the *network attempt* still fires on every model init.

**Why the demo does NOT cleanly hold R7 evidentially:**
- A host-side packet capture during the recording window would observe an
  outbound DNS query for `vlqqczxwyaodtcdmdmlw.supabase.co`. Per
  [`tools/holdout_7/offline_witness.md`](../../tools/holdout_7/offline_witness.md),
  this is exactly the diagnostic the optional host-side capture path would
  surface.
- The witness's default (device-side status-bar evidence + airplane-mode
  toggle on camera) is the canonical R7 evidence because the network attempt
  fails closed. But it's worth disclosing in the writeup.

**The C++ side is safer.** `cactus_telemetry.h::sendToSupabase` is gated
behind `#ifdef CACTUS_TELEMETRY_ENABLED` (compile-time) and
`recordEvent` requires a non-empty telemetry token at runtime. So the
log-record / device-registration C++ paths are inert by default. The Dart
`getModel` is the only confirmed leak.

**Mitigations we considered and didn't take:**
1. **Patch the Cactus SDK.** Would diverge from pub.dev — needs a path
   dependency or a fork. Out of scope for the hackathon timeline.
2. **Pre-cache the model JSON and stub the SDK call.** Would require
   reflection into the SDK's `ModelCache`. The cache files already exist
   on-device after first online boot, so the natural mitigation is the
   one above: first-boot online once, then airplane.
3. **Block the host at the OS level.** `iptables` / Android per-app firewall
   on the phones. Possible, but not portable into the recorded artifact's
   "phone shows airplane mode" frame.

**For the writeup (specialists thread):**
A specialist on-device runtime would have **no model-registry concept** at
all — model weights would be a fixed asset baked into the package. The
generalist SDK ships a registry call because it's designed for arbitrary
model swaps from a cloud catalog. This is concrete evidence that "even with
the telemetry kill switch declared, the SDK assumes a cloud-backed catalog
by default" — exactly the texture the writeup wants to surface.

---

## Token callback `FormatException` on multi-byte UTF-8 boundaries

**What you'll see in logs (during a Qwen Chinese-CoT block):**

```
I/flutter: Token callback error: FormatException: Unfinished UTF-8 octet
           sequence (at offset 3)
I/flutter: Token callback error: FormatException: Unexpected extension byte
           (at offset 0)
I/flutter: Token callback error: FormatException: Missing extension byte
           (at offset 1)
```

The Cactus token-stream callback hands the Dart side a `String` that's been
naively decoded from a byte buffer at token boundaries. When the model emits
a Chinese character (3–4 bytes in UTF-8), the byte split can land *inside*
a code-point. Dart's UTF-8 decoder rejects the partial fragment and logs
the error — but the partial bytes are still rendered in the final assembled
string when the next callback completes the code-point.

**Where it lives:** Cactus FFI layer. Bytes are concatenated on the C++ side
and the Dart callback gets called per-token, not per-code-point.

**Our app's response:** absorbed silently. The final flashcard output still
parses cleanly because by the time `parseRaw` runs, the full byte stream has
been assembled and re-decoded. The error noise is informational only.

**Why it matters for the writeup:** another generalist-distribution artifact
— if Qwen never drifted into Chinese, these errors wouldn't fire. The
multi-byte UTF-8 boundary handling is the SDK's bug, but it's only triggered
by the bilingual CoT drift documented in `model-quirks.md`. The two quirks
compound.

---

## Filed upstream (2026-05-26)

Three issues opened against
[cactus-compute/cactus-flutter](https://github.com/cactus-compute/cactus-flutter)
covering the two seams above plus a third that explains why we ship a
chat-tuned model in the embedder slot:

- [**#33**](https://github.com/cactus-compute/cactus-flutter/issues/33)
  — `isTelemetryEnabled` is ignored by `getModel` / `fetchModels` /
  `fetchVoiceModels`. The flag honors `sendLogRecord` and
  `registerDevice` but not the model-catalog functions. Clean 3-line
  fix; security-relevant. *The seam this doc's first section
  describes.*
- [**#34**](https://github.com/cactus-compute/cactus-flutter/issues/34)
  — chat-tuned slugs (`qwen3-1.7`, `qwen3-0.6`) accept `embed()` and
  fail at runtime with cryptic code `-2` instead of refusing at
  registration. *The bug that forced this app into a two-model
  architecture — see [discussion #7](https://github.com/alycda/DittoXCactus/discussions/7).*
- [**#35**](https://github.com/cactus-compute/cactus-flutter/issues/35)
  — *originally filed as: "purpose-built `qwen3-embedding-0.6` slug
  can't be resolved by the Flutter SDK 1.3.0 catalog."*
  **Retracted 2026-05-26** — the slug we filed against does not exist;
  the actual dedicated embedder slug is **`qwen3-0.6-embed`** (suffix
  style), and on-device retest confirmed it loads + initializes
  end-to-end via Flutter SDK 1.3.0. The demo's default embedder was
  swapped to it per [issue #9](https://github.com/alycda/DittoXCactus/issues/9).
  See "Issue #35 retraction" section below.

If #33 lands, the witness checklist's host-side-capture caveat goes
away. If #34 lands, the chat-tuned slug accepting `embed()` no longer
matters because we no longer use it. #35 is closed as not-a-bug.

---

## Issue #35 retraction (2026-05-26)

The original quirk filed under #35 ("dedicated embedder slug doesn't load")
was wrong on two counts. Recording the truth so future readers don't re-file
the same bug.

**What we filed.** Issue #35 against `cactus-compute/cactus-flutter` claimed
the Flutter SDK 1.3.0 catalog couldn't resolve the slug
`qwen3-embedding-0.6` — that `CactusLM.downloadModel('qwen3-embedding-0.6')`
returned `Failed to get model qwen3-embedding-0.6`.

**What was actually happening.**

1. **The slug we used does not exist.** The Cactus catalog returns
   `{"error":"Model not found or is not live"}` for `qwen3-embedding-0.6`
   and a valid `CactusModel` object for **`qwen3-0.6-embed`** (suffix
   style, not prefix). The SDK was correctly reporting an unresolvable
   slug.
2. **The SDK's "Failed to get model" error also covers transient DNS
   failures.** First on-device retest produced exactly that error when
   `supabase.co` lookup briefly failed mid-boot. So one error string
   covers at least three failure modes — slug doesn't exist, network
   failed, or storage URL 404s (observed for some `*-pro` slugs).

**On-device retest (Pixel 6a, Flutter SDK 1.3.0)** with the corrected
slug `qwen3-0.6-embed`:

```
Downloading file from .../cactus-models/qwen3-0.6-embed.zip
Download completed successfully ... 61440ms
Initializing context with model: …/qwen3-0.6-embed, contextSize: 2048
[ColdLoadTimer] boot complete: { total_ms: 62440, … cactus_initialized: 62345 }
Generating embedding for text: Saturn
Received embedding result code: 1024
[topK] preThresholdScores=[0.417, 0.406, 0.388, 0.358, 0.353] ranked=5
```

End-to-end works: download (~60s for 394MB), extract, initialize, embed
(1024-dim), cosine ranking. Upstream PR comment added at
[#35-issuecomment-4551731987](https://github.com/cactus-compute/cactus-flutter/issues/35#issuecomment-4551731987).

**Demo state after retraction.** The default embedder slug in
`lib/services/cactus_service.dart` was swapped to `qwen3-0.6-embed` per
[issue #9](https://github.com/alycda/DittoXCactus/issues/9). Pre-computed
seed embeddings in `assets/seed_notes_*.json` were regenerated against
the new model via
[`tools/regen_seed_embeddings.py`](../../tools/regen_seed_embeddings.py).
U1 cross-platform baseline at `tools/determinism_harness/baselines/latest/`
was regenerated against the new slug.

---

## What this list is NOT

Quirks of the Cactus SDK, not of the model. For model-side quirks
(bilingual CoT, citation omission, etc.), see
[`model-quirks.md`](model-quirks.md). For the on-device Ditto bugs
(queryMissingEmbedding, IS NULL trap), see [`dry-run-findings.md`](dry-run-findings.md)
if it exists, or the relevant fix commits.
