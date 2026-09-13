# Memory System Architecture & Evaluation

Digest of the deep-research evaluation archived at
[2026-09-memory-systems-evaluation.pdf](../raw/2026-09-memory-systems-evaluation.pdf)
(Gemini conversation, kept verbatim). This page holds the corrected, actionable
knowledge; errors found in the source are listed below. Bootstrap tool:
`./init-memory-system.sh` in the repo root (idempotent; `--help` for flags).

## Why a memory system at all

GPT-6 Astra on a ChatGPT Plus account has a tight 5-hour quota (the source doc
claims 1–3 non-trivial Codex turns can consume 50–100% of it, and requests
over 272k input tokens are billed at 2x input / 1.5x output rates). Every turn
that dumps large context into the model burns quota fast. The fix is a
*layered context funnel*: keep active prompts small by reading pre-compiled,
targeted summaries instead of whole sources. Model-native notes (Astra "Notes
and Search", Gemini cloud memory) don't help across vendors: they are locked
inside each vendor's runtime and invisible to other tools.

## Paradigm comparison (from the evaluation)

* **Karpathy-style markdown wiki** — chosen. Plain-text, git-tracked pages
  that any agent or human reads: multi-agent interoperability, human
  auditability (Obsidian/VS Code), and context funneling.
* **Vector chunk-RAG** — rejected: fragments code, adds context noise.
* **AST code map (tree-sitter)** — endorsed as a complementary low-cost
  structural layer (~1–2k tokens); not implemented in this project yet.
* **Model-native notes** — rejected as the primary layer: vendor-locked, not
  human-auditable, not shared across CLIs.

## ai-memory vs memwiki (why ai-memory won)

Both are open source and both build on the Karpathy wiki idea:

|                        | memwiki                            | ai-memory                                  |
| ---------------------- | ---------------------------------- | ------------------------------------------ |
| Nature                 | Prompt/folder scaffolder (npx)     | Rust server + MCP infrastructure           |
| Capture                | Passive — model must write before close | Hook-driven — background lifecycle capture |
| Search                 | Manual file reads/grep             | SQLite/FTS backstop + wiki files           |
| Handoffs               | File-based convention              | Typed protocol (memory_handoff_begin/accept) |

The decisive argument: with Astra's quota, a passive system loses the turn
whenever the model is cut off mid-task; ai-memory's hooks capture tool calls
and failures automatically. Its typed handoff protocol is what makes
alternating between Codex, Antigravity and OpenCode seamless. (Source:
akitaonrails/ai-memory, MIT, Rust.)

## Corrections to the source document

1. **Step 3's MCP snippet is wrong.** `npx -y ai-memory-mcp` points at an
   unrelated third-party npm package (author: larryzhang; stdio notes server).
   The real ai-memory is akitaonrails' Rust binary serving HTTP on
   127.0.0.1:49374, wired via `ai-memory install-mcp --client <name> --apply`
   (and `install-hooks --agent <name> --apply`). Even for the npm package the
   doc's `MEMORY_PATH` env var is wrong (`AI_MEMORY_ROOT`).
2. **Gemini CLI is deprecated.** Google's successor is Antigravity CLI (`agy`),
   installed from antigravity.google. It reads `AGENTS.md` natively, so the
   doc's Step-2 Gemini bridge (`.gemini/settings.json` `context.fileName` or
   a thin `GEMINI.md`) is unnecessary for it; kept only as a legacy option.
3. **Codex has no `~/.codex/mcp.json`.** MCP servers merge into
   `~/.codex/config.toml` (`[mcp_servers.ai-memory]`).
4. **Seed-content links were mangled** by the Google-Docs export
   (docs.google.com/... placeholders) — restored to relative wiki links. The
   doc's GEMINI.md import line `@file AGENTS.md` is also wrong syntax; the
   real form is `@AGENTS.md`.
5. **Astra quota/context figures** (5–45 msgs/5h, 272k threshold, 1.05M
   window) are the source conversation's claims, not independently verified;
   treat as approximate.

## Implemented architecture (2026-09-12)

* Vault: `.memory/{raw,wiki}` (this wiki), `AGENTS.md` protocol, git-tracked;
  runtime state (`.memory/*.db`, `.memory/tmp/`) ignored.
* Server: ai-memory 2.2.1 from AUR (`ai-memory-bin`, author-maintained),
  systemd user unit `ai-memory.service`, HTTP + MCP on 127.0.0.1:49374, data
  dir `~/.local/share/ai-memory`. Zero-LLM mode (FTS search only, no API
  keys); LLM/embedding providers can be enabled later in
  `~/.config/ai-memory/config.toml`.
* Clients (MCP + lifecycle hooks):
  * **Codex** — `~/.codex/config.toml` + `~/.codex/hooks.json`; hooks need a
    one-time explicit trust prompt at next start.
  * **Antigravity CLI** — `~/.gemini/config/mcp_config.json` +
    `~/.gemini/config/hooks.json`; no true session-end hook: run
    `ai-memory finalize-session --agent antigravity-cli` after the final turn.
  * **OpenCode** — `~/.config/opencode/opencode.json` + plugin at
    `~/.config/opencode/plugins/ai-memory.ts`; config is loaded once at
    startup, restart to pick up changes.
* Session hand-off protocol: [HANDOFF.md](HANDOFF.md).

## Where things go (doc guidance, kept)

* `.memory/raw/` — unedited reference material (deep-research reports, API
  specs). The agent distills them into the wiki on request.
* `.memory/wiki/` — distilled domain knowledge, decisions, gotchas.
* `/docs/` — permanent human-facing project documentation (none yet).

## Related

* [ADR 0001: Initial Stack](adrs/0001-initial-stack.md)
* [Environment & Library Gotchas](gotchas.md)
* [Failed Implementation Paths](failed_approaches.md)
* [Memory Update Log](log.md)
