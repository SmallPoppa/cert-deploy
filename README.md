# Скрипт и инструкция по деплою сертификатов LE на ноды с мейна

Подготовка мейна
- устанока сертбота (удобный вариант)

1 · Мастер: создаём пользователя deploy и SSH‑ключ

```
sudo adduser --disabled-password --gecos "" deploy
sudo -u deploy ssh-keygen -t ed25519 -N '' -f /home/deploy/.ssh/cert-deploy
```

2 · Фронты: создаём того же deploy и вставляем ключ

```
sudo adduser --disabled-password --gecos "" deploy
sudo mkdir -p /home/deploy/.ssh
echo 'ВПИСЫВАЕМ ПОЛУЧЕННЫЙ РАНЕЕ КЛЮЧ' | sudo tee /home/deploy/.ssh/authorized_keys
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 700  /home/deploy/.ssh
sudo chmod 600  /home/deploy/.ssh/authorized_keys
```
### sudo‑права для rsync и reload nginx

```
echo 'deploy ALL=(root) NOPASSWD: /usr/bin/rsync, /usr/bin/systemctl reload nginx, /usr/sbin/nginx -t' | \
  sudo tee /etc/sudoers.d/deploy-cert
```

### Каталог под сертификаты

```
sudo mkdir -p /etc/letsencrypt/live/domain.com
sudo chown root:root /etc/letsencrypt -R
sudo chmod 700 /etc/letsencrypt /etc/letsencrypt/live /etc/letsencrypt/live/domain.com
```

3 · Мастер: заносим фронты в known_hosts

```
sudo -u deploy ssh-keyscan -H IP  >> /home/deploy/.ssh/known_hosts
sudo -u deploy ssh-keyscan -H IP2  >> /home/deploy/.ssh/known_hosts
```

4 · Мастер: копируем и меняем скрипт

```
nano /usr/local/bin/deploy-cert.sh
```

Вставляем содержимое скрипта, меняем DOMAIN и прописываем IP нод (через пробел)

```
sudo chmod +x /usr/local/bin/deploy-cert.sh
```

5 · Привязываем к продлению Certbot

```
sudo mkdir -p /etc/letsencrypt/renewal-hooks/deploy
sudo ln -sf /usr/local/bin/deploy-cert.sh \
            /etc/letsencrypt/renewal-hooks/deploy/00-cert-to-node
```

6 · Тестируем

```
sudo /usr/local/bin/deploy-cert.sh
```
➜ должно вывести строки ✓ nginx перезагружен

Скрипт будет запускаться с мейн сервера за счет сертбота, при обновлении сертификатов, переносить их на ноды (именно сертификат, не симлинки) и перезагружать nginx.

Планирую добавить логирование, уведомление, ретраи если нода недоступна.
