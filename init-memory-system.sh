#!/usr/bin/env bash
#
# init-memory-system.sh
#
# Automates the 5-step implementation plan from memory-systems-evaluation.md:
# a Karpathy-style markdown wiki + ai-memory MCP server, shared by OpenAI
# Codex (Astra), Google Antigravity CLI (agy) and OpenCode.
#
#   Step 1  .memory/ vault scaffolding + seed files
#   Step 2  AGENTS.md single source of truth (read natively by Codex, agy
#           and OpenCode)
#   Step 3  ai-memory MCP server + lifecycle hooks wiring per client
#   Step 4  Git version control & safeguards (.gitignore)
#   Step 5  Session hand-off protocol (.memory/HANDOFF.md)
#
# Idempotent: existing content is kept; files about to change are backed up
# as <file>.bak-<timestamp>. Safe to re-run.

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults (override with flags)
# ---------------------------------------------------------------------------
TARGET_DIR="$PWD"
BUILD_CMD="pnpm build"               # doc: Step 2 example commands
TEST_CMD="pnpm test"
LINT_CMD="pnpm lint"
CLIENTS="codex,antigravity-cli,opencode"
INSTALL_METHOD="aur-bin"            # ai-memory install: aur-bin | aur | docker | none
WIRE_HOOKS=1                         # 1 = also run ai-memory install-hooks per client
AGY_INSTALL=1                        # 1 = install Antigravity CLI (agy) if missing
WITH_ROUTING=0                       # 1 = ai-memory install-instructions --target AGENTS.md
GIT_INIT=1                          # 1 = git init if target is not a repo
FORCE=0                             # 1 = overwrite existing AGENTS.md / seed files

SERVER_URL="${AI_MEMORY_SERVER_URL:-http://127.0.0.1:49374}"

usage() {
  cat <<'USAGE'
Usage: init-memory-system.sh [flags]

Initialises the Karpathy-style memory system (ai-memory) from
memory-systems-evaluation.md in the target project directory.

Flags:
  -d, --dir DIR          Target project directory (default: current dir)
  -b, --build CMD        Build command for AGENTS.md  (default: pnpm build)
  -t, --test CMD         Test command for AGENTS.md   (default: pnpm test)
  -l, --lint CMD         Lint command for AGENTS.md   (default: pnpm lint)
  -c, --clients LIST     Comma-separated clients to wire
                         (default: codex,antigravity-cli,opencode)
                         (also valid: gemini-cli, opencode2)
  -m, --install-method M ai-memory install: aur-bin | aur | docker | none
  --no-hooks             Skip ai-memory install-hooks (MCP only)
  --no-agy-install       Do not install Antigravity CLI if missing
  --with-routing         Also install ai-memory managed routing into AGENTS.md
  --no-git-init          Do not run git init if target is not a repository
  --force                Overwrite existing AGENTS.md / seed files (backs up first)
  -h, --help             This help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--dir)            TARGET_DIR="$2"; shift 2 ;;
    -b|--build)          BUILD_CMD="$2"; shift 2 ;;
    -t|--test)           TEST_CMD="$2"; shift 2 ;;
    -l|--lint)           LINT_CMD="$2"; shift 2 ;;
    -c|--clients)        CLIENTS="$2"; shift 2 ;;
    -m|--install-method) INSTALL_METHOD="$2"; shift 2 ;;
    --no-hooks)          WIRE_HOOKS=0; shift ;;
    --no-agy-install)    AGY_INSTALL=0; shift ;;
    --with-routing)      WITH_ROUTING=1; shift ;;
    --no-git-init)       GIT_INIT=0; shift ;;
    --force)             FORCE=1; shift ;;
    -h|--help)           usage; exit 0 ;;
    *)                   usage >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
TS="$(date +%Y%m%d-%H%M%S)"
say()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[1;32mok\033[0m  %s\n' "$*"; }
warn() { printf '    \033[1;33m!!\033[0m  %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

backup() {                       # backup FILE — timestamped copy if it exists
  if [ -f "$1" ]; then
    cp -p "$1" "$1.bak-$TS"
    warn "backed up existing $1 -> $1.bak-$TS"
  fi
  return 0
}

write_seed() {                   # write_seed FILE — content on stdin
  local f="$1"                   # kept as-is if non-empty (unless --force)
  if [ -s "$f" ] && [ "$FORCE" != 1 ]; then
    cat > /dev/null
    ok "exists, kept: $f"
    return 0
  fi
  backup "$f"
  mkdir -p "$(dirname "$f")"
  cat > "$f"
  ok "seeded: $f"
}

yay_install() {                  # yay_install PKG — non-interactive-safe AUR install
  local flags=(--needed)
  [ -t 0 ] || flags+=(--noconfirm)
  yay -S "${flags[@]}" "$1"
}

# ---------------------------------------------------------------------------
# Step 0: preflight
# ---------------------------------------------------------------------------
command -v git >/dev/null 2>&1 || die "git is required"
[ -d "$TARGET_DIR" ] || die "target directory not found: $TARGET_DIR"
cd "$TARGET_DIR"
TODAY="$(date +%F)"
say "Initialising memory system in: $PWD"

# ---------------------------------------------------------------------------
# Step 1/5: Memory repository structure
# ---------------------------------------------------------------------------
say "Step 1/5: Memory repository structure (.memory/)"
mkdir -p .memory/raw .memory/wiki/adrs

write_seed .memory/wiki/index.md <<'EOF'
# Project Memory Index

## System Architecture & ADRs

* [Architectural Decisions](adrs/0001-initial-stack.md)

## Execution Knowledge

* [Environment & Library Gotchas](gotchas.md)
* [Failed Implementation Paths](failed_approaches.md)
EOF

write_seed .memory/wiki/log.md <<EOF
# Memory Update Log

## [$TODAY] INIT | Created project memory vault
EOF

write_seed .memory/wiki/gotchas.md <<'EOF'
# Environment & Library Gotchas
EOF

write_seed .memory/wiki/failed_approaches.md <<'EOF'
# Failed Implementation Paths
EOF

write_seed .memory/wiki/adrs/0001-initial-stack.md <<EOF
# ADR 0001: Initial Stack

Status: Proposed
Date: $TODAY

TODO: record the initial technology stack and the rationale behind it.
EOF

# ---------------------------------------------------------------------------
# Step 2/5: AGENTS.md single source of truth
# (read natively by Codex, Antigravity CLI and OpenCode; no bridge needed for
#  any of them. The doc's Step 2 bridge is applied only for legacy gemini-cli.)
# ---------------------------------------------------------------------------
say "Step 2/5: AGENTS.md single source of truth"

if [ -s AGENTS.md ] && [ "$FORCE" != 1 ]; then
  warn "AGENTS.md already exists — leaving untouched (use --force to overwrite)"
else
  backup AGENTS.md
  cat > AGENTS.md <<EOF
# Repository Instructions & Memory Protocol

## Context & Build Commands

* Build: $BUILD_CMD
* Test: $TEST_CMD
* Lint: $LINT_CMD

## Memory Management Protocol

1. BEFORE REFACTORING OR WRITING CODE:
   * Read \`.memory/wiki/index.md\` and check \`.memory/wiki/gotchas.md\`.
   * Search for prior failures in \`.memory/wiki/failed_approaches.md\` before re-attempting complex fixes.
2. DURING AND AFTER WORK:
   * If you encounter a library bug, environment quirk, or make an architectural decision, immediately record it under \`.memory/wiki/\`.
   * Log significant changes in \`.memory/wiki/log.md\` using the format: \`## [YYYY-MM-DD] ACTION | Summary\`.
   * Never store architectural decisions or quirks solely in session-private memory.
EOF
  ok "created AGENTS.md (natively read by Codex, Antigravity CLI and OpenCode)"
fi

# Legacy bridge: only when the deprecated gemini-cli is explicitly wired
case ",$CLIENTS," in
  *,gemini-cli,*)
    command -v jq >/dev/null 2>&1 || die "jq required to bridge legacy gemini-cli"
    if [ -f .gemini/settings.json ]; then
      backup .gemini/settings.json
      jq '.context = ((.context // {}) + {fileName: "AGENTS.md"})' \
        .gemini/settings.json > .gemini/settings.json.tmp
      mv .gemini/settings.json.tmp .gemini/settings.json
    else
      mkdir -p .gemini
      printf '{ "context": { "fileName": "AGENTS.md" } }\n' > .gemini/settings.json
    fi
    ok "legacy gemini-cli bridged to AGENTS.md via .gemini/settings.json"
    ;;
esac

# ---------------------------------------------------------------------------
# Step 3/5: Shared MCP memory server (ai-memory) + clients
# ---------------------------------------------------------------------------
say "Step 3/5: ai-memory MCP server + client wiring"

# 3a. Antigravity CLI (agy) — official installer, ~/.local/bin/agy
if [ "$AGY_INSTALL" = 1 ] && ! command -v agy >/dev/null 2>&1; then
  say "Installing Antigravity CLI (agy) via official installer"
  curl -fsSL https://antigravity.google/cli/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  if command -v agy >/dev/null 2>&1; then
    ok "agy installed: $(command -v agy)"
  else
    warn "agy installer ran but binary not on this shell's PATH — open a new terminal before first use"
  fi
fi

# 3b. ai-memory itself
SKIP_MCP=0
if ! command -v ai-memory >/dev/null 2>&1; then
  case "$INSTALL_METHOD" in
    aur-bin)
      say "Installing ai-memory from AUR (prebuilt binary)"
      yay_install ai-memory-bin
      ;;
    aur)
      say "Installing ai-memory from AUR (build from source)"
      yay_install ai-memory
      ;;
    docker)
      say "Installing ai-memory Docker wrapper + server container"
      mkdir -p ~/.local/bin
      wrapper_tmp="$(mktemp -d)"
      base="https://github.com/akitaonrails/ai-memory/releases/latest/download/ai-memory-wrapper"
      curl -fsSL "$base"        -o "$wrapper_tmp/ai-memory-wrapper"
      curl -fsSL "$base.sha256" -o "$wrapper_tmp/ai-memory-wrapper.sha256"
      expected="$(awk 'NR == 1 { print $1 }' "$wrapper_tmp/ai-memory-wrapper.sha256")"
      actual="$(sha256sum "$wrapper_tmp/ai-memory-wrapper" | awk '{ print $1 }')"
      [ -n "$expected" ] && [ "$actual" = "$expected" ] || die "wrapper checksum mismatch"
      install -m 0755 "$wrapper_tmp/ai-memory-wrapper" ~/.local/bin/ai-memory
      rm -rf "$wrapper_tmp"
      export PATH="$HOME/.local/bin:$PATH"
      docker run -d --name ai-memory --restart unless-stopped \
        -p 127.0.0.1:49374:49374 -v ai-memory-data:/data \
        docker.io/akitaonrails/ai-memory:latest
      ;;
    none)
      warn "ai-memory not installed and --install-method none; skipping MCP wiring"
      SKIP_MCP=1
      ;;
    *) die "unknown --install-method: $INSTALL_METHOD" ;;
  esac
fi

if [ "$SKIP_MCP" != 1 ]; then
  command -v ai-memory >/dev/null 2>&1 || die "ai-memory is not on PATH"

  # One-time data-dir init + server start — only when the server is not
  # already up. Idempotent: a running server is left untouched; the docker
  # container self-initialises; an existing config is never overwritten.
  if ! ai-memory status >/dev/null 2>&1; then
    if [ "$INSTALL_METHOD" = docker ]; then
      ok "docker container starting; waiting for it below"
    else
      if [ ! -f "$HOME/.config/ai-memory/config.toml" ]; then
        mkdir -p ~/.config/ai-memory ~/.local/share/ai-memory
        ai-memory --data-dir "$HOME/.local/share/ai-memory" \
                  --config "$HOME/.config/ai-memory/config.toml" init
        ok "initialised ai-memory data dir (~/.local/share/ai-memory)"
      fi
      if systemctl --user list-unit-files 2>/dev/null | grep -q '^ai-memory\.service'; then
        if systemctl --user enable --now ai-memory.service; then
          ok "ai-memory server enabled (systemd user unit)"
        else
          warn "systemd user unit found but could not be enabled; start the server manually:"
          warn "  ai-memory --data-dir $HOME/.local/share/ai-memory --config $HOME/.config/ai-memory/config.toml serve --transport http --bind 127.0.0.1:49374"
        fi
      else
        warn "no ai-memory systemd user unit; start the server manually:"
        warn "  ai-memory serve --transport http --bind 127.0.0.1:49374"
      fi
    fi
  else
    ok "ai-memory server already running"
  fi

  # Wait for the server before wiring clients
  server_ok=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ai-memory status >/dev/null 2>&1; then server_ok=1; break; fi
    sleep 2
  done
  if [ "$server_ok" = 1 ]; then
    ok "ai-memory server is up ($SERVER_URL)"
  else
    warn "server not reachable yet — wiring configs anyway (start it before your next session)"
  fi

  # 3c. Wire each requested client: MCP registration (+ lifecycle hooks)
  IFS=',' read -ra client_list <<< "$CLIENTS"
  for c in "${client_list[@]}"; do
    c="$(echo "$c" | xargs)"               # trim whitespace
    [ -n "$c" ] || continue
    say "Wiring client: $c"
    ai-memory install-mcp --client "$c" --apply
    ok "MCP registered for $c"
    if [ "$WIRE_HOOKS" = 1 ]; then
      ai-memory install-hooks --agent "$c" --apply
      ok "lifecycle hooks installed for $c"
    fi
  done

  if [ "$WITH_ROUTING" = 1 ]; then
    ai-memory install-instructions --target AGENTS.md
    ok "ai-memory managed routing added to AGENTS.md"
  fi

  say "Server status"
  ai-memory status || warn "ai-memory status failed"
  case ",$CLIENTS," in
    *,gemini-cli,*)
      command -v gemini >/dev/null 2>&1 && { gemini mcp list || warn "gemini mcp list failed"; }
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# Step 4/5: Git version control & safeguards
# ---------------------------------------------------------------------------
say "Step 4/5: Git version control & safeguards"
if [ "$GIT_INIT" = 1 ] && ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init
  ok "initialised git repository"
fi
if ! grep -q '^!.memory/wiki/' .gitignore 2>/dev/null; then
  backup .gitignore
  cat >> .gitignore <<'EOF'

# Keep compiled knowledge tracked in Git
!.memory/raw/
!.memory/wiki/

# Ignore local temporary agent/SQLite indexes if generated by MCP runtime
.memory/*.db
.memory/tmp/
EOF
  ok "updated .gitignore"
else
  ok ".gitignore already configured"
fi

# ---------------------------------------------------------------------------
# Step 5/5: Session hand-off protocol
# ---------------------------------------------------------------------------
say "Step 5/5: Session hand-off protocol"
write_seed .memory/HANDOFF.md <<'EOF'
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
EOF

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
say "Done. Memory system initialised in: $PWD"
cat <<EOF

Files:
  .memory/raw/                      raw source material (deep-research reports, etc.)
  .memory/wiki/index.md             map of content
  .memory/wiki/log.md               audit trail
  .memory/wiki/gotchas.md           environment & library gotchas
  .memory/wiki/failed_approaches.md failed implementation paths
  .memory/wiki/adrs/0001-initial-stack.md
  .memory/HANDOFF.md                session hand-off protocol
  AGENTS.md                         shared instructions (Codex + Antigravity + OpenCode)
  .gitignore                        wiki tracked; runtime state ignored

Next steps:
  1. Review the build/test/lint commands in AGENTS.md.
  2. Run agy once in a terminal to complete Google Sign-In (first launch).
  3. Restart any running opencode / Codex / agy sessions to pick up MCP + hooks
     (opencode in particular does not hot-reload its config).
  4. Sanity check: in Codex, agy or opencode, ask the agent to list its MCP
     tools and call memory_status.
  5. Commit the vault:
       git add -A
       git commit -m "docs(memory): initialise project memory vault"
EOF
