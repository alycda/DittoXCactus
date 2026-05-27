<!--
DRAFT — GitHub Discussion, category: Show and tell
Repo: alycda/DittoXCactus
Author: Alyssa
Date drafted: 2026-05-26

To post:
  gh discussion create --repo alycda/DittoXCactus \
    --category "Show and tell" \
    --title "What I learned trying to run TinyLlama, Granite, and Qwen 2.5 on Cactus's C++ engine" \
    --body-file _docs/discussions/2026-05-26-cactus-cpp-bypass-spike.md

Or via GraphQL (since `gh discussion create` isn't in older gh builds), use
the same pattern as discussion #8 (see git log for the createDiscussion
mutation invocation).

Pre-post checklist:
- [ ] Push `spike-tinyllama-cactus` so relative links to the spike notes resolve
- [ ] Strip this HTML comment before posting
- [ ] Optional: cross-link to discussion #8 (the eval that motivated this)
-->

# What I learned trying to run TinyLlama, Granite, and Qwen 2.5 on Cactus's C++ engine

Follow-up to [Discussion #8](https://github.com/alycda/DittoXCactus/discussions/8), where
the small-LLM eval concluded with one deferred item: *try TinyLlama / TinyDolphin via
the C++ route — the Cactus catalog doesn't list them, but the engine's
`engine_model.cpp:548` maps `tinyllama → ModelType::GEMMA4`, suggesting the engine
already knows how to load them.* Spent a few hours on this and the result is more
interesting than the deferred item implied.

**TL;DR.** The C++ bypass mechanism works — HF repo → `cactus convert` → custom-path
`cactus_init` → inference all flow. The blocker is *one shared assumption* baked into
three loader files in the C++ engine: every Llama-class model is assumed to have
**QK-norm** tensors (`layer_*_attn_q_norm.weights`, `layer_*_attn_k_norm.weights`).
This is a Qwen-3-era convention. Most 1–4B open models — TinyLlama, Llama 1/2/3.x,
Mistral 7B v0.x, Phi-2/3, Granite 3.x — don't use QK-norm and don't load. Three
upstream PRs at the end if any Cactus folks are reading.

## What I tried

Five candidates, one HF token short of full coverage.

| Candidate | HF ID | Result |
| --- | --- | --- |
| **TinyLlama 1.1B Chat** | `TinyLlama/TinyLlama-1.1B-Chat-v1.0` | Converts cleanly. Load fails on missing `layer_0_attn_q_norm.weights`. **Identity-scale-ones hack** (synthetic `attn_q_norm.weights` files filled with FP16 ones) lets the load succeed and inference runs at 568/106 tok/s prefill/decode — but output is garbage (`<0x0A><\|system\|>...` token leakage). Two compounding failure modes: template mismatch + attention-temperature shift. |
| **Granite 3.1 2B** | `ibm-granite/granite-3.1-2b-instruct` | Converts (`Warning: Unknown model type 'granite', defaulting to qwen`). Load fails same way. With the ones-hack: load succeeds (0.5s, 1024MB RAM, 232 tok/s prefill) but **generates zero tokens** (`decode_tps: 0.0`, empty response). Different shape, equally unusable. |
| **Qwen 2.5 1.5B Instruct** | `Qwen/Qwen2.5-1.5B-Instruct` | Converts cleanly. **Surprise:** Qwen 2.5 also lacks QK-norm — it's a Qwen-3-line feature only. With the ones-hack: load succeeds, throughput is the best yet (440/51 tok/s, 745MB RAM), output is a **multilingual token salad** mixing Chinese / Spanish / Vietnamese / Arabic fragments with random English words. Crucial *because* Qwen 2.5's chat template matches what Cactus's QWEN loader expects — see "the isolated experiment" below. |
| **Phi-3 Mini 3.8B** | `microsoft/Phi-3-mini-4k-instruct` | **Convert fails** with cryptic `Error: 'type'` after fetching weights. Cactus's Python converter doesn't handle Phi-3's HF config schema (probably the `rope_scaling.type` field). Never reached the load stage. |
| **Llama 3.2 1B** | `meta-llama/Llama-3.2-1B-Instruct` | Gated; couldn't fetch without an HF token. Llama 3.x doesn't introduce QK-norm either, so the prediction is identical failure to TinyLlama — but unverified. |

## The mechanism works

This isn't a complaint about the bypass. Convert + load + inference all execute:

```bash
# Step 1 — convert any HF causal-LM repo to Cactus's per-layer .weights+.scale format
$ PYTHONPATH=. python -m src.cli convert TinyLlama/TinyLlama-1.1B-Chat-v1.0
Loading weights: 100%|██████████| 201/201
Quantization Summary:
  CosSim - Mean: 0.995046, Max: 0.999950
Processed 1 INT8 tensors, 155 INT4 tensors, 45 FP16 tensors
Successfully downloaded and converted weights to weights/tinyllama-1.1b-chat-v1.0
```

```python
# Step 2 — load + run via the brew-installed libcactus.dylib's Python bindings
from cactus import cactus_init, cactus_complete
model = cactus_init("/path/to/converted/dir", "", False)   # works for ANY dir, catalog or not
out = cactus_complete(model, messages_json, options_json, "[]", None)
# {"response": "...", "prefill_tps": 568, "decode_tps": 106, ...}
```

So the engine *will* take a custom-path bundle. The catalog isn't gatekeeping. **The
engine's per-loader file-mmap contract is.**

## The architectural finding

Every Llama-class loader in Cactus's C++ engine hard-requires QK-norm tensors:

| Loader | File | Where |
| --- | --- | --- |
| Qwen path | `model_qwen.cpp` | L37 — `mmap_weights("attn_q_norm.weights")` then L64 `gb->rms_norm(q_proj, q_norm_weight, ...)` |
| Gemma path | `model_gemma.cpp` | L41 — same pattern, L70 `rms_norm` |
| LFM2-MoE path | `model_lfm2moe.cpp` | L133 — `mmap_or_throw("attn_q_norm.weights", false)` |

If the file is missing, `mmap_weights` throws:

```
[ERROR] [init] Exception during init: Cannot open file for mapping:
       .../layer_0_attn_q_norm.weights
```

And there's no Llama-without-QK-norm loader. The engine's
`tinyllama → ModelType::GEMMA4` string mapping at `engine_model.cpp:548` is a
half-hookup — string is recognized, but `ModelType::GEMMA4` resolves to the
Gemma-3n loader, which expects `embed_tokens_per_layer.weights` instead. Different
missing file, same "Cannot open file for mapping" wall.

## The wider observation

I assumed pre-2024 was the cutoff for "lacks QK-norm." It's wider than that. In the
1–4B class of currently-open models:

- **Have QK-norm:** Qwen 3 / Qwen 3.5 (explicit in their tech report), DeepSeek V3 /
  R1 (learned Q/K norms), some Cohere Command variants.
- **Don't have QK-norm:** Llama 1 / 2 / 3 / 3.1 / 3.2, Mistral 7B v0.x,
  Phi-2 / Phi-3, Granite 3.x, TinyLlama, TinyDolphin, Gemma 2. (Gemma 3 ambiguous —
  converter mapping suggests yes but I didn't verify end-to-end.)

Cactus's engine standardized on the Qwen-3-class assumption across all three
Llama-class loaders, likely because Qwen 3 is Cactus's canonical "small on-device
LLM." But that quietly excludes most of the rest of the 2024-vintage open model
landscape from the engine's reach.

**For the C++ bypass that means:** the mechanism works, but the set of models that
can travel through it *and produce coherent output* is roughly *the Qwen 3.x family
+ DeepSeek-V3-class derivatives*. Most of which are already in the catalog. The
practical scope of "off-catalog model loading" is therefore narrower than the
mechanism suggests.

## Identity-scale-ones hack: it loads but doesn't help

Out of curiosity, I wrote a small script that synthesizes
`layer_*_attn_q_norm.weights` files containing FP16 ones-tensors of shape
`(head_dim,)`. RMSNorm with an identity scale is just RMS normalization without
learnable parameters; inserting it lets `mmap_weights` find a file and
`gb->rms_norm(...)` returns a valid tensor.

The model loads. Inference runs. But three different failure shapes across three
different model families confirmed the hack isn't a workaround:

- **TinyLlama 1.1B** produced token streams like
  `<0x0A><0x0A><|system|>system|ass><|assistant>2>2>` — compound failure of
  attention-temperature shift + chat-template mismatch (QWEN loader expects
  `<|im_start|>` markers, TinyLlama uses Llama 2's `<|system|>`).
- **Granite 3.1 2B** generated *zero tokens* (`decode_tps: 0.0`, empty response).
  Bigger model, more graceful death — the inserted normalization apparently
  pushes the first sampled token to EOS or below the sampler's mass threshold.

## The isolated experiment: Qwen 2.5 controls for chat-template mismatch

TinyLlama and Granite both confounded two variables — *attention-temperature
shift* (from the inserted RMSNorm) and *chat-template mismatch* (Llama-2-era
markers vs. Qwen's `<|im_start|>` style). I couldn't tell which one was breaking
generation.

Qwen 2.5 1.5B was the right control. Qwen 2.5 shares the chat template family
with Qwen 3 — `<|im_start|>` / `<|im_end|>` markers — but **doesn't have
QK-norm**. So loading it with the synth-ones hack tests *just the attention
shift in isolation*, with the chat template variable removed.

Result: token salad. Real output, abridged:

```
Mathf indeb indeb indeb indeb indeb indeb indeb indeb indeb indebize putas索
GLenum索 indeb indeb mâ indebize献 Participant indeb献献献 Resource indeb mâ
indeb putas索Participant indeb indeb الية putas索献ize血脉 putas索献喤 putas索
bowed Participant indeb indeb indeb Pou putas索 indeb讛索 mâ瑎ño Genderize GLenum
jan putas索 bowed态索 mâ}% ñom â题材塛献ize ...
```

Chinese characters (`索`, `献`, `喤`), Vietnamese (`mâ`), Spanish (`ño`, `dòng`),
Arabic (`الية`), Korean fragments, random English (`Participant`, `Mathf`,
`GLenum`, `Bunifu`, `Resource`). 51 tok/s decode — the model is generating
fluently; it's just generating from a completely scrambled distribution.

**With chat-template mismatch ruled out**, the only remaining cause is the
attention-temperature shift. The inserted normalization changes how
pretrained attention weights interpret their inputs, and the model has no
trained robustness to that change. Same finding the original synth-norm idea
would predict, but now with a clean control case behind it.

**Conclusion:** the synth-ones hack is a dead end as a user-side workaround.
The model *will* execute architecturally-incompatible inference; the output
is just unusable, even when every other variable lines up. Real fix is the
engine patch in PR #1 below.

## Three upstream PRs this spike concretely supports

If anyone from cactus-compute is reading and wants to widen the engine's reach:

**PR #1 — optional QK-norm.** Three files, ~30 LOC. In each of `model_qwen.cpp`,
`model_gemma.cpp`, `model_lfm2moe.cpp`: change `mmap_weights(...attn_q_norm...)` to
something that returns null when the file is missing; gate the `gb->rms_norm(...)`
call with `if (q_norm_weight != nullptr)`. This unlocks pre-QK-norm Llama-class
models across the board.

**PR #2 — chat-template handling for Llama-2-era markers.** Once PR #1 lands,
`<|user|>` / `<|assistant|>` / `<|system|>` markers from Llama 2 / 3 chat models
need to round-trip through Cactus's tokenizer correctly. Either the converter
rewrites templates at convert time (simpler) or the runtime detects which markers
the bundle uses and adapts.

**PR #3 — cleaner converter error for unsupported configs.** Phi-3's `Error: 'type'`
told me nothing about whether the config was unsupported, malformed, or
matchable-with-an-override. Printing the failing config key + path would have
saved an hour of trial-and-error.

## A separate small finding: the brew formula's venv is broken for `cactus convert`

Running `cactus convert <hf-id>` with the brew-installed CLI fails consistently
with `Could not import module 'LlamaForCausalLM'`. Root cause inside
`/opt/homebrew/Cellar/cactus/1.14_1/libexec/venv`: torchvision is installed but its
C extension is incompatible with the bundled torch 2.12.0
(`RuntimeError: operator torchvision::nms does not exist`). Importing
`transformers.models.llama` transitively imports torchvision, which fails to load.

Workaround used in this spike: a separate Python 3.11 venv with fresh
`transformers + torch` (no torchvision) at `/tmp/cactus-convert-venv`, then
`PYTHONPATH=<cactus python source> python -m src.cli convert <hf-id>`. Output
bundle lands in the brew location regardless and is then loadable via the brew
binary's `libcactus.dylib`.

**Two-line formula fix:** remove torchvision from the bundled venv (or pin a
compatible version). Unblocks `cactus convert` on Mac for arbitrary HF causal-LM
models.

## And one more telemetry seam

While I had the Python bindings open: `cactus_init` from Python also writes to
Supabase on init. I saw the response body in stderr:

```
{"code":"23505","details":null,"hint":null,
 "message":"duplicate key value violates unique constraint \"projects_project_key_idx\""}
```

The unique-constraint violation is just because the same machine fingerprint
keeps registering. The relevant fact is that *a network write happened*. The
Python bindings don't honor `CactusConfig.isTelemetryEnabled` either — that's a
Dart-side concept. So Mac/dev-side use of the Python API has an *additional*
telemetry seam beyond the Flutter SDK's `getModel` leak that
[#33](https://github.com/cactus-compute/cactus-flutter/issues/33) tracks.

## What I'd ask for comments on

- **Cactus folks:** do PRs #1 and #2 sound right to ship? PR #1 is the load-bearing
  one — does anyone outside cactus-compute have leverage to land it? I'd rather
  consume a wider engine than maintain a fork.
- **Anyone who's tried off-catalog models on Cactus:** what did you load and how
  did you work around the loader contract? The QK-norm gap can't be the only one.
- **Anyone running edge LLMs more broadly:** is the "specialist runtimes with
  generalist API surfaces" pattern visible at other engines too (llama.cpp's
  per-architecture flags, MLC's model-specific configs)? This is the
  thread the [larger writeup](https://github.com/alycda/DittoXCactus) keeps
  surfacing and I'm curious whether the pattern generalizes.

## Where to look

- Spike notes (full diagnostic chain): [`_docs/notes/cactus-cpp-bypass-spike.md`](https://github.com/alycda/DittoXCactus/blob/spike-tinyllama-cactus/_docs/notes/cactus-cpp-bypass-spike.md)
- Smoke-test driver: [`tools/ollama_eval/smoke_cactus_model.py`](https://github.com/alycda/DittoXCactus/blob/spike-tinyllama-cactus/tools/ollama_eval/smoke_cactus_model.py)
- The eval that motivated this spike: [Discussion #8](https://github.com/alycda/DittoXCactus/discussions/8)
- Prior model-quirk corrections: [`cactus-sdk-quirks.md`](https://github.com/alycda/DittoXCactus/blob/main/_docs/notes/cactus-sdk-quirks.md)

Spike branch: `spike-tinyllama-cactus`. Not merged; kept around as the reproduction
trail for these claims.
