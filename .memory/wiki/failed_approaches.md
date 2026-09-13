# Failed Implementation Paths

## Doc-literal MCP wiring via npx (2026-09-12)
The evaluation doc's Step 3 as written — `npx -y ai-memory-mcp` with
`MEMORY_PATH=.memory` in `~/.codex/mcp.json` — fails three ways: the npm
package is an unrelated project, the env var is wrong even for it
(`AI_MEMORY_ROOT`), and Codex has no `~/.codex/mcp.json`. Correct path:
`ai-memory install-mcp --client codex --apply` (merges into
`~/.codex/config.toml`) — do not re-attempt the npx form.
