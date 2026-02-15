#!/bin/bash
# watcher_supervisor.sh - Starts and monitors all inbox_watchers
# Run this in a dedicated tmux window to keep watchers alive
# Compatible with bash 3.x (macOS default)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

mkdir -p "$SCRIPT_DIR/logs"

# Agent configurations (parallel arrays instead of associative array)
AGENTS=("shogun" "karo" "ashigaru1" "ashigaru2" "ashigaru3" "ashigaru4" "ashigaru5" "ashigaru6" "ashigaru7" "ashigaru8")
PANES=("shogun:main" "multiagent:agents.0" "multiagent:agents.1" "multiagent:agents.2" "multiagent:agents.3" "multiagent:agents.4" "multiagent:agents.5" "multiagent:agents.6" "multiagent:agents.7" "multiagent:agents.8")
PIDS=()

echo "=== Watcher Supervisor Started ==="
echo "Press Ctrl+C to stop all watchers"
echo ""

# Function to start a watcher and return PID
start_watcher() {
    local idx="$1"
    local agent="${AGENTS[$idx]}"
    local target="${PANES[$idx]}"
    local cli=$(tmux show-options -p -t "$target" -v @agent_cli 2>/dev/null || echo "claude")
    local logfile="$SCRIPT_DIR/logs/inbox_watcher_${agent}.log"

    if [ "$agent" = "shogun" ]; then
        ASW_DISABLE_ESCALATION=1 ASW_PROCESS_TIMEOUT=0 \
            bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" "$agent" "$target" "$cli" >> "$logfile" 2>&1 &
    else
        bash "$SCRIPT_DIR/scripts/inbox_watcher.sh" "$agent" "$target" "$cli" >> "$logfile" 2>&1 &
    fi
    echo $!
}

# Start all watchers
for i in 0 1 2 3 4 5 6 7 8 9; do
    pid=$(start_watcher $i)
    PIDS[$i]=$pid
    echo "[$(date +%H:%M:%S)] Started ${AGENTS[$i]} (PID: $pid)"
done

echo ""
echo "All watchers started. Monitoring..."
echo ""

# Monitor and restart dead watchers
while true; do
    sleep 30
    for i in 0 1 2 3 4 5 6 7 8 9; do
        pid="${PIDS[$i]}"

        if ! kill -0 "$pid" 2>/dev/null; then
            echo "[$(date +%H:%M:%S)] ${AGENTS[$i]} died (was PID $pid), restarting..."
            new_pid=$(start_watcher $i)
            PIDS[$i]=$new_pid
            echo "[$(date +%H:%M:%S)] ${AGENTS[$i]} restarted (PID: $new_pid)"
        fi
    done
done
