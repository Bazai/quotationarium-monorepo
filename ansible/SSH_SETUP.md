# SSH Configuration для деплоя

## 🔑 Понимание SSH конфигурации

**Важно различать два типа SSH ключей:**

### 1. **Ansible SSH ключ** (для подключения к серверу)
- Используется Ansible для подключения к серверу
- Обычно `~/.ssh/id_rsa` на вашей локальной машине
- Настраивается в `inventory/production.yml`

### 2. **Deploy Key** (на сервере для Git)
- Находится НА СЕРВЕРЕ: `~/.ssh/id_rsa_collector_monorepo`
- Используется для клонирования репозитория с GitHub
- Добавлен как Deploy Key в настройках GitHub репозитория

## ⚙️ Правильная настройка

### Шаг 1: Настройка SSH доступа к серверу
```bash
# Убедитесь что можете подключиться к серверу
ssh user@your-server-ip

# Если не получается, скопируйте ваш публичный ключ
ssh-copy-id user@your-server-ip
```

### Шаг 2: Проверка Deploy Key на сервере
```bash
# Подключитесь к серверу
ssh user@your-server-ip

# На сервере проверьте что deploy key работает
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa_collector_monorepo
ssh -T git@github.com

# Должно показать что-то вроде:
# "Hi username/repo! You've successfully authenticated, but GitHub does not provide shell access."
```

### Шаг 3: Настройка inventory
```yaml
# inventory/production.yml
all:
  hosts:
    quotes-prod:
      ansible_host: "YOUR_SERVER_IP"
      ansible_user: "YOUR_SSH_USER"
      ansible_ssh_private_key_file: "~/.ssh/id_rsa"  # ВАШ локальный SSH ключ
```

## 🚨 Частые ошибки

### ❌ Неправильно:
- Указывать `id_rsa_collector_monorepo` в inventory (это deploy key НА сервере)
- Настраивать SSH agent локально с deploy key
- Путать SSH ключ для подключения к серверу и deploy key для Git

### ✅ Правильно:
- В inventory указывать ВАШ SSH ключ для подключения к серверу
- Deploy key должен быть настроен НА СЕРВЕРЕ для git операций
- SSH agent с deploy key запускать НА СЕРВЕРЕ (если нужно)

## 🔍 Диагностика проблем

### Проблема: Ansible не может подключиться
```bash
# Тест прямого SSH подключения
ssh user@your-server-ip

# Тест через Ansible
ansible quotes-prod -m ping
```

### Проблема: Git clone не работает во время деплоя
```bash
# На сервере проверьте git доступ
ssh user@your-server-ip
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa_collector_monorepo
git clone YOUR_REPO_URL /tmp/test-clone
rm -rf /tmp/test-clone
```

## ✅ Финальная проверка

Все эти команды должны работать:
```bash
# 1. SSH подключение к серверу
ssh user@your-server-ip

# 2. Ansible ping
ansible quotes-prod -m ping

# 3. Git доступ на сервере (выполнить НА СЕРВЕРЕ)
ssh user@your-server-ip "eval \"\$(ssh-agent -s)\" && ssh-add ~/.ssh/id_rsa_collector_monorepo && ssh -T git@github.com"
```