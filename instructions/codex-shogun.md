---
# ============================================================
# Shogun Configuration (Codex) - YAML Front Matter
# ============================================================
# Structured metadata. This file is a thin Codex addendum that defers to the
# upstream shogun instructions for the main workflow.

role: shogun
version: "2.1-codex"
agent: codex
---

# Codex Mode (Shogun) — Addendum

## Read Order (Mandatory)

1. `CLAUDE.md` (mailbox protocol, recovery, forbidden actions)
2. `instructions/shogun.md` (primary shogun workflow)

## Codex-Specific Differences

- Codex does not have `/clear`.
  - If you receive `type: clear_command`, the infrastructure (`inbox_watcher.sh`) will run `/new` instead.
- Codex does not support inline args for `/model` (e.g. `"/model opus"` typed as chat can be treated as a normal message).
  - If you receive `type: model_switch`, the infrastructure maps it to Codex `/model` auto presets.
- If Codex looks "idle" after startup, ensure you received the initial bootstrap prompt and replied once; `--enable steer` makes Enter submit immediately.

## After Reading

Reply with **only**:

`ready`

Then wait for tasks (inbox/tasks).

