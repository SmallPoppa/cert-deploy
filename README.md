# Скрипт и инструкция по деплою сертификатов LE на ноды с мейна

**Важное замечание.** Я не программист, не кодер, просто пытаюсь сделать как мне (прежде всего) понятно и удобно.  
Данный способ не является лучшим (но, надеюсь, является хотя бы технически верным) для работы с сертификатами на нодах.  
Все описанное можно заменить любым другим вариантом или даже просто ручным копированием сертификатов и перезапуском nginx.

Подготовка мейна
- устанока сертбота (удобный вариант)

1 · Мастер: создаём пользователя deploy и SSH‑ключ

```
sudo adduser --disabled-password --gecos "" deploy
sudo -u deploy ssh-keygen -t ed25519 -N '' -f /home/deploy/.ssh/cert-deploy
```

2 · Фронты: создаём того же deploy и вставляем ключ из /home/deploy/.ssh/cert-deploy.pub

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

4 · Мастер: копируем и меняем скрипт на мейн сервере

```
nano /opt/deploy-cert/deploy-cert.sh
```

Вставляем содержимое скрипта, меняем DOMAIN и прописываем IP нод (через пробел)

```
sudo chmod +x /opt/deploy-cert/deploy-cert.sh
```

5 ·Создаем crontab запись для выполнения скрипта раз в сутки в 4 утра (желательно создать запись для certbot на более раннее время, например, 3 часа)

```
echo "0 4 * * * /opt/deploy-cert/deploy-cert.sh" | sudo -u deploy crontab -
```

6 · Тестируем

```
sudo /usr/local/bin/deploy-cert.sh
```
➜ должно вывести строки ✓ nginx перезагружен

Скрипт будет запускаться с мейн сервера по вашему расписанию (сейчас раз в день, ночью), копировать сертификаты на ноды и перезагружать nginx. Если какой-то сервер будет недоступен, его скрипт отработает только в следующий раз (ретраев нет и не планирую). Недоступные сервера не прерывают работу скрипта.

Планирую в дальнейшем улучшить логирование и добавить уведомления о результате работы скрипта.
