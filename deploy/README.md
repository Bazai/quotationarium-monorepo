# Deploy Module

Централизованный модуль развертывания для проекта quotes application.

## Структура

```
deploy/
├── config/          # Конфигурационные файлы
│   ├── deploy.conf  # Главный конфигурационный загрузчик
│   ├── .env.production  # Продакшн настройки
│   ├── .env.local       # Локальные настройки для тестирования
│   └── .env.secrets.example  # Шаблон секретов
├── docs/            # Документация
│   ├── configuration.md     # Полное описание конфигурации
│   └── old-deploy-workflow.md  # Старый процесс деплоя
└── scripts/         # Скрипты развертывания
    ├── lib/         # Общие библиотеки
    │   ├── common.sh        # Общие утилиты
    │   ├── health-checks.sh # Проверки здоровья
    │   └── validation.sh    # Валидация конфигурации
    ├── deploy-frontend.sh   # Деплой фронтенда
    ├── deploy-backend.sh    # Деплой бэкенда
    ├── rollback-frontend.sh # Откат фронтенда
    └── rollback-backend.sh  # Откат бэкенда
```

## Использование

### Запуск из корня проекта:

```bash
# Деплой
./deploy/scripts/deploy-frontend.sh [environment] [options]
./deploy/scripts/deploy-backend.sh [environment] [options]

# Откат
./deploy/scripts/rollback-frontend.sh [environment] [version] [options]
./deploy/scripts/rollback-backend.sh [environment] [version] [options]
```

### Environments:
- `production` - продакшн (по умолчанию)  
- `local` - локальное тестирование
- `staging` - стейджинг

### Примеры:

```bash
# Деплой в продакшн
./deploy/scripts/deploy-frontend.sh production

# Локальное тестирование с dry-run
./deploy/scripts/deploy-frontend.sh local --dry-run

# Откат к предыдущей версии
./deploy/scripts/rollback-frontend.sh production

# Принудительный откат без подтверждения
./deploy/scripts/rollback-frontend.sh production --force
```

## Конфигурация

Все настройки централизованы в файлах `config/.env.*`. 

См. подробности в [docs/configuration.md](docs/configuration.md).

## Архитектура путей

- `PROJECT_ROOT` - корень всего проекта (../../../)
- `DEPLOY_ROOT` - корень модуля deploy (./)  
- `SCRIPT_DIR` - директория скриптов (./scripts)
- `CONFIG_DIR` - директория конфигов (./config)