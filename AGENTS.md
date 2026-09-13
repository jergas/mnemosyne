# Repository Instructions & Memory Protocol

## Context & Build Commands

* Build: none (markdown + shell-script repository)
* Test: bash -n init-memory-system.sh
* Lint: shellcheck init-memory-system.sh

## Memory Management Protocol

1. BEFORE REFACTORING OR WRITING CODE:
   * Read `.memory/wiki/index.md` and check `.memory/wiki/gotchas.md`.
   * Search for prior failures in `.memory/wiki/failed_approaches.md` before re-attempting complex fixes.
2. DURING AND AFTER WORK:
   * If you encounter a library bug, environment quirk, or make an architectural decision, immediately record it under `.memory/wiki/`.
   * Log significant changes in `.memory/wiki/log.md` using the format: `## [YYYY-MM-DD] ACTION | Summary`.
   * Never store architectural decisions or quirks solely in session-private memory.
