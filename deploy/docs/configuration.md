# 🔧 Configuration Guide

## Overview

The deployment system uses centralized configuration files to eliminate hardcoded values and enable multi-environment deployments.

## 🧹 Recent Cleanup (2025-08-22)

The following variables were removed from configuration files as they are not used by any deployment scripts:

- ~~`MONOREPO_BASE_PATH`~~ - Not referenced in scripts
- ~~`BACKUP_BASE_DIR`~~ - Individual backup directories used instead
- ~~`ALLOWED_USERS`~~ - User permissions not implemented in scripts  
- ~~`LOG_RETENTION_DAYS`~~ - Log rotation not implemented
- ~~`NOTIFY_EMAIL`~~ - Email notifications not implemented (webhook only)
- ~~`DOMAIN_NAME`~~ - Domain config not automated in scripts
- ~~`SSL_CERT_PATH`~~ - SSL configuration not automated  
- ~~`SSL_KEY_PATH`~~ - SSL configuration not automated

These variables are now commented out in `.env.*` files but can be re-enabled if functionality is implemented.

## 📁 Configuration Structure

```
config/
├── .env.production         # Production environment settings
├── .env.local             # Local development/testing settings  
├── .env.staging           # Staging environment (optional)
├── .env.secrets.example   # Example secrets file
└── deploy.conf            # Configuration loader script
```

## 🌍 Environment Files

### Production (.env.production)

Primary configuration for production deployment:

```bash
# Environment
ENVIRONMENT=production
APP_NAME=quotes

# Paths - Production server paths
FRONTEND_SOURCE_PATH=/opt/quotes-monorepo-v2/frontend
BACKEND_SOURCE_PATH=/opt/quotes-monorepo-v2/backend
FRONTEND_PROD_PATH=/opt/collect_front
BACKEND_PROD_PATH=/opt/collector

# Services
FRONTEND_SERVICE_MANAGER=pm2
FRONTEND_SERVICE_NAME=app
BACKEND_SERVICE_MANAGER=systemd
BACKEND_SERVICE_NAME=collector.service
SERVICE_USER=www-data

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=quotes_db
DB_USER=quotes_user

# Network
FRONTEND_PORT=3000
BACKEND_PORT=8000
# DOMAIN_NAME=expo.timuroki.ink  # UNUSED: Not referenced in scripts
```

### Local (.env.local) 

Configuration for local testing:

```bash
# Environment
ENVIRONMENT=local
APP_NAME=quotes-local

# Paths - Local testing paths
FRONTEND_SOURCE_PATH=/Users/yourname/projects/quotes-monorepo-v2/frontend
FRONTEND_PROD_PATH=/tmp/quotes-test/collect_front
BACKEND_PROD_PATH=/tmp/quotes-test/collector

# Services - Local testing
SERVICE_USER=$(whoami)
BACKEND_SERVICE_MANAGER=manual  # Don't use systemd locally

# Network - Different ports to avoid conflicts
FRONTEND_PORT=3001
BACKEND_PORT=8001

# Options - Faster for local testing
SKIP_TESTS=true
VERBOSE=true
NODE_MAX_OLD_SPACE_SIZE=512
```

## 🔐 Secrets Management

### .env.secrets (Not in git!)

Create from `.env.secrets.example`:

```bash
# Copy example and fill in real values
cp config/.env.secrets.example config/.env.secrets
chmod 600 config/.env.secrets

# Edit with your credentials
DB_PASSWORD=your_secure_password
GITHUB_TOKEN=your_token
NOTIFY_WEBHOOK_URL=your_webhook_url
```

**Important:** Never commit `.env.secrets` to git!

## ⚙️ Configuration Variables

### 📍 Paths Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| ~~`MONOREPO_BASE_PATH`~~ | ~~Base path to monorepo~~ | **UNUSED** - Not referenced |
| `FRONTEND_SOURCE_PATH` | Frontend source directory | `${PROJECT_ROOT}/frontend` |
| `BACKEND_SOURCE_PATH` | Backend source directory | `${PROJECT_ROOT}/backend` |
| `FRONTEND_PROD_PATH` | Frontend production directory | `/opt/collect_front` |
| `BACKEND_PROD_PATH` | Backend production directory | `/opt/collector` |
| `STATIC_FILES_PATH` | Django static files | `/var/opt/collector/static` |

### 💾 Backup Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| ~~`BACKUP_BASE_DIR`~~ | ~~Base backup directory~~ | **UNUSED** - Individual dirs used |
| `FRONTEND_BACKUP_DIR` | Frontend backups directory | `/opt/backups/frontend` |
| `BACKEND_BACKUP_DIR` | Backend backups directory | `/opt/backups/backend` |
| `BACKUP_RETENTION_COUNT` | How many backups to keep | `5` |

### 🔧 Services Configuration

| Variable | Description | Options |
|----------|-------------|---------|
| `FRONTEND_SERVICE_MANAGER` | Frontend service type | `pm2`, `manual` |
| `FRONTEND_SERVICE_NAME` | Frontend service name | `app` |
| `BACKEND_SERVICE_MANAGER` | Backend service type | `systemd`, `manual` |
| `BACKEND_SERVICE_NAME` | Backend service name | `collector.service` |
| `SERVICE_USER` | User to run services | `www-data`, `$(whoami)` |

### 🗄️ Database Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_HOST` | Database host | `localhost` |
| `DB_PORT` | Database port | `5432` |
| `DB_NAME` | Database name | `quotes_db` |
| `DB_USER` | Database user | `quotes_user` |
| `DB_PASSWORD` | Database password | *In .env.secrets* |

### 🌐 Network Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `FRONTEND_PORT` | Frontend port | `3000` |
| `BACKEND_PORT` | Backend port | `8000` |
| `FRONTEND_URL` | Frontend URL | `http://localhost:3000` |
| `BACKEND_URL` | Backend URL | `http://localhost:8000` |
| `API_HEALTH_ENDPOINT` | Backend health check | `/api/` |
| `FRONTEND_HEALTH_ENDPOINT` | Frontend health check | `/` |

### 🔨 Build Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_MAX_OLD_SPACE_SIZE` | Node.js memory limit (MB) | `1024` |
| `BUILD_TIMEOUT` | Build timeout (seconds) | `300` |
| `NPM_INSTALL_TIMEOUT` | npm install timeout | `180` |

### 📊 Health Check Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `HEALTH_CHECK_RETRIES` | Number of health check attempts | `5` |
| `HEALTH_CHECK_DELAY` | Delay between attempts (seconds) | `2` |
| `HEALTH_CHECK_TIMEOUT` | HTTP timeout (seconds) | `10` |

### 🎛️ Deployment Options

| Variable | Description | Default |
|----------|-------------|---------|
| `SKIP_TESTS` | Skip running tests | `false` |
| `SKIP_BACKUP` | Skip creating backups | `false` |
| `FORCE_DEPLOY` | Force deploy ignoring warnings | `false` |
| `VERBOSE` | Verbose output | `false` |
| `DRY_RUN` | Show actions without executing | `false` |

### 🔄 Sync Configuration

| Variable | Description |
|----------|-------------|
| `RSYNC_DELETE` | Delete files not in source |
| `RSYNC_EXCLUDE_FRONTEND` | Frontend rsync exclude patterns |
| `RSYNC_EXCLUDE_BACKEND` | Backend rsync exclude patterns |

### 📢 Notification Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `NOTIFY_ON_DEPLOY` | Send deploy notifications | `false` |
| `NOTIFY_ON_ROLLBACK` | Send rollback notifications | `false` |
| `NOTIFY_WEBHOOK_URL` | Webhook URL for notifications | *In .env.secrets* |
| ~~`NOTIFY_EMAIL`~~ | ~~Email notifications~~ | **UNUSED** - Not implemented |

## 🚀 Usage Examples

### Environment Selection

```bash
# Deploy to production (default)
./scripts/deploy-frontend.sh
./scripts/deploy-frontend.sh production

# Deploy to local environment
./scripts/deploy-frontend.sh local

# Deploy to staging
./scripts/deploy-frontend.sh staging
```

### Overriding Options

```bash
# Deploy with verbose output
./scripts/deploy-frontend.sh production --verbose

# Deploy without tests
./scripts/deploy-frontend.sh local --skip-tests

# Dry run to see what would happen
./scripts/deploy-backend.sh production --dry-run

# Force deploy ignoring warnings
./scripts/deploy-backend.sh production --force
```

### Multiple Environments

```bash
# Test locally first
./scripts/deploy-frontend.sh local --verbose

# Then deploy to production
./scripts/deploy-frontend.sh production
```

## 🔍 Configuration Validation

The system automatically validates configuration before deployment:

```bash
# Check configuration without deploying
./scripts/deploy-frontend.sh production --dry-run

# Show current configuration
source config/deploy.conf production
show_config
```

### Validation Checks

- ✅ Required variables are set
- ✅ Source paths exist  
- ✅ Production directories can be created
- ✅ Network ports are valid
- ✅ Service configuration is correct
- ✅ Database settings are complete
- ✅ Boolean values are correct

## 🛠️ Creating New Environments

### 1. Create Environment File

```bash
# Create staging environment
cp config/.env.production config/.env.staging

# Edit for staging-specific settings
vim config/.env.staging
```

### 2. Update Environment-Specific Settings

```bash
# In .env.staging
ENVIRONMENT=staging
FRONTEND_PROD_PATH=/opt/collect_front_staging
BACKEND_PROD_PATH=/opt/collector_staging
FRONTEND_PORT=3001
BACKEND_PORT=8001
DB_NAME=quotes_db_staging
```

### 3. Use New Environment

```bash
# Deploy to staging
./scripts/deploy-frontend.sh staging
./scripts/deploy-backend.sh staging

# Rollback staging
./scripts/rollback-frontend.sh staging
```

## 🔧 Customization Examples

### Custom Build Settings

```bash
# In .env.local - Faster builds for development
NODE_MAX_OLD_SPACE_SIZE=512
BUILD_TIMEOUT=180
SKIP_TESTS=true
VERBOSE=true
```

### Custom Service Management

```bash
# In .env.local - Don't use systemd locally  
BACKEND_SERVICE_MANAGER=manual
FRONTEND_SERVICE_MANAGER=pm2
SERVICE_USER=$(whoami)
```

### Custom Paths

```bash
# In .env.staging - Different paths for staging
FRONTEND_PROD_PATH=/opt/staging/collect_front
BACKEND_PROD_PATH=/opt/staging/collector
BACKUP_BASE_DIR=/opt/staging/backups
```

## 🚨 Security Best Practices

### File Permissions

```bash
# Secure configuration files
chmod 644 config/.env.*
chmod 600 config/.env.secrets  # More restrictive for secrets
chown root:deploy config/
```

### Secrets Management

1. **Never commit secrets to git**
2. **Use strong, unique passwords**
3. **Rotate credentials regularly**
4. **Consider using proper secrets management (Vault, etc.) for production**

### Production Checklist

- [ ] `.env.secrets` exists and has correct permissions
- [ ] Database credentials are secure
- [ ] Webhook URLs use HTTPS
- [ ] Service user has minimal required permissions
- [ ] Backup directories are secure
- [ ] Log retention is configured

## 🔍 Troubleshooting

### Configuration Issues

```bash
# Check configuration
./scripts/deploy-frontend.sh production --dry-run

# Validate specific environment
source config/deploy.conf local
validate_configuration
```

### Missing Variables

```bash
# Error: Missing required configuration variables
# Solution: Check .env file for missing variables

# Show what's loaded
source config/deploy.conf production
env | grep -E "(FRONTEND|BACKEND|DB)_"
```

### Permission Issues

```bash
# Error: Cannot write to production directory
# Solution: Fix permissions

sudo chown -R $SERVICE_USER:$SERVICE_USER $FRONTEND_PROD_PATH
sudo chown -R $SERVICE_USER:$SERVICE_USER $BACKEND_PROD_PATH
```

### Path Issues

```bash
# Error: Source path does not exist
# Solution: Update paths in configuration

# Check current paths
ls -la $FRONTEND_SOURCE_PATH
ls -la $BACKEND_SOURCE_PATH
```

This configuration system provides flexibility for multiple environments while maintaining security and ease of use.