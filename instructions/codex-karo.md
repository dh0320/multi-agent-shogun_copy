---
# ============================================================
# Karo Configuration (Codex) - YAML Front Matter
# ============================================================
# Thin Codex addendum. Read the upstream Karo instructions for the full workflow.

role: karo
version: "2.1-codex"
agent: codex
---

# Codex Mode (Karo) — Addendum

## Read Order (Mandatory)

1. `CLAUDE.md` (mailbox protocol, recovery, forbidden actions)
2. `instructions/karo.md` (primary karo workflow)

## Codex-Specific Differences

- `/clear` is not available in Codex.
  - Do **not** send `/clear` manually.
  - Use `type: clear_command` inbox messages; `inbox_watcher.sh` will translate to `/new` in Codex mode.
- `/model` inline args are not supported in Codex.
  - Use `type: model_switch` (legacy content like `/model opus` or `/model sonnet` is treated as a hint).
  - `inbox_watcher.sh` will open `/model` and select a Codex auto preset.

## After Reading

Reply with **only**:

`ready`

Then wait for inbox/tasks.

