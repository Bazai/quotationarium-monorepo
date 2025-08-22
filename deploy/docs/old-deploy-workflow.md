# Описание

Два приложения (django и next.js) хостятся внутри Digital Ocean Droplet. Расположены в папках `/opt/collector` (django) и `/opt/collect_front` (next.js)

На сервере запущены через pm2 и systemctl соответственно. Сервятся в веб через nginx с настройкой (etc/nginx/sites-enabled)

```
server {
    server_name expo.timuroki.ink;

    location /static/ {
        alias /var/opt/collector/static/;
    }
    location /_next/ {
        alias /opt/collect_front/.next/;
        expires 30d;
        access_log on;
    }
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    location /admin/ {
        include proxy_params;
        proxy_pass http://unix:/run/collector.sock;
    }
    location /api/ {
        include proxy_params;
        proxy_pass http://unix:/run/collector.sock;
    }


    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/expo.timuroki.ink/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/expo.timuroki.ink/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = expo.timuroki.ink) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80;
    server_name expo.timuroki.ink;
    return 404; # managed by Certbot

}
```

Приложения деплоятся каждый из своего отдельного git репозитория

# Текущий подход к деплою приложения

## Deploy Frontend

1. подключиться через Degital Ocean Web Terminal
2. добавить github deploy key `eval "$(ssh-agent -s)" && ssh-add ~/.ssh/github_id_rsa`
3. `cd /opt/collect_front`
4. `git fetch && git pull`
5. `pm2 stop app` (проверить, что приложение стопнулось через `pm2 list`)
6. `npm install`
7. `npm run build` (обязательно дождаться сообщения со списком чанков)

   ```jsx
    ✓ Generating static pages (4/4)
    ✓ Collecting build traces
    ✓ Finalizing page optimization
   ```

8. `pm2 start app`

## Deploy Backend (Django)

1. подключиться через Degital Ocean Web Terminal
2. добавить github deploy key `eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa_django`
3. `cd /opt/collector`
4. `git fetch && git pull`
5. `systemctl restart collector.service`

# Проблемы текущего подхода

1. 2 отдельных репозитория
   - Решение в текущем проекте
2. Деплой фронтенда не возможен без build фазы. А поскольку RAM в digital ocean droplet сильно ограничен, наивный запуск `npm run build` отнимает все доступные ресурсы, и другие хостящиеся приложения "повисают"
3. Нет механизма rollback-a и особенно быстрого rollback-a/ в случае критичных ошибок

# Необходимо

1. Реализовать документацию и скрипты, для pull-деплоя изнутри DO Dropleta (pull из одного репозитория с последующим)
2. Реализовать скрипт для билда фронтенда с ограничением на использование ядер процессора и памяти
3. Скрипты для rollback-a неудачного деплоя
