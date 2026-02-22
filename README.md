# SSH Guard — мониторинг и защита серверов через Telegram

Набор bash-скриптов для VPS/выделенных серверов под управлением Ubuntu/Debian.
Уведомляет в Telegram о каждом SSH-входе, блокирует неизвестные IP автоматически.

---

## Кому поможет

- Разработчикам и системным администраторам с VPS
- Тем, у кого несколько серверов и нет времени смотреть логи
- Тем, кто хочет знать о подозрительных входах в реальном времени

---

## Что внутри

### Уведомления о SSH-входах
- Известный IP → обычный алерт с меткой: `🔐 SSH вход на Server-1 | myserver (95.X.X.X) — Admin (1.2.3.4)`
- Неизвестный IP → вопрос в Telegram: "Это ты? ДА/НЕТ"
- Нет ответа 5 минут → IP автоматически блокируется через UFW + алерт о блокировке

### Мониторинг сервисов
Каждые 5 минут проверяет что сервисы живые. Если упал — пишет в Telegram.

### Мониторинг диска и памяти
Алерт при заполнении диска >80% или памяти >90%.

### Проверка аномальных портов
Раз в сутки сравнивает открытые порты с эталоном. Если появился новый порт — алерт.

### Масштабируемость
Единый белый список IP для всех серверов. Добавить новый сервер — одна команда.

---

## Требования

- Ubuntu/Debian с UFW
- Telegram-бот (создать через @BotFather, получить токен)
- SSH-доступ к серверу с ключом (без пароля)

---

## Быстрый старт

### 1. Создать Telegram-бота
- Написать @BotFather → `/newbot`
- Сохранить токен
- Узнать свой Telegram ID: написать @userinfobot

### 2. Заполнить `.env_secrets`
```bash
cp .env_secrets.template /root/.env_secrets
nano /root/.env_secrets
# Вставить TG_BOT_TOKEN и TG_OWNER_ID
chmod 600 /root/.env_secrets
```

### 3. Развернуть на первом сервере
```bash
# Создать директорию
mkdir -p /root/scripts/security/pending

# Скопировать скрипты
cp *.sh /root/scripts/security/
cp whitelist-ips.conf servers.conf /root/scripts/security/
chmod 700 /root/scripts/security/*.sh

# SSH-алерт через PAM
echo 'session optional pam_exec.so /root/scripts/security/ssh-alert.sh' >> /etc/pam.d/sshd

# Cron
(crontab -l 2>/dev/null; \
  echo "*/5 * * * * /root/scripts/security/monitor.sh"; \
  echo "0 8 * * * /root/scripts/security/port-check.sh"; \
  echo "* * * * * /root/scripts/security/pending-check.sh"; \
  echo "*/5 * * * * /root/scripts/security/sync-whitelist.sh") | crontab -
```

### 4. Добавить свой IP в белый список
```bash
echo "1.2.3.4 Имя" >> /root/scripts/security/whitelist-ips.conf
```

### 5. Добавить следующий сервер
```bash
# С первого сервера:
./onboard-server.sh root@IP "Метка"
# Например:
./onboard-server.sh root@95.X.X.X "Server-1"
```

---

## Настройка `ssh-alert.sh`

В начале скрипта поменять:
```bash
SERVER_LABEL="MyServer"   # Метка этого сервера в уведомлениях
```

В `monitor.sh` поменять список сервисов:
```bash
SERVICES="nginx postgresql myapp"   # Ваши сервисы
```

---

## Как работает белый список

Файл `whitelist-ips.conf`:
```
1.2.3.4 Admin
157.X.X.X RemoteAgent
```

При входе скрипт ищет IP в списке:
- Нашёл → `Откуда: Admin (1.2.3.4)` без вопросов
- Не нашёл → спрашивает подтверждение, создаёт `.pending` файл

Ответ "ДА" → добавить IP вручную в `whitelist-ips.conf`.
Ответ "НЕТ" или молчание 5 мин → `ufw insert 1 deny from IP`.

---

## Структура файлов

```
scripts/
├── ssh-alert.sh          # PAM-хук: алерт при SSH-входе
├── pending-check.sh      # Автоблокировка по таймауту
├── monitor.sh            # Мониторинг сервисов + диск + память
├── port-check.sh         # Аномальные порты
├── sync-whitelist.sh     # Синхронизация whitelist на все серверы
├── onboard-server.sh     # Деплой на новый сервер
├── whitelist-ips.conf    # Белый список IP
├── servers.conf          # Список серверов для синхронизации
└── .env_secrets.template # Шаблон токенов
```

---

## Известные ограничения

- Блокировка через UFW (`ufw insert 1 deny from IP`) — блокирует весь трафик с IP, не только SSH
- Ответ "ДА" на вопрос о неизвестном IP нужно обрабатывать вручную (добавить в whitelist)
- `monitor.sh` — список сервисов нужно прописать под каждый сервер отдельно
- Белый список IP не учитывает динамические IP (например, мобильный интернет)

---

Сделано в феврале 2026. Работает на Ubuntu 22.04 / 24.04.
