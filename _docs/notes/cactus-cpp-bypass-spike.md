# Spike: load a non-catalog model via Cactus's C++ runtime

**Branch:** `spike-tinyllama-cactus`. **Date:** 2026-05-26. **Status:**
mechanism proven, model choice was wrong; architectural finding documented.

## Goal

Validate that we can run a model on the Cactus engine *without it being in
the Cactus Flutter catalog*. The hypothesis was that the C++ engine has
broader model coverage than the SDK's catalog exposes — specifically that
`engine_model.cpp:548` recognizes `tinyllama` as a `ModelType::GEMMA4`
mapping, suggesting TinyLlama / TinyDolphin should be runnable via the
custom-path init route.

## What works (the bypass mechanism)

End-to-end from a HuggingFace repo ID to a running model in three steps:

1. **Convert**: Cactus's Python converter produces a custom-format bundle
   (`.weights` + `.scale` files per layer) from any standard HF causal-LM
   repo. Confirmed on `TinyLlama/TinyLlama-1.1B-Chat-v1.0`:

   ```
   $ PYTHONPATH=. python -m src.cli convert TinyLlama/TinyLlama-1.1B-Chat-v1.0
   Loading weights: 100%|██████████| 201/201
   Quantization Summary:
     MSE - Mean: 6.18e-06, Max: 3.40e-05
     CosSim - Mean: 0.995046, Max: 0.999950
   Processed 1 INT8 tensors, 155 INT4 tensors, 45 FP16 tensors
   Successfully downloaded and converted weights to weights/tinyllama-1.1b-chat-v1.0
   ```

   Quant fidelity is good (mean cosine 0.995). The converter works on any
   HF-architecture-recognized model — `LlamaForCausalLM`, `GemmaForCausalLM`,
   `Qwen2ForCausalLM` etc.

2. **Load**: `cactus_init('/path/to/converted/dir', '', False)` loads any
   converted bundle regardless of whether the slug is in the Cactus catalog.
   The C++ engine path doesn't care about catalog membership.

3. **Run**: `cactus_complete(model, messages_json, options_json, ...)` produces
   inference. Throughput on TinyLlama 1.1B (M-series Mac, INT4): **568 tok/s
   prefill, 106 tok/s decode** — measurably faster than the Qwen3-1.7B
   incumbent (314/44 tok/s in T1-Cactus) but only on numerical throughput, not
   on output quality.

## What doesn't work (the architectural obstacle)

**Cactus's engine assumes QK-norm tensors exist in every Llama-class
loader.** Source-confirmed:

| Loader | File | Line |
| --- | --- | --- |
| `model_qwen.cpp` | `attn_q_norm_weight = gb->mmap_weights(...)` | 37 |
| `model_gemma.cpp` | `attn_q_norm_weight = gb->mmap_weights(...)` | 41 |
| `model_lfm2moe.cpp` | `attn_q_norm_weight = mmap_or_throw(..., false)` | 133 |

Each loader then unconditionally calls `gb->rms_norm(q_proj, q_norm_weight, ...)`
during attention. If the tensor file is missing, `mmap_weights` throws and
load fails with:

```
[ERROR] [init] Exception during init: Cannot open file for mapping:
       .../layer_0_attn_q_norm.weights
```

TinyLlama 1.1B (2023) predates the QK-norm convention. The same applies to
**original Llama 1 / 2**, **Mistral 7B v0.1**, **Phi-2**, **TinyDolphin** (a
TinyLlama fine-tune, so inherits the same architecture), and most pre-2024
open Llama-class checkpoints.

The engine's `tinyllama → ModelType::GEMMA4` mapping at `engine_model.cpp:548`
is a *string-level recognition without a matching loader* — `ModelType::GEMMA4`
uses the Gemma 3n loader, which expects `embed_tokens_per_layer.weights` (a
Gemma 3n MoE-style file TinyLlama doesn't have). So even the "official"
TinyLlama → GEMMA4 routing fails on a different missing file. There is no
working TinyLlama loader path in the current C++ engine.

## The identity-scale QK-norm hack

Out of curiosity, I synthesized `layer_*_attn_q_norm.weights` and
`layer_*_attn_k_norm.weights` files containing FP16 ones-tensors of shape
`(head_dim,)`. RMSNorm with an identity scale is just RMS normalization;
inserting it doesn't add learnable parameters, just normalizes Q and K
vectors before attention scoring.

Result: **the model loads and runs, but output is incoherent.**

```
$ cactus_complete("What is the capital of France? Answer in one word.")
<0x0A><0x0A><0x0A><0x0A><0x0A><0x0A><|system|system|ass><0x0A><|assistant><0x0A>2><0x0A>2><0x0A>
```

Two failure modes compound:

1. **Attention-temperature shift.** TinyLlama's pretrained attention scores
   are calibrated against unnormalized Q/K vectors. Adding an RMS
   normalization step in front (even with identity scale) changes the
   relative magnitudes of attention logits. The model wasn't trained to
   handle this; token distribution is corrupted.
2. **Chat-template mismatch.** The QWEN-class loader's tokenizer and chat
   template format use `<|im_start|>` / `<|im_end|>` markers. TinyLlama's
   chat template uses Llama 2's `<|system|>` / `<|user|>` / `<|assistant|>`.
   The byte tokens (`<0x0A>` = `\n`) and the `<|system|>` / `<|assistant|>`
   leakage in the output are template-side, not architecture-side.

So the hack satisfies the loader but doesn't produce usable output — the
engine *will* run an architecturally-incompatible model, but the result is
garbage.

## What it would take to actually run TinyLlama

Two clean fixes, in increasing order of effort:

1. **Patch the C++ engine to make q_norm/k_norm optional.** Three-file
   change: in each of `model_qwen.cpp`, `model_gemma.cpp`, `model_lfm2moe.cpp`,
   guard the `mmap_weights` call with a "if file exists" check and skip the
   `gb->rms_norm(...)` op when null. The Python converter would also need a
   matching branch that doesn't emit q_norm/k_norm files for pre-QK-norm
   models. This is "right way" engineering — Cactus's API surface stays
   honest about what its loaders actually support.

2. **Add a dedicated `model_llama.cpp` loader.** Mirror `model_qwen.cpp`
   structurally, drop the QK-norm step, handle Llama-1/2-era chat templates.
   This is a real PR to upstream. Worth doing if Llama 1/2-class models are
   important; less worth doing if everyone moves to Llama 3.x (which has
   QK-norm anyway).

A third path — **skip TinyLlama, use a modern Llama-class model that already
has QK-norm** — is what the demo would do in practice. Modern candidates:

- **Llama 3.2 1B** (gated; needs HF token + Meta license).
- **SmolLM 2** family (HuggingFace; ungated; already in the Cactus catalog
  as `smollm2-360m`, so it'd defeat the "off-catalog" purpose).
- **Phi-3-mini** (Microsoft; ungated; not in the catalog).
- **Granite 4 Tiny** (IBM; Apache-2.0; not in the catalog).

For "demonstrate the C++ bypass with a model that's both off-catalog AND
actually produces coherent output," **Phi-3-mini** or **Granite 4 Tiny** are
the cleanest follow-ups. Neither was tried in this spike because the
*architectural finding* answers the original question: yes, the bypass
works; no, TinyLlama specifically doesn't load coherently because of the
engine's QK-norm assumption.

## Tooling sub-finding: Cactus's bundled venv is broken

`cactus convert <hf-id>` with the brew-installed CLI hits this error
consistently:

```
Error: Could not import module 'LlamaForCausalLM'. Are this object's
requirements defined correctly?
```

Root cause inside `/opt/homebrew/Cellar/cactus/1.14_1/libexec/venv`:
**torchvision is installed but its C extension is incompatible with the
installed torch 2.12.0** (`RuntimeError: operator torchvision::nms does not
exist`). Importing `transformers.models.llama` transitively imports
torchvision, which then fails to load.

**Workaround used in this spike:** built a separate Python 3.11 venv at
`/tmp/cactus-convert-venv` with fresh transformers + torch (no torchvision)
and ran `python -m src.cli convert ...` from there with `PYTHONPATH` set
to the cloned Cactus python source. Output bundle lands in the brew
location regardless and is then loadable via the brew binary's
`libcactus.dylib`.

**Filing-worthy upstream issue:** *cactus brew formula ships an incompatible
torchvision/torch pair; uninstalling torchvision in the formula's venv
would fix `cactus convert` for any HF causal-LM model.* Two-line fix in the
Homebrew formula.

## Spike artifacts (not committed; in `_inspiration/` or `/tmp/`)

- `_inspiration/cactus-compute/cactus/weights/tinyllama-1.1b-chat-v1.0/` —
  converted bundle. 208 files. INT4 default. Gitignored.
- `/tmp/cactus-convert-venv/` — isolated Python venv that can run the
  converter. Reproducible.
- `/tmp/synth_qk_norm.py` — the identity-scale-norm hack script. ~30 lines.

## Recommendation

**Don't add TinyLlama / TinyDolphin to the demo.** The model itself loads
through the bypass mechanism, but it doesn't produce coherent output without
an upstream engine patch. The *interesting* spike result is the
architectural finding ("Cactus assumes QK-norm everywhere") — that goes in
the writeup as another concrete instance of the on-device-AI-runtime
maturity gap.

**Two specific upstream PRs the spike surfaced as good filings:**

1. `cactus-compute/cactus` — make `attn_q_norm` / `attn_k_norm` optional in
   the three Llama-class loaders. Unlocks ~6 years of pre-QK-norm
   open-source models for the engine.
2. `cactus-compute/cactus` (Homebrew formula side) — remove torchvision
   from the bundled venv (or pin a compatible version). Unblocks
   `cactus convert` on Mac for arbitrary HF causal-LM models.

**One follow-up spike worth scheduling**, if "off-catalog model demonstration"
is still wanted for the writeup: run Phi-3-mini or Granite 4 Tiny through the
same convert → init → complete path. Both have QK-norm, both are ungated,
both should produce coherent output through the existing engine. That'd
give the writeup a *working* example of the C++ bypass instead of just an
architectural-finding result.

---

## Update 2026-05-26 (later that day) — Phi-3 + Granite + Llama 3.2

Tried the three off-catalog candidates the previous section's "follow-up
spike" pitched. **The QK-norm gap is wider than I assumed** — Granite 3.1
also lacks it, Phi-3 wouldn't even convert, Llama 3.2 is gated *and* likely
shares the same architecture gap. None produced coherent output.

| Candidate | HF ID | Result |
| --- | --- | --- |
| Phi-3 Mini 3.8B | `microsoft/Phi-3-mini-4k-instruct` | **Convert failed**: cryptic `Error: 'type'` after fetching weights. Cactus's Python converter doesn't handle Phi-3's HF config schema (Phi-3 uses some unusual fields — `rope_scaling.type` or similar). |
| Granite 3.1 2B | `ibm-granite/granite-3.1-2b-instruct` | Convert ✓ (`Warning: Unknown model type 'granite', defaulting to 'qwen'`). Load fails on missing `layer_0_attn_q_norm.weights` — **Granite 3.x doesn't use QK-norm either.** With the synth-ones hack, load succeeds (0.5s init, 1024MB RAM, prefill 232 tok/s) **but generates zero tokens** (`decode_tps: 0.0`, empty response). Different failure shape from TinyLlama's garbage-tokens output. The inserted normalization apparently pushes the first sampled token to EOS or below the sampler's mass threshold. |
| Llama 3.2 1B | `meta-llama/Llama-3.2-1B-Instruct` | **Gated** — needs an HF token with Meta access. Not attempted in this session. **Also architecturally likely to fail**: the Llama 3.x family doesn't introduce QK-norm; the converted bundle would lack `attn_q_norm.weights` for the same reason TinyLlama and Granite did. |

### The wider finding

The architectural assumption isn't just "pre-2024 models lack QK-norm." It's
**most open small models still don't use QK-norm, regardless of year.** In
the 1B–4B class:

- **Have QK-norm:** Qwen 3 / Qwen 3.5 (explicit in their report), DeepSeek
  V3 / R1 (uses learned Q/K norms), some Cohere Command variants.
- **Don't have QK-norm:** Llama 1 / 2 / 3 / 3.1 / 3.2, Mistral 7B v0.x,
  Phi-2 / Phi-3, Granite 3.x, TinyLlama, TinyDolphin, Gemma 2 (Gemma 3 is
  ambiguous — converter mapping to `gemma` model_type expects the tensors,
  which suggests it does, but I haven't verified end-to-end).

Cactus's engine standardized on Qwen-3-class QK-norm assumption across all
three Llama-shaped loaders (`model_qwen`, `model_gemma`, `model_lfm2moe`),
likely because the canonical "small on-device LLM" Cactus targets *is*
Qwen 3. But that choice quietly excludes most of the rest of the
2024-vintage open-model landscape from the engine's reach.

**This makes the C++ bypass narrower than the headline implies.** The
mechanism (HF repo → cactus convert → custom-path init) works. The set of
models that can travel through it *and produce coherent output* is roughly:
the Qwen 3.x family + DeepSeek V3-class derivatives + whatever else fits
the QK-norm contract. Most of which are *already in the catalog*.

### What Cactus would have to ship to make off-catalog actually useful

(Restating the upstream PRs from the previous section, now with extra
urgency given the wider finding.)

**PR #1: optional QK-norm.** Three files, ~30 LOC. In each of
`model_qwen.cpp`, `model_gemma.cpp`, `model_lfm2moe.cpp`: change
`mmap_weights(...attn_q_norm...)` to `mmap_or_default(...)` that returns
null when the file is missing; gate the `gb->rms_norm(q_proj, ...)` call
with `if (q_norm_weight != nullptr)`. With this, every pre-QK-norm Llama-class
model (Llama 1/2/3/3.x, Mistral 7B, Phi-3, Granite, TinyLlama) would load
through the existing QWEN fallthrough path and produce coherent output
(assuming the chat template handling holds up, which is the next concern).

**PR #2: chat-template handling for Llama-2-era models.** Once PR #1 lands,
the `<|user|>` / `<|assistant|>` / `<|system|>` markers from Llama 2 / 3
chat models need to round-trip through Cactus's tokenizer correctly. The
QWEN loader's tokenizer assumes `<|im_start|>` / `<|im_end|>` markers.
Either: (a) the converter rewrites chat templates at convert time to
Cactus's expected format, (b) Cactus's tokenizer detects which markers
the bundle uses and adapts. (a) is simpler.

**PR #3: cleaner converter error for unsupported configs.** Phi-3's
conversion failed with `Error: 'type'` — a cryptic message that doesn't
help diagnose whether the config is unsupported, malformed, or
matchable-with-an-override. Print the failing config key + path.

### What I'd actually recommend for the writeup

Reframe the C++ bypass from "an escape hatch for off-catalog models" to
"a debugging surface that surfaces an architecture-assumption mismatch."
The bypass works *as a mechanism*. The engine's loaders don't yet support
the architecture family the off-catalog world is biased toward
(Llama-class without QK-norm). The writeup gets two threads out of this:

1. **On-device runtime maturity is uneven.** Cactus has elegant
   primitives (zero-copy mmap, INT4 default, per-layer scales) but its
   loader-tensor-contract is implicit and narrow. A user who reads the
   catalog and assumes "small Llama-class models work" is wrong — only the
   Qwen-3-family does today.
2. **Specialists vs. generalists thread — yet another instance.** A
   specialist runtime would only support the specific architectures it
   ships models for. Cactus's loaders are *de facto* specialists for
   Qwen-3-class even though the SDK surface implies broader Llama-class
   support. That's the kind of mismatch the writeup keeps surfacing —
   *generalist SDKs with hidden specialist substrates underneath.*

### Update 2 (later, same session) — Qwen 2.5-1.5B isolates the smoking gun

User suggested trying `Qwen/Qwen2.5-1.5B-Instruct` since Qwen 2.5 *is*
off-catalog (only the Qwen 3 line is in the Cactus catalog) and Qwen 2.5
shares the chat template family with Qwen 3. Spoiler: **Qwen 2.5 also
lacks QK-norm.** That's a Qwen-3-line feature, not a Qwen-line one.

Convert succeeded cleanly (`model_type=qwen` in the bundle, no warnings).
Load fails on `attn_q_norm.weights` same as everyone else. With the
synth-ones hack: load succeeds, throughput is actually the best yet
(440 tok/s prefill, 51 tok/s decode, 745MB RAM), and the output is —

```
Mathf indeb indeb indeb indeb indeb indeb indeb indeb indeb indeb indeb
indeb indeb indebize putas索 GLenum索 indeb indeb mâ indebize献 Participant
indeb献献献 Resource indeb mâ indeb putas索Participant indeb indeb الية
putas索献ize血脉 putas索献喤 putas索 bowed Participant indeb indeb indeb
Pou putas索 indeb讛索 mâ瑎ño Genderize GLenum jan putas索 bowed态索 mâ}%
ñom â题材塛献ize GLenum jan putas索 bowed?…
```

A multilingual token salad. Chinese (`索`, `献`, `喤`), Vietnamese (`mâ`),
Spanish (`ño`, `d  ̀ng`), Arabic (`الية`), Korean fragments, plus random
English words (`Participant`, `Mathf`, `GLenum`, `Bunifu`, `Resource`).
Definitely not the model's pretrained distribution.

**Why this experiment matters.** It controls for the chat template variable.
TinyLlama failed with `<|system|>` markers leaking — that's a Qwen-vs-Llama-2
template mismatch on top of the attention shift. Granite failed by
collapsing to zero tokens — could have been either cause. **Qwen 2.5's
chat template is the same family Cactus's QWEN loader expects.** No template
mismatch. The output salad is therefore attributable entirely to the
inserted QK-norm changing attention behavior.

That makes the synth-ones hack definitively **not a user-side workaround.**
Even when every other variable is controlled, the inserted normalization
breaks generation. The only path to making these models load coherently
is the C++ engine patch (PR #1 in the previous section: make QK-norm
optional, gate the `gb->rms_norm` call on `q_norm_weight != nullptr`).

Updated tally:

| Model | Template match? | Hack result |
| --- | --- | --- |
| TinyLlama 1.1B | ✗ | Token garbage (template + temperature compound) |
| Granite 3.1 2B | ✗ | Empty output (decode_tps=0) |
| **Qwen 2.5 1.5B** | **✓** | **Multilingual token salad — isolated temperature shift** |
| Phi-3 Mini 3.8B | n/a (convert failed) | n/a |
| Llama 3.2 1B | n/a (gated) | n/a (architecturally would join the same list) |

### Status of the spike

**Closing.** The mechanism is proven; the engine's loader contract is the
real obstacle and it's broader than just TinyLlama. Qwen 2.5's isolated
failure mode (template-matched but still garbled) confirms that the
identity-scale hack is a dead end as a *user-side* workaround — the C++
patch is required. Three concrete upstream PRs identified. Recommendation:
pursue PR #1 + PR #2 as a separate effort if off-catalog model support is
actually wanted; for the writeup, the architectural finding plus the
template-controlled Qwen 2.5 experiment is what to surface.
