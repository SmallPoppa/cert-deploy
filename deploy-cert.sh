#!/usr/bin/env bash
# Рассылка сертификата на фронты и reload nginx
set -euo pipefail

DOM=DOMAIN
SRC=/etc/letsencrypt
TARGETS=(IP IP2)

SSH_KEY=/home/deploy/.ssh/cert-deploy
SSH_OPTS="-i $SSH_KEY -o IdentitiesOnly=yes \
          -o UserKnownHostsFile=/home/deploy/.ssh/known_hosts \
          -o StrictHostKeyChecking=no"

for host in "${TARGETS[@]}"; do
  echo "[*] → $host"

  # 1. Передаём ВСЕ .pem-файлы из live (симлинки → реальные файлы благодаря -L)
  rsync -aL -e "ssh $SSH_OPTS" \
        --rsync-path="sudo rsync" \
        --chmod=600 \
        "$SRC/live/$DOM/fullchain.pem" \
        "$SRC/live/$DOM/privkey.pem"   \
        "$SRC/live/$DOM/cert.pem"      \
        "$SRC/live/$DOM/chain.pem"     \
        deploy@"$host":/etc/letsencrypt/live/$DOM/

  # 2. Передаём общие файлы (если вдруг обновятся)
  rsync -aL -e "ssh $SSH_OPTS" \
        --rsync-path="sudo rsync" \
        "$SRC/options-ssl-nginx.conf" \
        "$SRC/ssl-dhparams.pem" \
        deploy@"$host":/etc/letsencrypt/

  # 3. Проверяем конфиг и перезагружаем nginx
  ssh $SSH_OPTS deploy@"$host" '
      sudo nginx -t >/dev/null &&
      sudo systemctl reload nginx &&
      echo "   ✓ nginx перезагружен" ||
      { echo "   ✗ nginx конфиг ERROR" ; exit 1; }
  '
done
