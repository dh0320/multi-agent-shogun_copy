# multi-agent-kairai

<div align="center">

**Multi-Agent Orchestration System for Claude Code**

*One command. Eight AI agents working in parallel.*

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet)](https://claude.ai)
[![tmux](https://img.shields.io/badge/tmux-required-green)](https://github.com/tmux/tmux)

[English](README.md) | [Japanese / 日本語](README_ja.md)

</div>

---

## What is this?

**multi-agent-kairai** is a system that runs multiple Claude Code instances simultaneously, organized like a feudal Japanese army.

**Why use this?**
- Give one command, get 8 AI workers executing in parallel
- No waiting - you can keep giving commands while tasks run in background
- AI remembers your preferences across sessions (Memory MCP)
- Real-time progress tracking via dashboard

```
        You (The Lord)
             │
             ▼ Give orders
      ┌─────────────┐
      │   KAIRAI    │  ← Receives your command, delegates immediately
      └──────┬──────┘
             │ YAML files + tmux
      ┌──────▼──────┐
      │    PULONIA     │  ← Distributes tasks to workers
      └──────┬──────┘
             │
    ┌─┬─┬─┬─┴─┬─┬─┬─┐
    │1│2│3│4│5│6│7│8│  ← 8 workers execute in parallel
    └─┴─┴─┴─┴─┴─┴─┴─┘
        BOSCO
```

---

## 🚀 Quick Start

### 🪟 Windows Users (Most Common)

<table>
<tr>
<td width="60">

**Step 1**

</td>
<td>

📥 **Download this repository**

[Download ZIP](https://github.com/yohey-w/multi-agent-kairai/archive/refs/heads/main.zip) and extract to `C:\tools\multi-agent-kairai`

*Or use git:* `git clone https://github.com/yohey-w/multi-agent-kairai.git C:\tools\multi-agent-kairai`

</td>
</tr>
<tr>
<td>

**Step 2**

</td>
<td>

🖱️ **Run `install.bat`**

Right-click and select **"Run as administrator"** (required if WSL2 is not yet installed). The installer will guide you through each step — you may need to restart your PC or set up Ubuntu before re-running.

</td>
</tr>
<tr>
<td>

**Step 3**

</td>
<td>

🐧 **Open Ubuntu and run** (first time only)

```bash
cd /mnt/c/tools/multi-agent-kairai
./first_setup.sh
```

</td>
</tr>
<tr>
<td>

**Step 4**

</td>
<td>

✅ **Deploy!**

```bash
./mission_start.sh
```

</td>
</tr>
</table>

#### 📅 Daily Startup (After First Install)

Open **Ubuntu terminal** (WSL) and run:

```bash
cd /mnt/c/tools/multi-agent-kairai
./mission_start.sh
```

---

<details>
<summary>🐧 <b>Linux / Mac Users</b> (Click to expand)</summary>

### First-Time Setup

```bash
# 1. Clone the repository
git clone https://github.com/yohey-w/multi-agent-kairai.git ~/multi-agent-kairai
cd ~/multi-agent-kairai

# 2. Make scripts executable
chmod +x *.sh

# 3. Run first-time setup
./first_setup.sh
```

### Daily Startup

```bash
cd ~/multi-agent-kairai
./mission_start.sh
```

</details>

---

<details>
<summary>❓ <b>What is WSL2? Why do I need it?</b> (Click to expand)</summary>

### About WSL2

**WSL2 (Windows Subsystem for Linux)** lets you run Linux inside Windows. This system uses `tmux` (a Linux tool) to manage multiple AI agents, so WSL2 is required on Windows.

### Don't have WSL2 yet?

No problem! When you run `install.bat`, it will:
1. Check if WSL2 is installed (auto-install if missing)
2. Check if Ubuntu is installed (auto-install if missing)
3. Guide you to the next steps (`first_setup.sh`)

**Quick install command** (run in PowerShell as Administrator):
```powershell
wsl --install
```

Then restart your computer and run `install.bat` again.

</details>

---

<details>
<summary>🎩 <b>Script Reference</b> (Click to expand)</summary>

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `install.bat` | Windows: WSL2 + Ubuntu setup | First time only |
| `first_setup.sh` | Installs tmux, Node.js, Claude Code CLI + configures Memory MCP | First time only |
| `mission_start.sh` | Creates tmux sessions + starts Claude/Codex + loads instructions | Every day |

### What `install.bat` does automatically:
- ✅ Checks if WSL2 is installed (auto-install if missing)
- ✅ Checks if Ubuntu is installed (auto-install if missing)
- ✅ Guides you to the next steps (`first_setup.sh`)

### What `mission_start.sh` does:
- ✅ Creates tmux sessions (kairai + multiagent)
- ✅ Launches Claude Code for Kairai/Pulonia
- ✅ Launches Bosco with fixed engines (1-4: Claude / 5-8: Codex)
- ✅ If Codex is not installed, Bosco 5-8 fall back to Claude
- ✅ Automatically loads instruction files for each agent
- ✅ Resets queue files for a fresh start

**After running, all agents are ready to receive commands immediately!**

</details>

---

<details>
<summary>🔧 <b>Prerequisites (for manual setup)</b> (Click to expand)</summary>

If you prefer to install dependencies manually:

| Requirement | How to install | Notes |
|-------------|----------------|-------|
| WSL2 + Ubuntu | `wsl --install` in PowerShell | Windows only |
| Set Ubuntu as default | `wsl --set-default Ubuntu` | Required for scripts to work |
| tmux | `sudo apt install tmux` | Terminal multiplexer |
| Node.js v20+ | `nvm install 20` | Required for Claude Code CLI |
| Claude Code CLI | `npm install -g @anthropic-ai/claude-code` | Anthropic's official CLI |
| Codex CLI | `npm install -g @openai/codex` | Used by Bosco 5-8 |

</details>

---

### ✅ What Happens After Setup

After running either option, **AI agents** will start automatically:

| Agent | Role | Quantity |
|-------|------|----------|
| 🫖 KAIRAI (Kairai) | Commander - receives your orders | 1 |
| 🎩 Pulonia (Pulonia) | Manager - distributes tasks | 1 |
| 🤖 Bosco (Bosco) | Workers - execute tasks in parallel | 8 |

You'll see tmux sessions created:
- `kairai` - Connect here to give commands
- `multiagent` - Workers running in background

---

## 📖 Basic Usage

### Step 1: Connect to KAIRAI (Kairai)

After running `mission_start.sh`, all agents automatically load their instructions and are ready to work.

Open a new terminal and connect to the KAIRAI (Kairai):

```bash
tmux attach-session -t kairai
```

### Step 2: Give Your First Order

The KAIRAI (Kairai) is already initialized! Just give your command:

```
Investigate the top 5 JavaScript frameworks and create a comparison table.
```

The KAIRAI (Kairai) will:
1. Write the task to a YAML file
2. Notify the Pulonia (Pulonia) (manager)
3. Return control to you immediately (you don't have to wait!)

Meanwhile, the Pulonia (Pulonia) distributes the work to Bosco (Bosco) workers who execute in parallel.

### Step 3: Check Progress

Open `dashboard.md` in your editor to see real-time status:

```markdown
## In Progress
| Worker | Task | Status |
|--------|------|--------|
| Bosco (Bosco) 1 | React research | Running |
| Bosco (Bosco) 2 | Vue research | Running |
| Bosco (Bosco) 3 | Angular research | Done |
```

---

## ✨ Key Features

### ⚡ 1. Parallel Execution

One command can spawn up to 8 parallel tasks:

```
You: "Research 5 MCP servers"
→ 5 Bosco (Bosco) start researching simultaneously
→ Results ready in minutes, not hours
```

### 🔄 2. Non-Blocking Workflow

The KAIRAI (Kairai) delegates immediately and returns control to you:

```
You: Give order → KAIRAI (Kairai): Delegates → You: Can give next order immediately
                                           ↓
                         Workers: Execute in background
                                           ↓
                         Dashboard: Shows results
```

You never have to wait for long tasks to complete.

### 🧠 3. Memory Across Sessions (Memory MCP)

The AI remembers your preferences:

```
Session 1: You say "I prefer simple solutions"
           → Saved to Memory MCP

Session 2: AI reads memory at startup
           → Won't suggest over-engineered solutions
```

**Memory MCP is owned by the Claude side (Kairai/Pulonia).**  
Bosco (Codex side) does not read learning memory and only executes assigned tasks.

### 📡 4. Event-Driven (No Polling)

Agents communicate via YAML files and wake each other with tmux send-keys.
**No API calls are wasted on polling loops.**

### 📸 5. Screenshot Support

VSCode's Claude Code extension lets you paste screenshots to explain issues. This CLI system brings the same capability:

```
# Configure your screenshot folder in config/settings.yaml
screenshot:
  path: "/mnt/c/Users/YourName/Pictures/Screenshots"

# Then just tell the KAIRAI (Kairai):
You: "Check the latest screenshot"
You: "Look at the last 2 screenshots"
→ AI reads and analyzes your screenshots instantly
```

**💡 Windows Tip:** Press `Win + Shift + S` to take a screenshot. Configure the save location to match your `settings.yaml` path for seamless integration.

Perfect for:
- Explaining UI bugs visually
- Showing error messages
- Comparing before/after states

### 🧠 Model Configuration

| Agent | Model | Thinking | Reason |
|-------|-------|----------|--------|
| KAIRAI (Kairai) | Opus | Disabled | Delegation & dashboard updates don't need deep reasoning |
| Pulonia (Pulonia) | Default | Enabled | Task distribution requires careful judgment |
| Bosco (Bosco) | Default | Enabled | Actual implementation needs full capabilities |

The KAIRAI (Kairai) uses `MAX_THINKING_TOKENS=0` to disable extended thinking, reducing latency and cost while maintaining Opus-level judgment for high-level decisions.

### 📁 Context Management

The system uses a three-layer context structure for efficient knowledge sharing:

| Layer | Location | Purpose |
|-------|----------|---------|
| Memory MCP | `memory/kairai_memory.jsonl` | Persistent memory across sessions (preferences, decisions) |
| Global | `memory/global_context.md` | System-wide settings, user preferences |
| Project | `context/{project}.md` | Project-specific knowledge and state |

This design allows:
- Any Bosco (Bosco) to pick up work on any project
- Consistent context across agent switches
- Clear separation of concerns
- Knowledge persistence across sessions

### Universal Context Template

All projects use the same 7-section template:

| Section | Purpose |
|---------|---------|
| What | Brief description of the project |
| Why | Goals and success criteria |
| Who | Stakeholders and responsibilities |
| Constraints | Deadlines, budget, limitations |
| Current State | Progress, next actions, blockers |
| Decisions | Decision log with rationale |
| Notes | Free-form notes and insights |

This standardized structure ensures:
- Quick onboarding for any agent
- Consistent information across all projects
- Easy handoffs between Bosco (Bosco) workers

### 🛠️ Skills

Skills are not included in this repository by default.
As you use the system, skill candidates will appear in `dashboard.md`.
Review and approve them to grow your personal skill library.

---

## 🏛️ Design Philosophy

### Why Hierarchical Structure?

The KAIRAI (Kairai) → Pulonia (Pulonia) → Bosco (Bosco) hierarchy exists for:

1. **Immediate Response**: KAIRAI (Kairai) delegates instantly and returns control to you
2. **Parallel Execution**: Pulonia (Pulonia) distributes to multiple Bosco (Bosco) simultaneously
3. **Separation of Concerns**: KAIRAI (Kairai) decides "what", Pulonia (Pulonia) decides "who"

### Why YAML + send-keys?

- **YAML files**: Structured communication that survives agent restarts
- **send-keys**: Event-driven wakeups (no polling = no wasted API calls)
- **No direct calls**: Agents can't interrupt each other or your input

### Why Only Pulonia (Pulonia) Updates Dashboard?

- **Single responsibility**: One writer = no conflicts
- **Information hub**: Pulonia (Pulonia) receives all reports, knows the full picture
- **Consistency**: All updates go through one quality gate

### How Skills Work

Skills (`.claude/commands/`) are **not committed to this repository** by design.

**Why?**
- Each user's workflow is different
- Skills should grow organically based on your needs
- No one-size-fits-all solution

**How to create new skills:**
1. Bosco (Bosco) report "skill candidates" when they notice repeatable patterns
2. Candidates appear in `dashboard.md` under "Skill Candidates"
3. You review and approve (or reject)
4. Approved skills are created by Pulonia (Pulonia)

This keeps skills **user-driven** — only what you find useful gets added.

---

## 🔌 MCP Setup Guide

MCP (Model Context Protocol) servers extend Claude's capabilities. Here's how to set them up:

### What is MCP?

MCP servers give Claude access to external tools:
- **Notion MCP** → Read/write Notion pages
- **GitHub MCP** → Create PRs, manage issues
- **Memory MCP** → Remember things across sessions

### Installing MCP Servers

Run these commands to add MCP servers:

```bash
# 1. Notion - Connect to your Notion workspace
claude mcp add notion -e NOTION_TOKEN=your_token_here -- npx -y @notionhq/notion-mcp-server

# 2. Playwright - Browser automation
claude mcp add playwright -- npx @playwright/mcp@latest
# Note: Run `npx playwright install chromium` first

# 3. GitHub - Repository operations
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_pat_here -- npx -y @modelcontextprotocol/server-github

# 4. Sequential Thinking - Step-by-step reasoning for complex problems
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

# 5. Memory - Long-term memory across sessions (Recommended!)
# ✅ Automatically configured by first_setup.sh
# To reconfigure manually:
claude mcp add memory -e MEMORY_FILE_PATH="$PWD/memory/kairai_memory.jsonl" -- npx -y @modelcontextprotocol/server-memory
```

### Verify Installation

```bash
claude mcp list
```

You should see all servers with "Connected" status.

---

## 🌍 Real-World Use Cases

### Example 1: Research Task

```
You: "Research the top 5 AI coding assistants and compare them"

What happens:
1. KAIRAI (Kairai) delegates to Pulonia (Pulonia)
2. Pulonia (Pulonia) assigns:
   - Bosco (Bosco) 1: Research GitHub Copilot
   - Bosco (Bosco) 2: Research Cursor
   - Bosco (Bosco) 3: Research Claude Code
   - Bosco (Bosco) 4: Research Codeium
   - Bosco (Bosco) 5: Research Amazon CodeWhisperer
3. All 5 research simultaneously
4. Results compiled in dashboard.md
```

### Example 2: PoC Preparation

```
You: "Prepare a PoC for the project in this Notion page: [URL]"

What happens:
1. Pulonia (Pulonia) fetches Notion content via MCP
2. Bosco (Bosco) 2: Lists items to clarify
3. Bosco (Bosco) 3: Researches technical feasibility
4. Bosco (Bosco) 4: Creates PoC plan document
5. All results in dashboard.md, ready for your meeting
```

---

## ⚙️ Configuration

### Language Setting

Edit `config/settings.yaml`:

```yaml
language: ja   # Japanese only
language: en   # Japanese + English translation
```

---

## 🛠️ Advanced Usage

<details>
<summary><b>Script Architecture</b> (Click to expand)</summary>

```
┌─────────────────────────────────────────────────────────────────────┐
│                      FIRST-TIME SETUP (Run Once)                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  install.bat (Windows)                                              │
│      │                                                              │
│      ├── Check/Install WSL2                                         │
│      └── Check/Install Ubuntu                                       │
│                                                                     │
│  first_setup.sh (run manually in Ubuntu/WSL)                        │
│      │                                                              │
│      ├── Check/Install tmux                                         │
│      ├── Check/Install Node.js v20+ (via nvm)                      │
│      ├── Check/Install Claude Code CLI                              │
│      └── Configure Memory MCP server                                │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                      DAILY STARTUP (Run Every Day)                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  mission_start.sh                                             │
│      │                                                              │
│      ├──▶ Create tmux sessions                                      │
│      │         • "kairai" session (1 pane)                          │
│      │         • "multiagent" session (9 panes, 3x3 grid)           │
│      │                                                              │
│      ├──▶ Reset queue files and dashboard                           │
│      │                                                              │
│      └──▶ Launch Claude/Codex (Kairai/Pulonia=Claude, Bosco fixed)   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

</details>

<details>
<summary><b>mission_start.sh Options</b> (Click to expand)</summary>

```bash
# Default: Full startup (tmux sessions + Claude/Codex launch)
./mission_start.sh

# Session setup only (without launching CLI)
./mission_start.sh -s
./mission_start.sh --setup-only

# Full startup + open Windows Terminal tabs
./mission_start.sh -t
./mission_start.sh --terminal

# Show help
./mission_start.sh -h
./mission_start.sh --help
```

</details>

<details>
<summary><b>Common Workflows</b> (Click to expand)</summary>

**Normal Daily Usage:**
```bash
./mission_start.sh          # Start everything
tmux attach-session -t kairai     # Connect to give commands
```

**Debug Mode (manual control):**
```bash
./mission_start.sh -s       # Create sessions only

# Manually start CLI on specific agents
tmux send-keys -t kairai:0 'claude --dangerously-skip-permissions' Enter
tmux send-keys -t multiagent:0.0 'claude --dangerously-skip-permissions' Enter
```

**Restart After Crash:**
```bash
# Kill existing sessions
tmux kill-session -t kairai
tmux kill-session -t multiagent

# Start fresh
./mission_start.sh
```

</details>

---

## 📁 File Structure

<details>
<summary><b>Click to expand file structure</b></summary>

```
multi-agent-kairai/
│
│  ┌─────────────────── SETUP SCRIPTS ───────────────────┐
├── install.bat               # Windows: First-time setup
├── first_setup.sh            # Ubuntu/Mac: First-time setup
├── mission_start.sh    # Daily startup (auto-loads instructions)
│  └────────────────────────────────────────────────────┘
│
├── instructions/             # Agent instruction files
│   ├── kairai.md             # Commander instructions
│   ├── pulonia.md               # Manager instructions
│   └── bosco.md           # Worker instructions
│
├── config/
│   └── settings.yaml         # Language and other settings
│
├── queue/                    # Communication files
│   ├── kairai_to_pulonia.yaml   # Commands from KAIRAI (Kairai) to Pulonia (Pulonia)
│   ├── tasks/                # Individual worker task files
│   └── reports/              # Worker reports
│
├── memory/                   # Memory MCP storage
├── dashboard.md              # Real-time status overview
└── CLAUDE.md                 # Project context for Claude
```

</details>

---

## 🔧 Troubleshooting

<details>
<summary><b>MCP tools not working?</b></summary>

MCP tools are "deferred" and need to be loaded first:

```
# Wrong - tool not loaded
mcp__memory__read_graph()  ← Error!

# Correct - load first
ToolSearch("select:mcp__memory__read_graph")
mcp__memory__read_graph()  ← Works!
```

</details>

<details>
<summary><b>Agents asking for permissions?</b></summary>

Make sure to start with `--dangerously-skip-permissions`:

```bash
claude --dangerously-skip-permissions --system-prompt "..."
```

</details>

<details>
<summary><b>Workers stuck?</b></summary>

Check the worker's pane:
```bash
tmux attach-session -t multiagent
# Use Ctrl+B then number to switch panes
```

</details>

---

## 📚 tmux Quick Reference

| Command | Description |
|---------|-------------|
| `tmux attach -t kairai` | Connect to KAIRAI (Kairai) |
| `tmux attach -t multiagent` | Connect to workers |
| `Ctrl+B` then `0-8` | Switch between panes |
| `Ctrl+B` then `d` | Detach (leave running) |
| `tmux kill-session -t kairai` | Stop KAIRAI (Kairai) session |
| `tmux kill-session -t multiagent` | Stop worker sessions |

---

## 🙏 Credits

Based on [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa.

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

<div align="center">

**Command your AI army. Build faster.**

</div>
