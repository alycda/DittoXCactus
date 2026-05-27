# Pre-swap snapshot (2026-05-26)

Archives the iPhone determinism JSON captured against the **chat-tuned
`qwen3-0.6`** slug, immediately before issue #9 swapped the demo's default
embedder to dedicated `qwen3-0.6-embed`. The original Pixel baselines from
2026-05-23 are preserved one level deeper at
[`../2026-05-23/`](../2026-05-23/) — Pixel↔Pixel determinism is 1.0000
regardless of slug (same SoC = bit-identical output), so we didn't keep a
second Pixel copy here.

The iPhone JSON kept here is the original 2026-05-23 measurement against
chat-tuned `qwen3-0.6`. Cross-platform U1 rate was 0.85 with this baseline
(3 disagreements on Q10/Q13/Q17 between iOS and Pixel). After the swap to
`qwen3-0.6-embed` and a fresh on-device re-measurement on 2026-05-27, the
cross-platform rate jumped to **1.0000** (0 disagreements). The new iPhone
JSON for the dedicated slug lives in
[`../latest/iphone.json`](../latest/iphone.json).

Keep this snapshot for the audit trail — it's the only way to verify the
0.85 → 1.0000 improvement was a real model effect and not measurement drift.
