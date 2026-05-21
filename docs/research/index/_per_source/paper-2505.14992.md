# Schema-aware Information Extraction Using On-Device Large Language Models

- **Source ID:** paper-2505.14992
- **Kind:** paper
- **Path:** inspiration/papers/2505.14992.pdf
- **Density:** 3

## Elevator summary

This paper demonstrates structured information extraction (e.g., recipe merging, entity normalization) on-device using small LLMs with schema constraints. For Mesh RAG Stage 0, the test case is whether a 1.5B–3B model can coherently merge ingredient lists from multiple recipe sources when constrained by a JSON schema. This paper validates that on-device LLMs + grammar-constrained generation can handle structured extraction tasks that traditionally require cloud APIs or larger models. The critical gap for our recipe-merging demo: no published benchmark covers recipe-fusion specifically; we inherit the general structured-extraction methodology.

## Tags

`llm-inference`, `on-device-language-models`, `structured-extraction`, `grammar-constrained-generation`, `schema-awareness`, `json-output`

## Topics covered

1. Grammar-constrained generation for deterministic structure
2. Prompt design for schema-aware extraction
3. On-device LLM performance on structured tasks
4. Comparison with API-based extraction
5. Application to real-world information extraction pipelines

## What we'd take from this

- Grammar-constrained generation (via GBNF or similar) forces LLM output into a known structure (JSON, SQL, etc.) with high confidence and no hallucination post-processing.
- On-device LLMs with quantization (1.5B–3B parameter class) can tackle structured extraction if the schema and prompt are precise; performance is acceptable for single-user latency budgets.
- Schema-aware extraction is a general pattern: we apply it to ingredient lists, but the same framework works for any tuple merging task (e.g., contact deduplication, changelog normalization).

## Cross-references (optional)

- paper-2402.00841 (Tiny Titans: fine-tuned small models for narrow tasks)
- paper-2412.04922 (domain-specific LLM work on recipe ingredient substitution)
