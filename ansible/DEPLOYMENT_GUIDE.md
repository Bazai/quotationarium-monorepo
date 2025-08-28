# Руководство по первому развертыванию

## Подготовка к первому деплою Frontend

### 1. Конфигурация сервера

#### Требования к серверу:
- Ubuntu 20.04+ или CentOS 8+
- Минимум 1GB RAM (рекомендуется 2GB+)
- Минимум 10GB свободного места
- SSH доступ с sudo правами
- Node.js 18.0.0+
- PM2 глобально установлен

#### Проверка готовности сервера:
```bash
# На сервере выполните:
node --version  # должен быть >= 18.0.0
npm --version
pm2 --version
free -h        # проверьте RAM
df -h          # проверьте место на диске
```

### 2. Настройка локального окружения

#### Установка зависимостей:
```bash
# Установите Ansible
pip install ansible

# Проверьте установку
ansible --version
```

#### Конфигурация SSH:

**Важно**: Разделяйте два типа SSH ключей:
- **Ansible SSH ключ** - для подключения к серверу 
- **Deploy key** - на сервере для доступа к git репозиторию

```bash
# 1. Настройте SSH для подключения к серверу (обычный SSH ключ)
ssh-copy-id user@your-server-ip  # используйте ваш обычный ключ

# 2. Проверьте подключение
ssh user@your-server-ip

# 3. На СЕРВЕРЕ убедитесь что git deploy key настроен
# (это уже должно быть сделано, если git clone работает)
```

### 3. Настройка Ansible конфигурации

#### Обновите inventory:
Скопируйте пример и настройте под ваш сервер:
```bash
cp inventory/production.yml.example inventory/production.yml
```

Затем откройте `ansible/inventory/production.yml` и настройте:
```yaml
all:
  hosts:
    quotes-prod:
      ansible_host: YOUR_SERVER_IP
      ansible_user: YOUR_SSH_USER
      ansible_ssh_private_key_file: ~/.ssh/id_rsa  # SSH ключ для подключения к серверу
      # Если используете другой ключ для SSH доступа:
      # ansible_ssh_private_key_file: ~/.ssh/your_server_key
```

#### Настройте переменные окружения:
1. Откройте `ansible/group_vars/all/main.yml`
2. Обновите следующие параметры:
```yaml
# Repository configuration
git_repo: "https://github.com/YOUR_USERNAME/quotes-monorepo.git"

# Frontend configuration  
frontend_site_url: "http://YOUR_DOMAIN_OR_IP:3000"
frontend_health_url: "http://YOUR_DOMAIN_OR_IP:3000/"

# Backend configuration (для связи frontend с backend)
backend_api_url: "http://YOUR_DOMAIN_OR_IP:8000/api/"
```

#### Настройте секреты:
1. Установите пароль для Ansible Vault:
```bash
echo "your_secure_vault_password" > ansible/.ansible-vault-password
chmod 600 ansible/.ansible-vault-password
```

2. Зашифруйте файл с секретами:
```bash
cd ansible
./scripts/encrypt-vault.sh
```

### 4. Проверка SSH и Git конфигурации

**Проверьте SSH подключение к серверу:**

```bash
# Проверьте подключение к серверу
ssh user@your-server-ip

# На сервере проверьте git доступ (deploy key должен работать)
ssh user@your-server-ip "cd /tmp && git clone YOUR_REPO_URL test-clone && rm -rf test-clone"
```

**Если git clone не работает на сервере, настройте deploy key:**
```bash
# На сервере убедитесь что SSH agent использует правильный ключ
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa_collector_monorepo
ssh -T git@github.com  # должен показать успешную аутентификацию
```

### 5. Предварительная проверка

#### Проверьте конфигурацию:
```bash
cd ansible

# Проверьте синтаксис
ansible-playbook playbooks/deploy-frontend.yml --syntax-check

# Проверьте подключение к серверу
ansible quotes-prod -m ping

# Выполните dry-run
ansible-playbook playbooks/deploy-frontend.yml --check --diff
```

### 5. Первое развертывание Frontend

#### Выполните развертывание:
```bash
cd ansible

# Развертывание только frontend с подробным выводом
ansible-playbook playbooks/deploy-frontend.yml -v

# Или с ограничением по тегам (быстрее для тестирования)
ansible-playbook playbooks/deploy-frontend.yml --tags "frontend,health-check" -v
```

#### Мониторинг процесса:
Во время развертывания следите за выводом:
- ✅ `TASK [Pre-flight validation]` - проверки прошли
- ✅ `TASK [Clone or update repository]` - код загружен
- ✅ `TASK [Install Node.js dependencies]` - зависимости установлены
- ✅ `TASK [Build Next.js application]` - сборка завершена
- ✅ `TASK [Start Next.js service]` - сервис запущен
- ✅ `TASK [Verify frontend health]` - проверка здоровья прошла

### 6. Проверка развертывания

#### Проверьте статус сервисов:
```bash
# На сервере
pm2 status
pm2 logs collect_front --lines 20

# Проверьте доступность
curl http://localhost:3000
```

#### Проверьте в браузере:
Откройте `http://YOUR_SERVER_IP:3000` в браузере

### 7. Тестирование Rollback

#### Создайте тестовое изменение:
```bash
# Локально измените что-то в коде frontend
echo "console.log('test change')" >> frontend/pages/index.js
git add . && git commit -m "test change for rollback"
git push
```

#### Выполните повторное развертывание:
```bash
cd ansible
ansible-playbook playbooks/deploy-frontend.yml -v
```

#### Выполните откат:
```bash
# Найдите timestamp бэкапа (перед последним деплоем)
ansible quotes-prod -m find -a "paths=/opt/collector_backups/frontend patterns='*.tar.gz'"

# Выполните откат (замените TIMESTAMP на реальный)
ansible-playbook playbooks/rollback.yml -e rollback_component=frontend -e rollback_timestamp=TIMESTAMP -v
```

### 8. Частые проблемы и решения

#### Проблема: "npm install killed"
**Причина**: Недостаточно памяти
**Решение**:
```bash
# На сервере создайте swap
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

#### Проблема: "Permission denied" при SSH подключении
**Причина**: Проблемы с SSH ключами для подключения к серверу
**Решение**:
```bash
# 1. Проверьте SSH подключение к серверу
ssh user@your-server-ip

# 2. Если не работает, проверьте права на SSH ключ
chmod 600 ~/.ssh/id_rsa  # или ваш SSH ключ

# 3. Убедитесь что пользователь www-data существует на сервере
ssh user@your-server-ip "sudo useradd -r -s /bin/false www-data || true"
```

#### Проблема: "Git clone failed" во время деплоя
**Причина**: Deploy key не настроен на сервере
**Решение**:
```bash
# На сервере проверьте git доступ
ssh user@your-server-ip
# Затем на сервере:
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa_collector_monorepo
ssh -T git@github.com  # должен показать успех
```

#### Проблема: "Port 3000 already in use"
**Причина**: Сервис уже запущен
**Решение**:
```bash
# На сервере
pm2 stop collect_front
pm2 delete collect_front
# Затем повторите развертывание
```

#### Проблема: "Node.js version too old"
**Причина**: Устаревшая версия Node.js
**Решение**:
```bash
# Установите Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 9. Мониторинг и логи

#### Просмотр логов:
```bash
# PM2 логи
pm2 logs collect_front

# Ansible логи (если что-то пошло не так)
ansible-playbook playbooks/deploy-frontend.yml -v > deploy.log 2>&1
```

#### Мониторинг ресурсов:
```bash
# На сервере
htop
pm2 monit
```

### 10. Следующие шаги

После успешного развертывания frontend:

1. **Настройте мониторинг** - добавьте алерты на падение сервиса
2. **Настройте автоматические бэкапы** - cron задача для регулярных снапшотов
3. **Протестируйте CI/CD** - настройте GitHub Actions для автоматического деплоя
4. **Разверните backend** - используйте `ansible-playbook playbooks/deploy-backend.yml`
5. **Настройте reverse proxy** - nginx для production доступа

## Команды для быстрого старта

```bash
# 0. Проверка SSH подключения к серверу
ssh user@your-server-ip  # должно работать без пароля

# 1. Настройка окружения
cd ansible
echo "your_password" > .ansible-vault-password
chmod 600 .ansible-vault-password

# 2. Настройте inventory
cp inventory/production.yml.example inventory/production.yml
# Обновите production.yml с вашими данными (IP, SSH user, SSH key path)

# 3. Проверка конфигурации
ansible quotes-prod -m ping
ansible-playbook playbooks/deploy-frontend.yml --check

# 4. Развертывание
ansible-playbook playbooks/deploy-frontend.yml -v

# 5. Проверка
curl http://YOUR_SERVER_IP:3000

# 6. Откат (если нужен)
ansible-playbook playbooks/rollback.yml -e rollback_component=frontend -e rollback_timestamp=TIMESTAMP
```