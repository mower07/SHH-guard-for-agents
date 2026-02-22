#!/bin/bash
# Деплой security monitoring на новый сервер
# Использование: ./onboard-server.sh root@IP "Label"
# Пример: ./onboard-server.sh root@1.2.3.4 "Staging"

SERVER="$1"
LABEL="${2:-Server}"

if [ -z "$SERVER" ]; then
  echo "Использование: $0 user@host \"Метка\""
  exit 1
fi

SCRIPTS_DIR="/root/scripts/security"

echo "🚀 Деплой на $SERVER (метка: $LABEL)..."

# Создать директорию и скопировать файлы
ssh "$SERVER" "mkdir -p /root/scripts/security/pending"

# Скопировать .env_secrets и whitelist
scp "$SCRIPTS_DIR/.env_secrets" "${SERVER}:/root/.env_secrets"
scp "$SCRIPTS_DIR/whitelist-ips.conf" "${SERVER}:/root/scripts/security/whitelist-ips.conf"
scp "$SCRIPTS_DIR/pending-check.sh" "${SERVER}:/root/scripts/security/pending-check.sh"

# Создать ssh-alert.sh с нужным лейблом
sed "s/SERVER_LABEL=\"MyServer\"/SERVER_LABEL=\"$LABEL\"/" \
  "$SCRIPTS_DIR/ssh-alert.sh" | \
  sed "s|WHITELIST=\"/root/scripts/security/whitelist-ips.conf\"|WHITELIST=\"/root/scripts/security/whitelist-ips.conf\"|" | \
  ssh "$SERVER" "cat > /root/scripts/security/ssh-alert.sh"

# Права
ssh "$SERVER" "chmod 700 /root/scripts/security/{ssh-alert,pending-check}.sh && chmod 600 /root/.env_secrets"

# PAM hook
ssh "$SERVER" "grep -q 'ssh-alert' /etc/pam.d/sshd || echo 'session optional pam_exec.so /root/scripts/security/ssh-alert.sh' >> /etc/pam.d/sshd"

# Cron
ssh "$SERVER" "(crontab -l 2>/dev/null | grep -v 'pending-check\|monitor\|port-check'; \
  echo '* * * * * /root/scripts/security/pending-check.sh') | crontab -"

# Добавить в список серверов
echo "$SERVER" >> "$SCRIPTS_DIR/servers.conf"

echo "✅ $SERVER готов. Проверь UAW и добавь правило ufw allow 22/tcp если нужно."
