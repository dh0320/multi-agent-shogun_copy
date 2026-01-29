# ============================================================
# multi-agent-shogun Makefile
# ============================================================
# Unified interface for common operations.
#
# Usage:
#   make install    - Run full installation
#   make start      - Start all agents
#   make stop       - Stop all tmux sessions
#   make check      - Check prerequisites
#   make help       - Show available commands
# ============================================================

.PHONY: all install start stop check clean config help status attach-shogun attach-multiagent

# Default target
all: help

# Show help
help:
	@echo ""
	@echo "multi-agent-shogun - Available commands:"
	@echo ""
	@echo "  make install          - Run full installation"
	@echo "  make install-deps     - Install dependencies only"
	@echo "  make start            - Start all agents (full deployment)"
	@echo "  make start-setup      - Setup tmux sessions only (no Claude)"
	@echo "  make stop             - Stop all tmux sessions"
	@echo "  make check            - Check prerequisites"
	@echo "  make config           - Regenerate configuration"
	@echo "  make status           - Show tmux session status"
	@echo "  make attach-shogun    - Attach to shogun session"
	@echo "  make attach-multi     - Attach to multiagent session"
	@echo "  make clean            - Clean generated files"
	@echo "  make help             - Show this help"
	@echo ""

# Full installation
install:
	@./install.sh

# Install dependencies only
install-deps:
	@./install.sh --deps-only

# Start all agents
start:
	@./start.sh

# Start setup only (no Claude launch)
start-setup:
	@./start.sh -s

# Stop all sessions
stop:
	@echo "Stopping tmux sessions..."
	@tmux kill-session -t shogun 2>/dev/null || echo "  shogun: not running"
	@tmux kill-session -t multiagent 2>/dev/null || echo "  multiagent: not running"
	@echo "Done."

# Check prerequisites
check:
	@./install.sh --check

# Regenerate configuration
config:
	@./install.sh --config-only

# Show status
status:
	@echo ""
	@echo "Tmux Sessions:"
	@tmux list-sessions 2>/dev/null || echo "  No sessions running"
	@echo ""

# Attach to shogun session
attach-shogun:
	@tmux attach-session -t shogun

# Attach to multiagent session
attach-multi:
	@tmux attach-session -t multiagent

# Clean generated files (keeps templates and config)
clean:
	@echo "Cleaning generated files..."
	@rm -f config/settings.yaml.bak.*
	@rm -rf logs/*
	@rm -f queue/shogun_to_karo.yaml
	@rm -f queue/karo_to_ashigaru.yaml
	@rm -f queue/tasks/*.yaml
	@rm -f queue/reports/*.yaml
	@rm -f dashboard.md
	@echo "Done."

# Alias for attach-multi
attach-multiagent: attach-multi
