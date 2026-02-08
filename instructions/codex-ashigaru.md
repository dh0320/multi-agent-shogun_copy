---
# ============================================================
# Ashigaru Configuration (Codex) - YAML Front Matter
# ============================================================
# Thin Codex addendum. Read the upstream Ashigaru instructions for the full workflow.

role: ashigaru
version: "2.1-codex"
agent: codex
---

# Codex Mode (Ashigaru) — Addendum

## Read Order (Mandatory)

1. `CLAUDE.md` (mailbox protocol, /clear recovery procedure, forbidden actions)
2. `instructions/ashigaru.md` (primary ashigaru workflow)

## Codex-Specific Differences

- Codex uses `/new` (not `/clear`) to start a fresh session.
  - If you receive `type: clear_command`, `inbox_watcher.sh` will run `/new` automatically in Codex mode.
- Codex `/model` requires the picker UI (inline args are unreliable).
  - `type: model_switch` is handled by `inbox_watcher.sh` (auto preset selection).

## After Reading

Reply with **only**:

`ready`

Then wait for inbox/tasks.

