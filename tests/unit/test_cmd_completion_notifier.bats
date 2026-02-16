#!/usr/bin/env bats
# test_cmd_completion_notifier.bats — cmd完了通知daemonのユニットテスト
#
# テスト構成:
#   T-CCN-001: 新規doneコマンドがntfy送信される
#   T-CCN-002: 通知済みコマンドは重複送信されない
#   T-CCN-003: status=in_progressのコマンドは通知されない
#   T-CCN-004: 複数のdoneコマンドがまとめて通知される
#   T-CCN-005: notified_cmds.txtに通知済みIDが記録される
#   T-CCN-006: shogun_to_karo.yamlが存在しない場合エラーなし
#   T-CCN-007: ntfy.sh失敗時にnotified記録されない

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    [ -x "$PROJECT_ROOT/.venv/bin/python3" ] || skip "python3 not found in .venv"
}

setup() {
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/ccn_test.XXXXXX")"
    export MOCK_PROJECT="$TEST_TMPDIR/mock_project"
    export NTFY_LOG="$TEST_TMPDIR/ntfy_calls.log"

    mkdir -p "$MOCK_PROJECT"/{scripts,queue,logs,.venv/bin,config,lib}

    # python3 symlink
    ln -sf "$PROJECT_ROOT/.venv/bin/python3" "$MOCK_PROJECT/.venv/bin/python3"

    # mock ntfy.sh: log calls instead of sending
    cat > "$MOCK_PROJECT/scripts/ntfy.sh" << 'MOCK'
#!/bin/bash
echo "$1" >> "$NTFY_LOG"
exit ${MOCK_NTFY_EXIT_CODE:-0}
MOCK
    chmod +x "$MOCK_PROJECT/scripts/ntfy.sh"

    # Empty notified file
    touch "$MOCK_PROJECT/queue/notified_cmds.txt"
    touch "$NTFY_LOG"
    touch "$MOCK_PROJECT/logs/cmd_completion_notifier.log"

    # Source the script in testing mode
    export __CMD_NOTIFIER_TESTING__=1
    export SCRIPT_DIR="$MOCK_PROJECT"
    export QUEUE_FILE="$MOCK_PROJECT/queue/shogun_to_karo.yaml"
    export NOTIFIED_FILE="$MOCK_PROJECT/queue/notified_cmds.txt"
    export LOG_FILE="$MOCK_PROJECT/logs/cmd_completion_notifier.log"
    export NTFY_SCRIPT="$MOCK_PROJECT/scripts/ntfy.sh"

    # Source the actual script functions
    source "$PROJECT_ROOT/scripts/cmd_completion_notifier.sh"

    # Default: ntfy.sh succeeds
    unset MOCK_NTFY_EXIT_CODE
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# Helper: create shogun_to_karo.yaml with given commands
create_queue() {
    cat > "$QUEUE_FILE" << EOF
commands:
$1
EOF
}

# ═══════════════════════════════════════════════════════════════
# T-CCN-001: New done command triggers ntfy notification
# ═══════════════════════════════════════════════════════════════

@test "T-CCN-001: New done command triggers ntfy notification" {
    create_queue "
- id: cmd_100
  status: done
  purpose: \"Test command completed\"
"
    run process_done_cmds
    [ "$status" -eq 0 ]
    [ -s "$NTFY_LOG" ]
    grep -q "cmd_100" "$NTFY_LOG"
}

# ═══════════════════════════════════════════════════════════════
# T-CCN-002: Already notified command is NOT sent again
# ═══════════════════════════════════════════════════════════════

@test "T-CCN-002: Already notified command is NOT sent again" {
    echo "cmd_100" > "$NOTIFIED_FILE"
    create_queue "
- id: cmd_100
  status: done
  purpose: \"Already notified\"
"
    run process_done_cmds
    [ "$status" -eq 0 ]
    [ ! -s "$NTFY_LOG" ]
}

# ═══════════════════════════════════════════════════════════════
# T-CCN-003: In-progress command is NOT notified
# ═══════════════════════════════════════════════════════════════

@test "T-CCN-003: In-progress command is NOT notified" {
    create_queue "
- id: cmd_101
  status: in_progress
  purpose: \"Still working\"
"
    run process_done_cmds
    [ "$status" -eq 0 ]
    [ ! -s "$NTFY_LOG" ]
}

# ═══════════════════════════════════════════════════════════════
# T-CCN-004: Multiple done commands are all notified
# ═══════════════════════════════════════════════════════════════

@test "T-CCN-004: Multiple done commands are all notified" {
    create_queue "
- id: cmd_200
  status: done
  purpose: \"First done\"
- id: cmd_201
  status: done
  purpose: \"Second done\"
- id: cmd_202
  status: in_progress
  purpose: \"Not done yet\"
"
    run process_done_cmds
    [ "$status" -eq 0 ]
    grep -q "cmd_200" "$NTFY_LOG"
    grep -q "cmd_201" "$NTFY_LOG"
    ! grep -q "cmd_202" "$NTFY_LOG"
}

# ═══════════════════════════════════════════════════════════════
# T-CCN-005: Notified cmd_id is recorded in notified_cmds.txt
# ═══════════════════════════════════════════════════════════════

@test "T-CCN-005: Notified cmd_id is recorded in notified_cmds.txt" {
    create_queue "
- id: cmd_300
  status: done
  purpose: \"Record test\"
"
    process_done_cmds
    grep -q "cmd_300" "$NOTIFIED_FILE"
}

# ═══════════════════════════════════════════════════════════════
# T-CCN-006: Missing queue file does not cause error
# ═══════════════════════════════════════════════════════════════

@test "T-CCN-006: Missing queue file does not cause error" {
    rm -f "$QUEUE_FILE"
    run process_done_cmds
    [ "$status" -eq 0 ]
    [ ! -s "$NTFY_LOG" ]
}

# ═══════════════════════════════════════════════════════════════
# T-CCN-007: ntfy.sh failure prevents notified recording
# ═══════════════════════════════════════════════════════════════

@test "T-CCN-007: ntfy.sh failure prevents notified recording" {
    export MOCK_NTFY_EXIT_CODE=1
    create_queue "
- id: cmd_400
  status: done
  purpose: \"Will fail\"
"
    process_done_cmds
    ! grep -q "cmd_400" "$NOTIFIED_FILE"
}
