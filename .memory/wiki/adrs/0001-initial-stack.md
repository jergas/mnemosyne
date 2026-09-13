# ADR 0001: Initial Stack — Cross-Agent Memory System

Status: Accepted
Date: 2026-09-12

## Context

This project (mnemosyne) exists to give multiple coding agents — OpenAI Codex
(GPT-6 Astra), Google Antigravity CLI (`agy`) and OpenCode — shared, durable
project memory without burning Astra's tight ChatGPT Plus quota (5-hour
rolling window; large-context turns drain it fastest). A deep-research
evaluation (archived at `.memory/raw/2026-09-memory-systems-evaluation.pdf`)
compared memory paradigms and tools; see
[memory-architecture.md](../memory-architecture.md) for the corrected digest.

## Decision

Adopt a Karpathy-style markdown wiki as the knowledge layer, plus ai-memory as
the memory infrastructure:

1. **Vault**: git-tracked `.memory/` (raw sources + wiki) with an index,
   audit log, gotchas and failed-approaches ledgers, and ADRs.
2. **Instructions**: a single `AGENTS.md` at the repo root, read natively by
   all three CLIs (no per-vendor bridge files for the current clients).
3. **Infrastructure**: ai-memory (Rust, MIT, AUR `ai-memory-bin`) running as
   a systemd user service on loopback, providing MCP tools (memory_query,
   memory_handoff_*, memory_consolidate, ...) and background lifecycle-hook
   capture to all three clients.
4. **Bootstrap/maintenance**: `./init-memory-system.sh` (idempotent) — the
   canonical way to reproduce or extend this setup.

Rejected alternatives:

* **memwiki** — passive, model-dependent capture: if Astra is cut off
  mid-task by quota, the turn's context is lost. No search backstop, no typed
  handoffs.
* **Vector chunk-RAG** — fragments code, adds context noise, needs a vector
  store to babysit.
* **Model-native notes** — vendor-locked, not shared across CLIs, not
  human-auditable.

## Consequences

* Knowledge is plain markdown in git: humans and any agent can read/write it,
  and it survives vendor/tool switches.
* Active context stays small (read targeted wiki pages, not whole sources),
  protecting Astra's quota.
* Operational duties per client: trust the hook prompt once in Codex; run
  `ai-memory finalize-session --agent antigravity-cli` after final agy turns;
  restart OpenCode after config/plugin changes; AUR package installs require
  interactive sudo (agent shells cannot run `yay`).
* The ai-memory server is machine-local (loopback); the git-tracked wiki is
  the portable layer across machines.
