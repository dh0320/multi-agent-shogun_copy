#!/bin/bash
# SayTask通知 — ntfy.sh経由でスマホにプッシュ通知
# FR-066: ntfy認証対応 (Bearer token / Basic auth)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="$SCRIPT_DIR/config/settings.yaml"

# ntfy_auth.sh読み込み
# shellcheck source=../lib/ntfy_auth.sh
source "$SCRIPT_DIR/lib/ntfy_auth.sh"

TOPIC=$(grep 'ntfy_topic:' "$SETTINGS" | awk '{print $2}' | tr -d '"')
if [ -z "$TOPIC" ]; then
  echo "ntfy_topic not configured in settings.yaml" >&2
  exit 1
fi

# 認証引数を取得（設定がなければ空 = 後方互換）
AUTH_ARGS=()
while IFS= read -r line; do
    [ -n "$line" ] && AUTH_ARGS+=("$line")
done < <(ntfy_get_auth_args "$SCRIPT_DIR/config/ntfy_auth.env")

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/ntfy_send.log"

# shellcheck disable=SC2086
RESPONSE=$(curl -s -w "\n%{http_code}" "${AUTH_ARGS[@]}" -H "Tags: outbound" -d "$1" "https://ntfy.sh/$TOPIC")
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ] 2>/dev/null; then
  echo "[$TIMESTAMP] SUCCESS (HTTP $HTTP_CODE): $1" >> "$LOG_FILE"
else
  echo "[$TIMESTAMP] FAILED (HTTP $HTTP_CODE): $1" >> "$LOG_FILE"
  exit 1
fi
