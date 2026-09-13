# Environment & Library Gotchas

## ai-memory vs the ai-memory-mcp npm package (2026-09-12)
The npm package `ai-memory-mcp` is an unrelated third-party notes server
(author larryzhang, env `AI_MEMORY_ROOT`); the real ai-memory is akitaonrails'
Rust HTTP server (loopback :49374) wired via `ai-memory install-mcp` /
`install-hooks`. Never wire ai-memory by hand with npx — see
[failed_approaches.md](failed_approaches.md).

## Gemini CLI is deprecated — use Antigravity CLI (2026-09-12)
Google's successor is `agy` (antigravity.google, installs to
`~/.local/bin/agy`). It reads AGENTS.md natively, keeps MCP in
`~/.gemini/config/mcp_config.json` (key `serverUrl`) and hooks in
`~/.gemini/config/hooks.json`. It has no true session-end hook: run
`ai-memory finalize-session --agent antigravity-cli` after the final turn to
create the summary and handoff.

## Codex requires explicit trust for new hooks (2026-09-12)
After `install-hooks --agent codex`, the next `codex` start shows
"Hooks need review" — choose "Trust all and continue". Without trust,
ai-memory capture hooks don't run.

## OpenCode does not hot-reload config (2026-09-12)
OpenCode loads config/plugins once at startup: after MCP or plugin changes,
restart it. ai-memory's plugin lives at
`~/.config/opencode/plugins/ai-memory.ts`; the MCP entry merges into
`~/.config/opencode/opencode.json`.

## AUR installs need interactive sudo (2026-09-12)
`yay -S` prompts for a sudo password, so agent shells cannot install AUR
packages — a human must (ai-memory ships as `ai-memory-bin`/`ai-memory`,
author-maintained, with a systemd user unit `ai-memory.service`).

## PDFs are not readable by all agents (2026-09-12)
Some agent models cannot ingest PDF attachments directly; extract text with
`pdftotext` (poppler) instead. Raw PDFs still belong in `.memory/raw/` as
durable human-readable sources.

## Codex fires an Interrupt event ai-memory doesn't wire (2026-09-12)
Codex CLI ≥ 0.150.0 fires `Interrupt` when an active top-level turn is aborted (Esc); `Stop` never fires on abort paths. ai-memory 2.2.1's codex bundle has no interrupt hook, so a custom bridge was added: `~/.codex/hooks/ai-memory-interrupt.sh` posts the payload as an extension observation (`source_event=interrupt`) and is registered under `Interrupt` in `~/.codex/hooks.json` (needs a one-time trust at the next codex start). ai-memory's async ingest means a `202 queued` response may not be visible in `ai-memory status` immediately.
