# mnemosyne

A cross-agent memory system for AI coding CLIs: a git-tracked,
Karpathy-style markdown wiki plus the [ai-memory](https://github.com/akitaonrails/ai-memory)
MCP server — wired for **OpenAI Codex (Astra)**, **Google Antigravity CLI (`agy`)** and
**OpenCode**, so all three share one durable project memory.

This repository is both the tool and the proof: it bootstraps and maintains its own
knowledge vault (`.memory/`), digested from the deep-research evaluation that
motivated the architecture —
[raw source PDF](.memory/raw/2026-09-memory-systems-evaluation.pdf),
[corrected digest](.memory/wiki/memory-architecture.md),
[ADR 0001](.memory/wiki/adrs/0001-initial-stack.md).

## Why

Model-native memory (Astra's notes, Gemini's cloud memory) is locked inside each
vendor's runtime: other tools can't read it, humans can't audit it, and it dies
with the session. This system keeps knowledge as plain, human-auditable markdown
in git — readable and writable by every agent — with a local ai-memory server on
top providing MCP tools (query, typed cross-vendor handoffs, consolidation) and
background lifecycle-hook capture that survives model quota cutoffs. Keeping
active prompts small (read targeted wiki pages, not whole sources) also protects
Astra's tight ChatGPT Plus quota. See the
[architecture digest](.memory/wiki/memory-architecture.md) for the full
comparison, the corrections made to the source evaluation, and the
ai-memory-vs-memwiki rationale.

## Quick start

The bootstrap is idempotent and safe to re-run — existing content is kept, and
any file it would change is backed up first (`<file>.bak-<timestamp>`).

```bash
./init-memory-system.sh                       # initialise in the current repo
./init-memory-system.sh --dir ~/Projects/foo # or in another project
./init-memory-system.sh --help               # all flags
```

What the five steps do:

1. **Vault** — scaffolds `.memory/raw/` + `.memory/wiki/{adrs,}` and seeds the
   index, audit log, gotchas and failed-approaches ledgers.
2. **AGENTS.md** — single source of truth for instructions, read natively by
   Codex, Antigravity CLI and OpenCode (no per-vendor bridge files).
3. **ai-memory server + clients** — installs Antigravity CLI and ai-memory if
   missing, initialises the data dir, enables the systemd user unit
   (`127.0.0.1:49374`), and registers MCP + lifecycle hooks for every client in
   `--clients`.
4. **Git safeguards** — `git init` if needed; `.gitignore` keeps the vault
   tracked while ignoring MCP runtime state (`.memory/*.db`, `.memory/tmp/`).
5. **Hand-off protocol** — writes `.memory/HANDOFF.md`, the operational
   checklist for alternating between agents without context loss.

### Flags

| Flag | Default | Meaning |
| --- | --- | --- |
| `-d, --dir` | current dir | target project directory |
| `-b/-t/-l, --build/--test/--lint` | `pnpm build/test/lint` | commands recorded in AGENTS.md — replace with your repo's real commands |
| `-c, --clients` | `codex,antigravity-cli,opencode` | clients to wire (also valid: `gemini-cli`, `opencode2`) |
| `-m, --install-method` | `aur-bin` | ai-memory install: `aur-bin` \| `aur` \| `docker` \| `none` |
| `--no-hooks` | hooks on | register MCP only, skip lifecycle hooks |
| `--no-agy-install` | install on | don't install Antigravity CLI if missing |
| `--with-routing` | off | also install ai-memory's managed routing block into AGENTS.md |
| `--no-git-init` | init on | don't `git init` a non-repo target |
| `--force` | off | overwrite existing AGENTS.md / seed files (backs up first) |

### Requirements

* `git`, `curl`; `jq` only for the legacy `gemini-cli` bridge
* AUR method (default): `yay` + sudo — AUR installs need interactive
  authentication, so run the script from your terminal for the first install
* Docker method: Docker or Podman

### Per-client notes

* **Codex** — hooks need a one-time trust at the next start
  ("Hooks need review" → *Trust all and continue*).
* **Antigravity CLI** — first `agy` run completes Google Sign-In; it has no
  true session-end hook, so run `ai-memory finalize-session --agent antigravity-cli`
  after the final turn.
* **OpenCode** — config is not hot-reloaded; restart it after any MCP, plugin
  or AGENTS.md change.

## The wiki workflow

Agents working in this repo follow [AGENTS.md](AGENTS.md): read
[.memory/wiki/index.md](.memory/wiki/index.md) before complex work, record
quirks in [gotchas](.memory/wiki/gotchas.md), dead ends in
[failed approaches](.memory/wiki/failed_approaches.md), decisions as ADRs, and
log significant changes in the [audit trail](.memory/wiki/log.md). Deep-research
reports and other unedited sources go to `.memory/raw/` and are distilled into
the wiki on demand. The cross-agent session flow lives in
[.memory/HANDOFF.md](.memory/HANDOFF.md).

The script lints clean (`bash -n` + shellcheck 0.11.0).
