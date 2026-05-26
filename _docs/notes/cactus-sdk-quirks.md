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
  — the purpose-built `qwen3-embedding-0.6` slug can't be resolved by
  the Flutter SDK 1.3.0 catalog despite being in the engine README.
  *Pair-cause with #34: explains why the embedder slot ended up
  holding a chat-tuned `qwen3-0.6` rather than the similarity-tuned
  slug.*

If #33 lands, the witness checklist's host-side-capture caveat goes
away. If #34 or #35 land, much of the cosine-distribution tuning the
retrieval pipeline absorbs may relax.

---

## What this list is NOT

Quirks of the Cactus SDK, not of the model. For model-side quirks
(bilingual CoT, citation omission, etc.), see
[`model-quirks.md`](model-quirks.md). For the on-device Ditto bugs
(queryMissingEmbedding, IS NULL trap), see [`dry-run-findings.md`](dry-run-findings.md)
if it exists, or the relevant fix commits.
