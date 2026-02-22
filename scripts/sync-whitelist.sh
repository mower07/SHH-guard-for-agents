#!/bin/bash
# Синхронизирует master whitelist на все серверы из servers.conf

MASTER="/root/scripts/security/whitelist-ips.conf"
SERVERS="/root/scripts/security/servers.conf"

while IFS= read -r server; do
  # Пропустить пустые строки и комментарии
  [[ -z "$server" || "$server" == \#* ]] && continue
  scp -q "$MASTER" "${server}:/root/scripts/security/whitelist-ips.conf" 2>/dev/null
done < "$SERVERS"
