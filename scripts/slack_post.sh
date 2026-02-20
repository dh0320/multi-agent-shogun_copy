#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Slack投稿スクリプト
# Usage:
#   bash scripts/slack_post.sh "メッセージ"                                → 殿のDMに送信
#   bash scripts/slack_post.sh --channel "チャンネルID" "メッセージ"        → チャンネルに投稿
#   bash scripts/slack_post.sh --delete --channel "チャンネルID" --ts "TS"  → メッセージ削除
#   bash scripts/slack_post.sh --update --channel "チャンネルID" --ts "TS" "新メッセージ" → メッセージ修正
#
# ⚠️ デフォルトは殿のDM宛。チャンネル投稿は明示的に --channel 指定が必要。
# ═══════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 機密情報フィルター: メッセージ本文に認証情報等が含まれていないかチェック
check_sensitive_content() {
    local msg="$1"
    # Slackトークン、認証情報、AWSキー、秘密鍵のパターン
    local pattern='xoxb-|xapp-|xoxp-|xoxs-|Bearer |password|secret|api_key=|token=|credential|AKIA|aws_secret|-----BEGIN (PRIVATE KEY|RSA|EC|DSA)'
    if echo "$msg" | grep -iqE "$pattern"; then
        echo "[slack_post] ⚠️ 機密情報の可能性があるためブロックしました" >&2
        exit 1
    fi
}

CREDS_FILE="$SCRIPT_DIR/projects/slack_credentials.yaml"

# 認証情報読み込み（grep + awk でシンプルに）
BOT_TOKEN=$(grep 'bot_token:' "$CREDS_FILE" | awk '{print $2}' | tr -d '"')
DEFAULT_DM_USER=$(grep 'default_dm_user:' "$CREDS_FILE" | awk '{print $2}' | tr -d '"')

if [ -z "$BOT_TOKEN" ]; then
    echo "[slack_post] エラー: bot_tokenが取得できません" >&2
    exit 1
fi

# 引数パース
CHANNEL=""
THREAD_TS=""
FORCE_NEW=""
MESSAGE=""
MODE="post"
TARGET_TS=""

while [ $# -gt 0 ]; do
    case "$1" in
        --channel)
            CHANNEL="$2"
            shift 2
            ;;
        --thread_ts)
            THREAD_TS="$2"
            shift 2
            ;;
        --force-new)
            FORCE_NEW="1"
            shift
            ;;
        --delete)
            MODE="delete"
            shift
            ;;
        --update)
            MODE="update"
            shift
            ;;
        --ts)
            TARGET_TS="$2"
            shift 2
            ;;
        *)
            MESSAGE="$1"
            shift
            ;;
    esac
done

# ─── delete モード ───
if [ "$MODE" = "delete" ]; then
    if [ -z "$CHANNEL" ] || [ -z "$TARGET_TS" ]; then
        echo "Usage: slack_post.sh --delete --channel \"チャンネルID\" --ts \"TS\"" >&2
        exit 1
    fi

    export SLACK_CHANNEL="$CHANNEL"
    export SLACK_TARGET_TS="$TARGET_TS"

    PAYLOAD=$(python3 -c "
import json, os
payload = {
    'channel': os.environ['SLACK_CHANNEL'],
    'ts': os.environ['SLACK_TARGET_TS']
}
print(json.dumps(payload))
" 2>/dev/null)

    RESPONSE=$(curl -s -X POST "https://slack.com/api/chat.delete" \
        -H "Authorization: Bearer $BOT_TOKEN" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "$PAYLOAD")

    DELETE_OK=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null)

    if [ "$DELETE_OK" = "True" ]; then
        echo "[slack_post] 削除成功 (ts: $TARGET_TS)" >&2
    else
        ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error', 'unknown'))" 2>/dev/null)
        echo "[slack_post] 削除失敗: $ERROR" >&2
        echo "$RESPONSE" >&2
        exit 1
    fi
    exit 0
fi

# ─── update モード ───
if [ "$MODE" = "update" ]; then
    if [ -z "$CHANNEL" ] || [ -z "$TARGET_TS" ] || [ -z "$MESSAGE" ]; then
        echo "Usage: slack_post.sh --update --channel \"チャンネルID\" --ts \"TS\" \"新メッセージ\"" >&2
        exit 1
    fi

    # 送信前に機密情報チェック
    check_sensitive_content "$MESSAGE"

    export SLACK_CHANNEL="$CHANNEL"
    export SLACK_TARGET_TS="$TARGET_TS"
    export SLACK_MESSAGE="$MESSAGE"

    PAYLOAD=$(python3 -c "
import json, os
payload = {
    'channel': os.environ['SLACK_CHANNEL'],
    'ts': os.environ['SLACK_TARGET_TS'],
    'text': os.environ['SLACK_MESSAGE']
}
print(json.dumps(payload))
" 2>/dev/null)

    RESPONSE=$(curl -s -X POST "https://slack.com/api/chat.update" \
        -H "Authorization: Bearer $BOT_TOKEN" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "$PAYLOAD")

    UPDATE_OK=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null)

    if [ "$UPDATE_OK" = "True" ]; then
        echo "[slack_post] 更新成功 (ts: $TARGET_TS)" >&2
    else
        ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error', 'unknown'))" 2>/dev/null)
        echo "[slack_post] 更新失敗: $ERROR" >&2
        echo "$RESPONSE" >&2
        exit 1
    fi
    exit 0
fi

# ─── post モード（既存ロジック） ───
if [ -z "$MESSAGE" ]; then
    echo "Usage: slack_post.sh [--channel \"チャンネル名\"] \"メッセージ\"" >&2
    exit 1
fi

# 投稿先決定
if [ -n "$CHANNEL" ]; then
    # チャンネル指定あり: チャンネル名をそのまま使用
    TARGET_CHANNEL="$CHANNEL"
    echo "[slack_post] チャンネル投稿: #$CHANNEL" >&2
else
    # デフォルト: 殿のDMに送信
    # conversations.open APIでIM channel IDを取得
    echo "[slack_post] DM送信先: $DEFAULT_DM_USER" >&2

    export SLACK_DM_USER="$DEFAULT_DM_USER"
    OPEN_PAYLOAD=$(python3 -c "
import json, os
print(json.dumps({'users': os.environ['SLACK_DM_USER']}))
" 2>/dev/null)

    OPEN_RESPONSE=$(curl -s -X POST "https://slack.com/api/conversations.open" \
        -H "Authorization: Bearer $BOT_TOKEN" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "$OPEN_PAYLOAD")

    OPEN_OK=$(echo "$OPEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null)

    if [ "$OPEN_OK" != "True" ]; then
        echo "[slack_post] エラー: conversations.open 失敗" >&2
        echo "$OPEN_RESPONSE" >&2
        exit 1
    fi

    TARGET_CHANNEL=$(echo "$OPEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['channel']['id'])" 2>/dev/null)

    if [ -z "$TARGET_CHANNEL" ]; then
        echo "[slack_post] エラー: DM channel ID取得失敗" >&2
        exit 1
    fi

    echo "[slack_post] DM channel ID: $TARGET_CHANNEL" >&2
fi

# 送信前に機密情報チェック
check_sensitive_content "$MESSAGE"

# chat.postMessage API呼び出し
# JSONペイロードをpython3で安全に組み立て（メッセージ内の特殊文字対策）
export SLACK_CHANNEL="$TARGET_CHANNEL"
export SLACK_MESSAGE="$MESSAGE"
export SLACK_THREAD_TS="$THREAD_TS"
export SLACK_FORCE_NEW="$FORCE_NEW"

PAYLOAD=$(python3 -c "
import json, os
payload = {
    'channel': os.environ['SLACK_CHANNEL'],
    'text': os.environ['SLACK_MESSAGE'],
    'icon_emoji': ':crossed_swords:',
    'username': '将軍'
}
thread_ts = os.environ.get('SLACK_THREAD_TS', '')
force_new = os.environ.get('SLACK_FORCE_NEW', '')
if thread_ts and not force_new:
    payload['thread_ts'] = thread_ts
print(json.dumps(payload))
" 2>/dev/null)

RESPONSE=$(curl -s -X POST "https://slack.com/api/chat.postMessage" \
    -H "Authorization: Bearer $BOT_TOKEN" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "$PAYLOAD")

# レスポンス確認
POST_OK=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok', False))" 2>/dev/null)

if [ "$POST_OK" = "True" ]; then
    TS=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ts', ''))" 2>/dev/null)
    echo "$TS"
    echo "[slack_post] 投稿成功 (ts: $TS)" >&2
else
    ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error', 'unknown'))" 2>/dev/null)
    echo "[slack_post] 投稿失敗: $ERROR" >&2
    echo "$RESPONSE" >&2
    exit 1
fi
