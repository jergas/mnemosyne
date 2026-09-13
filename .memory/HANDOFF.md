# Session Hand-Off Protocol (Codex/Astra <-> Antigravity CLI <-> OpenCode)

    [Start Task in Codex (Astra)]
            |
            +-- Astra reads AGENTS.md & .memory/wiki/index.md
            +-- Astra executes work & writes discoveries to .memory/wiki/
            +-- Run `git commit -m "docs(memory): update wiki via Astra"`
            |
    [Switch to Antigravity CLI (agy) or OpenCode]
            |
            +-- Open agy / opencode in the same repo
            +-- AGENTS.md loads natively; pending ai-memory handoffs
            +   auto-inject at session start
            +-- The next agent inherits all recorded GOTCHAs & ADRs
            +-- It executes work & updates .memory/wiki/
            +-- Antigravity: run `ai-memory finalize-session --agent antigravity-cli`
            +-- Run `git commit -m "docs(memory): update wiki via <agent>"`

## In-Session Checklist

* When using Astra (Codex):
  * Keep active prompts small: read targeted .memory/wiki/ files rather than
    dumping entire source files (protects the 5-hour Plus quota).
  * Ensure Astra executes its memory consolidation / finalize-session pass
    before closing the session.
* When using Antigravity CLI (agy):
  * AGENTS.md and .memory/wiki/ load automatically; no manual reload needed.
  * Verify hook capture by comparing the `sessions` and `observations` counts
    in `ai-memory status` before and after a prompt.
  * agy has no true session-end hook: after the final turn, run
    `ai-memory finalize-session --agent antigravity-cli` to close the
    session, write the summary, and create the automatic handoff.
* When using OpenCode:
  * AGENTS.md loads natively; the generated lifecycle plugin captures
    tool and session events in the background.
  * opencode does not hot-reload config — restart it after any change to
    MCP config, plugins, or AGENTS.md discovery.
  * Sanity check: ask the agent to list its MCP tools and call memory_status.
* Legacy Gemini CLI (if wired):
  * `/memory show` at session start; `/memory reload` after background updates.
