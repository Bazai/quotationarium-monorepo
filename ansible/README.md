# Ansible Deployment для Quotes Monorepo

## TODOs

Я проверил ТОЛЬКО деплой backend and frontend.

- [ ] Реализовать и проверить rollback. Не работает rollback, т.к. tag.gz архивы в /opt/collector_backups/{backend,frontend,database} содержат название source папки (eg. /collect_front/{contents}).
  - На DO Droplet мало места. А разархивирование только frontend архива занимает 660Мб
- [ ] Проверить, что попадает в бэкап архивы backend
- [ ] Реализовать rollback backend
- [ ] Проверить backend rollback с восстановлением db
- [ ] Сделать и перепроверить npm install & npm build только с `npm list --production`
- [ ] Реализовать темплейты для: confg/settings_local.py, /etc/systemd/\*, /etc/nginx/sites-enabled/collector (Ищи в Obsidian)

## 🚀 Быстрый старт (Frontend deployment)

### 1. Подготовка

```bash
cd ansible

# Проверьте SSH подключение к серверу
ssh user@your-server-ip  # должно работать без пароля

# Настройте inventory и переменные
cp inventory/production.yml.example inventory/production.yml
# Обновите inventory/production.yml и group_vars/all/main.yml

# Создайте пароль для vault
echo "your_secure_password" > .ansible-vault-password
chmod 600 .ansible-vault-password
```

### 2. Проверка готовности

```bash
./scripts/pre-deploy-check.sh frontend
```

### 3. Первый деплой

```bash
./scripts/deploy-frontend.sh
```

### 4. Откат (если нужен)

```bash
./scripts/rollback.sh frontend TIMESTAMP
```

## 📖 Документация

- **DEPLOYMENT_GUIDE.md** - Подробное руководство по развертыванию
- **SSH_SETUP.md** - Настройка SSH ключей (читайте ОБЯЗАТЕЛЬНО!)
- **group_vars/all/main.yml** - Основные настройки (обновите git_repo и server IPs)
- **inventory/production.yml** - Конфигурация серверов

## 🔧 Основные команды

```bash
# Проверка подключения
ansible quotes-prod -m ping

# Деплой frontend
ansible-playbook playbooks/deploy-frontend.yml -v

# Откат
ansible-playbook playbooks/rollback.yml -e rollback_component=frontend -e rollback_timestamp=TIMESTAMP
```
