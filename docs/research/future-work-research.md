# Future-Work Research Pass (Step 4.5)

> Supplementary hand-research pass on the three future-work threads that landed after the original Mode B brief dispatched: **preference-aware merge**, **adversarial / mistake filtering**, **generational evolution**. Done by Opus directly via WebSearch + WebFetch on 2026-05-21. Companion to [SEED.md](../SEED.md) future-work angle and [docs/research/index/open-questions.md](research/index/open-questions.md) section 2.

The original Mode B workers had detailed engagement with thread 1 (specialists, not generalists — see LoRA Land, Tiny Titans, DistilBERT, schema-aware extraction in `docs/research/claude.md`). Threads 2–4 are the ones the workers didn't see. This pass finds the direct prior art.

---

## Thread 2 — Preference-aware merge

**The thread (from open-questions.md):** Today every contribution wins. Tomorrow, the merge respects taste: if I hate avocados the synthesized recipe quietly omits them; unless the small LLM judges I wouldn't notice. The CRDT set stays grow-only — the retrieval/synthesis at query time is preference-weighted.

### Direct prior art found

1. **CFRAG — Retrieval Augmented Generation with Collaborative Filtering for Personalized Text Generation** (Shi et al., arXiv 2504.05731, Apr 2025). The closest published cousin. Existing personalized RAG retrieves from the *user's own* history; CFRAG adds **collaborative information from similar users** via contrastive-learned user embeddings + a personalized retriever and reranker, with LLM-feedback fine-tuning. Validated on LaMP (Language Model Personalization benchmark).
   - **What it gives us:** A working architecture for "personalized retrieval over a shared corpus" with collaborative filtering as the mechanism. Maps almost directly onto Mesh RAG's preference-aware future: the *shared corpus* becomes the CRDT-merged tuple set; the *user embedding* is what biases retrieval per phone.
   - **Gap:** No mesh / no CRDT. Server-side personalization. Doesn't address how user embeddings themselves sync (or don't) across devices.
   - https://arxiv.org/abs/2504.05731

2. **ARAG — Agentic Retrieval Augmented Generation for Personalized Recommendation** (arXiv 2506.21931, Jun 2025). Multi-agent extension of personalized RAG: a User Understanding Agent summarizes long-term + session preferences; specialized agents handle semantic alignment evaluation and item ranking.
   - **What it gives us:** A natural architecture for "specialist preference agents per device" — slot directly into the Mesh RAG thread-1+thread-2 combination (specialists × preference-aware).
   - **Gap:** Same — server-side, no mesh consideration.
   - https://arxiv.org/abs/2506.21931

3. **User Preference Modeling for Conversational LLM Agents** (arXiv 2603.20939) — VARS-style dual long-term + short-term preference vectors with weak rewards from retrieval-augmented interaction.
   - **What it gives us:** A two-vector encoding (long-term cross-user overlap + short-term session) that's the right scale to broadcast in a mesh CRDT (small, bounded).
   - https://arxiv.org/abs/2603.20939

### What the writeup can say

The preference-aware future has *working server-side architectures* (CFRAG, ARAG, VARS) but **no mesh-aware implementation**. The thesis becomes: take the CFRAG-style collaborative-filtering retriever + the ARAG-style multi-agent decomposition + Mesh RAG's CRDT substrate, and you get a *peer-composable* personalization architecture nobody has built yet.

---

## Thread 3 — Adversarial / mistake filtering

**The thread (from open-questions.md):** The CRDT keeps everything (grow-only); promotion into the canonical recipe needs a gate — reputation, consensus, provenance, or LLM-plausibility check. Not every suggestion deserves to land.

### Direct prior art found

1. **Making CRDTs Byzantine Fault Tolerant** (Kleppmann, PaPoC 2022). **Gold-standard primary source on this exact question.** Adapts existing CRDT algorithms to tolerate Byzantine nodes — any number of malicious peers, immune to Sybil attacks — while maintaining Strong Eventual Consistency. Cryptographic + verification mechanisms layered onto standard CRDT semantics.
   - **What it gives us:** This is the formal version of "the CRDT keeps everything." Adversarial contributions still merge into the set — what changes is whether they're *believed*. Kleppmann's framework gives us the cryptographic gating layer we'd need.
   - **The arc point:** Kleppmann is also the lead author of the Local-First Software essay (our writeup's foundational citation). The progression *local-first → mesh RAG → Byzantine-tolerant mesh RAG* is one author's intellectual lineage. The writeup can lean on this.
   - https://martin.kleppmann.com/papers/bft-crdt-papoc22.pdf
   - https://dl.acm.org/doi/abs/10.1145/3517209.3524042 (ACM DL canonical)

2. **Byzantine-Resistant Reputation-Based Trust Management** (IEEE, archived on HAL). Older (2013) but foundational. Reputation systems designed to resist Byzantine behavior.
   - **What it gives us:** Long-standing reputation-system literature, useful as background. Not the load-bearing source but useful for the writeup's "this isn't a new idea" framing.
   - https://hal.science/hal-01261638v1

### What the writeup can say

Adversarial filtering on a grow-only CRDT *isn't speculative* — Kleppmann formalized it in 2022. The implementation path is: standard Ditto CRDT for the grow-only set + Kleppmann's BFT-CRDT layer for *signed contributions* + an LLM-judged promotion layer on top. Mesh RAG ships the substrate; this thread completes it.

---

## Thread 4 — Generational evolution

**The thread (from open-questions.md):** Recipes drift over time *even with the same people involved* — taste shifts, ingredients become available, old steps get pruned. Temporal weighting on retrieval or branch-on-taste-divergence semantics. Family recipes through generations is the load-bearing analogy.

### Direct prior art found

1. **Not All Memories Age the Same: Autodiscovery of Adaptive Decay in Knowledge Graphs** (Karhade, arXiv 2604.26970, Apr 2026). **The strongest direct prior art and the most recent.** Replaces uniform decay with a continuous *decay surface* parameterized by velocity (how frequently observed) and volatility (how much value changes between observations). Formulates edge lifetime as a survival-analysis problem where value-supersession marks the event. **Headline number: uniform decay performs 18× worse than no temporal weighting at all; heterogeneous decay recovers gains across all hierarchy levels.**
   - **What it gives us:** A formal framework for the "family recipe drift" problem. Each ingredient-step-contributor edge in the corpus gets its own velocity and volatility; old contributions decay at the rate appropriate to *that* concept, not a global rate. Maps onto Mesh RAG's per-tuple temporal weighting.
   - **Critical finding to internalize:** uniform decay is worse than no decay. If we apply naive recency weighting we make things worse — we need *per-concept* decay rates, which means we need a learned (or hand-encoded) velocity/volatility per ingredient. This is a non-trivial design.
   - https://arxiv.org/abs/2604.26970

2. **It's High Time: A Survey of Temporal Information Retrieval and Question Answering** (arXiv 2505.20243). Survey of temporal IR — useful as the citations hub for thread 4. Find the open problems list and the standard benchmark setups.
   - **What it gives us:** A citation map. Doesn't replace direct sources but gives us a defensible "we surveyed the field" position.
   - https://arxiv.org/abs/2505.20243

3. **From Storage to Experience: A Survey on the Evolution of LLM Agent Memory Mechanisms** (preprint 2601.0618, v2). Survey of LLM agent memory architectures including temporal layers.
   - **What it gives us:** Adjacent landscape on LLM-agent memory mechanisms (where the analogy "remembering family recipes" lives naturally).
   - https://www.preprints.org/manuscript/202601.0618/v2/download

4. **RAG Is Blind to Time — Engineering Writeup** (Towards Data Science). Practical implementation of a temporal layer for RAG. Temporal reranking adds only 15–30ms vs. 1–4 seconds for the LLM call — i.e., effectively free.
   - **What it gives us:** Engineering-blog evidence that temporal weighting is *cheap* to add to a retrieval pipeline; we don't have to wait for the future-work phase to experiment with it. Could even be a Stage-1 add if the demo lands cleanly.
   - https://towardsdatascience.com/rag-is-blind-to-time-i-built-a-temporal-layer-to-fix-it-in-production/

5. **temporal-rag (Emmimal)** — open-source reference implementation of a post-retrieval temporal layer.
   - https://github.com/Emmimal/temporal-rag/

### What the writeup can say

Generational evolution has the strongest published primary source of the three threads — Karhade (2026) gives us a formal decay-surface framework + a striking empirical claim (uniform decay 18× worse than nothing). The implementation cost is documented as low (15–30ms reranking overhead). The thesis the writeup lands on: *family recipes drift, and we know how to encode it* — the model is velocity-and-volatility per concept, and it works.

---

## Suggested additions to `downloads.yaml`

These are new candidate sources surfaced by this Step 4.5 pass. They are not in the current manifest. **Suggested action:** upsert as `status: pending` so a re-run of Step 3 can pull them, or add ad-hoc as needed.

| URL | kind | thread | priority |
|---|---|---|---|
| https://martin.kleppmann.com/papers/bft-crdt-papoc22.pdf | paper | 3 | **high** — Kleppmann primary; load-bearing for the writeup |
| https://arxiv.org/abs/2604.26970 | paper | 4 | **high** — Karhade adaptive-decay; strongest thread-4 primary |
| https://arxiv.org/abs/2504.05731 | paper | 2 | **high** — CFRAG; closest preference-aware-RAG primary |
| https://arxiv.org/abs/2506.21931 | paper | 2 | medium — ARAG; multi-agent extension |
| https://arxiv.org/abs/2603.20939 | paper | 2 | medium — VARS-style user preference modeling |
| https://arxiv.org/abs/2505.20243 | paper | 4 | medium — Temporal IR survey |
| https://arxiv.org/abs/2505.01657 | paper | 2 | low — RAGAR (image-generation, less aligned) |
| https://arxiv.org/abs/2512.12856 | paper | 4 | low — "Forgetful but Faithful" cognitive memory benchmark |
| https://www.preprints.org/manuscript/202601.0618/v2/download | paper | 4 | low — LLM agent memory survey |
| https://hal.science/hal-01261638v1 | paper | 3 | low — Byzantine-resistant reputation (older but adjacent) |
| https://github.com/Emmimal/temporal-rag | repo | 4 | medium — reference temporal-layer impl |
| https://towardsdatascience.com/rag-is-blind-to-time-i-built-a-temporal-layer-to-fix-it-in-production/ | article | 4 | medium — engineering writeup, low-cost temporal-layer evidence |
| https://airweave.ai/blog/temporal-relevance-explained | article | 4 | low — temporal-relevance primer |

To upsert these into the manifest and let a Step 3 re-run fetch them:

```python
# python3 -c "..." snippet
import yaml
new = [
    ("https://martin.kleppmann.com/papers/bft-crdt-papoc22.pdf", "paper", "Making CRDTs Byzantine Fault Tolerant — Kleppmann (PaPoC 2022)"),
    ("https://arxiv.org/abs/2604.26970", "paper", "Not All Memories Age the Same — Karhade (Apr 2026)"),
    ("https://arxiv.org/abs/2504.05731", "paper", "CFRAG — Collaborative-Filtering Personalized RAG (Apr 2025)"),
    # ... add others as desired
]
d = yaml.safe_load(open("docs/research/downloads.yaml"))
existing = {e["url"] for e in d["entries"]}
for url, kind, title in new:
    if url not in existing:
        d["entries"].append({"url": url, "kind": kind, "title": title,
                              "cited_in": ["step-4.5-opus"], "status": "pending", "path": None})
yaml.safe_dump(d, open("docs/research/downloads.yaml","w"), sort_keys=False, default_flow_style=False, allow_unicode=True, width=120)
```

---

## What changed in the open-questions arc

The four-thread arc in [`docs/research/index/open-questions.md`](research/index/open-questions.md) said threads 2–4 were "synthesized from our conversation, not from web-sourced prior art." That caveat now no longer applies — each thread has at least one strong primary source:

- **Thread 2:** CFRAG (arXiv 2504.05731) — Mesh RAG slot becomes "the peer-composable version of CFRAG."
- **Thread 3:** Kleppmann's BFT-CRDT paper — the gold-standard formalization of grow-only-CRDT + adversarial-filtering. Same author as the Local-First Software essay, so the writeup arc is *one author's lineage*.
- **Thread 4:** Karhade adaptive-decay (arXiv 2604.26970) — formal decay-surface framework + the striking "uniform decay is 18× worse than no decay" empirical claim. Cheap to implement (15–30ms overhead per the Emmimal engineering writeup).

The thesis tightens. The writeup can now say all four threads have known mechanisms in the literature; what Mesh RAG contributes is the *mesh substrate* on which they compose.
