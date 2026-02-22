#!/bin/bash
source ~/scripts/security/.env_secrets

HOST=$(hostname -s)
SNAPSHOT_FILE=~/scripts/security/ports-baseline.txt
CURRENT=$(ss -tlnp | grep LISTEN | awk '{print $4}' | sort)

if [ ! -f "$SNAPSHOT_FILE" ]; then
  echo "$CURRENT" > "$SNAPSHOT_FILE"
  exit 0
fi

BASELINE=$(cat "$SNAPSHOT_FILE")
DIFF=$(diff <(echo "$BASELINE") <(echo "$CURRENT"))

if [ -n "$DIFF" ]; then
  DATE=$(date '+%d.%m.%Y %H:%M')
  MSG="🔍 <b>${HOST}</b> — изменение портов (${DATE}):\n<pre>${DIFF}</pre>"
  curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TG_OWNER_ID}" \
    --data-urlencode "text=$(echo -e "$MSG")" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1
  echo "$CURRENT" > "$SNAPSHOT_FILE"
fi
