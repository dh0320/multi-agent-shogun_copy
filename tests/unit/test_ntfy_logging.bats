#!/usr/bin/env bats
# test_ntfy_logging.bats — ntfy.shログ出力機能のユニットテスト
#
# テスト構成:
#   T-NLOG-001: 送信成功時にSUCCESSログが記録される
#   T-NLOG-002: 送信失敗時にFAILEDログが記録される
#   T-NLOG-003: ログにタイムスタンプが含まれる
#   T-NLOG-004: ログにメッセージ内容が含まれる

setup_file() {
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

setup() {
    export TEST_TMPDIR="$(mktemp -d "$BATS_TMPDIR/ntfy_log_test.XXXXXX")"
    export MOCK_PROJECT="$TEST_TMPDIR/mock_project"
    export MOCK_BIN="$TEST_TMPDIR/mock_bin"

    mkdir -p "$MOCK_PROJECT"/{config,lib,scripts,logs}
    mkdir -p "$MOCK_BIN"

    # settings.yaml with test topic
    cat > "$MOCK_PROJECT/config/settings.yaml" << 'YAML'
ntfy_topic: "test-log-topic-12345"
YAML

    # Empty auth
    touch "$MOCK_PROJECT/config/ntfy_auth.env"

    # Copy real ntfy_auth.sh
    cp "$PROJECT_ROOT/lib/ntfy_auth.sh" "$MOCK_PROJECT/lib/"

    # Create test ntfy.sh with SCRIPT_DIR override
    sed "s|^SCRIPT_DIR=.*|SCRIPT_DIR=\"$MOCK_PROJECT\"|" \
        "$PROJECT_ROOT/scripts/ntfy.sh" \
        > "$MOCK_PROJECT/scripts/ntfy_test.sh"
    chmod +x "$MOCK_PROJECT/scripts/ntfy_test.sh"

    # PATH with mock curl first
    export PATH="$MOCK_BIN:$PATH"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# Helper: create mock curl returning given HTTP code
create_mock_curl() {
    local http_code="$1"
    cat > "$MOCK_BIN/curl" << CURL_MOCK
#!/bin/bash
echo "response body"
echo "$http_code"
CURL_MOCK
    chmod +x "$MOCK_BIN/curl"
}

# ═══════════════════════════════════════════════════════════════
# T-NLOG-001: Success response logs SUCCESS
# ═══════════════════════════════════════════════════════════════

@test "T-NLOG-001: Success response logs SUCCESS" {
    create_mock_curl 200
    run bash "$MOCK_PROJECT/scripts/ntfy_test.sh" "test message"
    [ "$status" -eq 0 ]
    [ -f "$MOCK_PROJECT/logs/ntfy_send.log" ]
    grep -q "SUCCESS" "$MOCK_PROJECT/logs/ntfy_send.log"
}

# ═══════════════════════════════════════════════════════════════
# T-NLOG-002: Failed response logs FAILED and exits non-zero
# ═══════════════════════════════════════════════════════════════

@test "T-NLOG-002: Failed response logs FAILED and exits non-zero" {
    create_mock_curl 500
    run bash "$MOCK_PROJECT/scripts/ntfy_test.sh" "test message"
    [ "$status" -ne 0 ]
    grep -q "FAILED" "$MOCK_PROJECT/logs/ntfy_send.log"
}

# ═══════════════════════════════════════════════════════════════
# T-NLOG-003: Log contains timestamp
# ═══════════════════════════════════════════════════════════════

@test "T-NLOG-003: Log contains timestamp" {
    create_mock_curl 200
    bash "$MOCK_PROJECT/scripts/ntfy_test.sh" "timestamp test"
    # Timestamp format: [YYYY-MM-DD HH:MM:SS]
    grep -qE '\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' \
        "$MOCK_PROJECT/logs/ntfy_send.log"
}

# ═══════════════════════════════════════════════════════════════
# T-NLOG-004: Log contains message content
# ═══════════════════════════════════════════════════════════════

@test "T-NLOG-004: Log contains message content" {
    create_mock_curl 200
    bash "$MOCK_PROJECT/scripts/ntfy_test.sh" "unique-msg-42xyz"
    grep -q "unique-msg-42xyz" "$MOCK_PROJECT/logs/ntfy_send.log"
}
