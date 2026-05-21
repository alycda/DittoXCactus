# Conflict-free Replicated Data Types (CRDTs)

- **Source ID:** paper-1106.4374
- **Kind:** paper
- **Path:** inspiration/papers/1106.4374.pdf
- **Density:** 5

## Elevator summary

Foundational CRDT theory paper establishing the mathematical framework for conflict-free replicated data types that automatically merge without central coordination. Provides the theoretical bedrock for treating a vector-index store as a grow-only CRDT in Mesh RAG, guaranteeing convergence and idempotence across peers. Essential reading for understanding why a CRDT merge semantic is the right choice for peer-to-peer embedding storage.

## Tags

`crdt`, `distributed-systems`, `convergence`, `conflict-free-merge`, `peer-to-peer`, `theoretical-foundation`

## Topics covered

1. Formal definitions of conflict-free replicated data types
2. Grow-only sets, LWW registers, and composition
3. Eventual consistency and convergence guarantees
4. Immunity to operation ordering and network partitions

## What we'd take from this

- The mathematical proof that grow-only sets (the merge semantic chosen for Mesh RAG's embedding corpus) guarantee convergence without a coordinator
- Formal justification for idempotent insertion in the RecipeTuple corpus
- The basis for arguing that "retrieval-augmented knowledge" is naturally a CRDT, more so than chat history or weights

## Cross-references

- paper-2305.00583 (Fugue text CRDT, cited in Loro)
