#!/usr/bin/env bash
# Рассылка сертификата на фронты и reload nginx
set -euo pipefail

DOM=DOMAIN
SRC=/etc/letsencrypt
TARGETS=(IP IP2)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/deploy-cert.log"

# Функция для логирования
log_message() {
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[${timestamp}] $1" >> "$LOG_FILE"
  echo "$1"
}

log_message "==== Начало процесса обновления сертификатов ===="
log_message "Домен: $DOM"

SSH_KEY=/home/deploy/.ssh/cert-deploy
SSH_OPTS="-i $SSH_KEY -o IdentitiesOnly=yes \
          -o UserKnownHostsFile=/home/deploy/.ssh/known_hosts"

# Отключаем немедленное завершение скрипта при ошибке в командах внутри цикла
set +e

for host in "${TARGETS[@]}"; do
  log_message "[*] → $host"

  # 1. Передаём ВСЕ .pem-файлы из live (симлинки → реальные файлы благодаря -L)
  log_message "  Копирование основных сертификатов..."
  if rsync -aL -e "ssh $SSH_OPTS" \
        --rsync-path="sudo rsync" \
        --chmod=600 \
        "$SRC/live/$DOM/fullchain.pem" \
        "$SRC/live/$DOM/privkey.pem"   \
        "$SRC/live/$DOM/cert.pem"      \
        "$SRC/live/$DOM/chain.pem"     \
        deploy@"$host":/etc/letsencrypt/live/$DOM/; then
    log_message "  ✓ Основные сертификаты скопированы"
  else
    log_message "  ✗ Ошибка копирования основных сертификатов на $host"
    # Пропускаем текущий хост и переходим к следующему
    continue
  fi

  # 2. Передаём общие файлы (если вдруг обновятся)
  log_message "  Копирование дополнительных файлов..."
  if rsync -aL -e "ssh $SSH_OPTS" \
        --rsync-path="sudo rsync" \
        "$SRC/options-ssl-nginx.conf" \
        "$SRC/ssl-dhparams.pem" \
        deploy@"$host":/etc/letsencrypt/; then
    log_message "  ✓ Дополнительные файлы скопированы"
  else
    log_message "  ✗ Ошибка копирования дополнительных файлов на $host"
    continue
  fi

  # 3. Проверяем конфиг и перезагружаем nginx
  log_message "  Проверка и перезагрузка nginx..."
  if ssh $SSH_OPTS deploy@"$host" '
      sudo nginx -t >/dev/null &&
      sudo systemctl reload nginx &&
      echo "   ✓ nginx перезагружен"
  '; then
    log_message "  ✓ Nginx успешно перезагружен"
  else
    log_message "  ✗ Ошибка проверки/перезагрузки Nginx на $host"
    continue
  fi
done

# Возвращаем строгий режим
set -e

log_message "==== Завершение процесса обновления сертификатов ====\n"