# uesama

<div align="center">

**Multi-Agent Orchestration System for Claude Code**

*One command. Eight AI agents working in parallel.*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet)](https://claude.ai)
[![tmux](https://img.shields.io/badge/tmux-required-green)](https://github.com/tmux/tmux)

[English](README.md) | [日本語](README_ja.md)

</div>

---

## What is this?

**uesama** is a CLI tool that runs multiple Claude Code instances simultaneously, organized like a feudal Japanese war council.

Install once, use in any project directory.

```
        You (The Lord / 上様)
             │
             ▼ Give orders
      ┌─────────────┐
      │   DAIMYO    │  ← Receives your command, delegates immediately
      │   (大名)    │
      └──────┬──────┘
             │ YAML files + tmux
      ┌──────▼──────┐
      │    SANBO    │  ← Distributes tasks to workers
      │   (参謀)    │
      └──────┬──────┘
             │
    ┌─┬─┬─┬─┴─┬─┬─┬─┐
    │1│2│3│4│5│6│7│8│  ← 8 workers execute in parallel
    └─┴─┴─┴─┴─┴─┴─┴─┘
        KASHIN (家臣)
```

---

## Quick Start

### Prerequisites

- **tmux** — `brew install tmux` (macOS) / `sudo apt install tmux` (Linux)
- **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`

### Install

```bash
git clone https://github.com/y-nishizaki/multi-agent-shogun.git uesama
cd uesama
./install.sh
source ~/.zshrc  # or ~/.bashrc
```

### Use

```bash
cd /your/project
uesama              # Start all agents
uesama-daimyo       # Attach to Daimyo (commander) session
uesama-agents       # Attach to Sanbo + Kashin (workers) session
```

### Uninstall

```bash
cd uesama
./uninstall.sh
```

---

## How It Works

1. `uesama` creates a `.uesama/` directory in your project
2. Launches two tmux sessions: `daimyo` (1 pane) and `kashindan` (9 panes)
3. Starts Claude Code on all 10 agents
4. Agents communicate via YAML files and tmux send-keys (event-driven, no polling)
5. Check progress in `.uesama/dashboard.md`

---

## Architecture

| Agent | Role | Count |
|-------|------|-------|
| Daimyo (大名) | Commander — receives your orders, delegates to Sanbo | 1 |
| Sanbo (参謀) | Strategist — decomposes tasks, assigns to Kashin | 1 |
| Kashin (家臣) | Workers — execute tasks in parallel | 8 |

---

## Credits

Based on [multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) by yohey-w, which was inspired by [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa.

## License

MIT License — See [LICENSE](LICENSE) for details.
