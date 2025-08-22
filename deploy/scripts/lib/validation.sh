#!/bin/bash
# =============================================================================
# CONFIGURATION VALIDATION UTILITIES
# =============================================================================
# Validation functions for deployment configuration
# Usage: source scripts/lib/validation.sh
# =============================================================================

# Validate required configuration variables
validate_required_config() {
    log_debug "Validating required configuration variables..."
    
    local required_vars=(
        "ENVIRONMENT"
        "APP_NAME"
        "FRONTEND_SOURCE_PATH"
        "BACKEND_SOURCE_PATH"
        "FRONTEND_PROD_PATH"
        "BACKEND_PROD_PATH"
        "SERVICE_USER"
        "FRONTEND_SERVICE_MANAGER"
        "FRONTEND_SERVICE_NAME"
        "BACKEND_SERVICE_MANAGER"
        "BACKEND_SERVICE_NAME"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required configuration variables:"
        printf '  - %s\n' "${missing_vars[@]}"
        return 1
    fi
    
    log_success "All required configuration variables are set"
    return 0
}

# Validate paths exist
validate_paths() {
    log_debug "Validating filesystem paths..."
    
    local paths_to_check=(
        "$FRONTEND_SOURCE_PATH:Frontend source directory"
        "$BACKEND_SOURCE_PATH:Backend source directory"
    )
    
    local missing_paths=()
    
    for path_info in "${paths_to_check[@]}"; do
        local path="${path_info%%:*}"
        local description="${path_info#*:}"
        
        if [ ! -d "$path" ]; then
            missing_paths+=("$description: $path")
        else
            log_debug "Path exists: $description ($path)"
        fi
    done
    
    if [ ${#missing_paths[@]} -gt 0 ]; then
        log_error "Missing required paths:"
        printf '  - %s\n' "${missing_paths[@]}"
        return 1
    fi
    
    log_success "All required paths exist"
    return 0
}

# Validate production directories (create if needed)
validate_production_paths() {
    log_debug "Validating production paths..."
    
    local prod_paths=(
        "$FRONTEND_PROD_PATH:Frontend production directory"
        "$BACKEND_PROD_PATH:Backend production directory"
        "$FRONTEND_BACKUP_DIR:Frontend backup directory"
        "$BACKEND_BACKUP_DIR:Backend backup directory"
        "$STATIC_FILES_PATH:Static files directory"
    )
    
    for path_info in "${prod_paths[@]}"; do
        local path="${path_info%%:*}"
        local description="${path_info#*:}"
        
        if [ ! -d "$path" ]; then
            if [ "$DRY_RUN" = "true" ]; then
                log_info "DRY RUN: Would create $description: $path"
            else
                log_warning "$description does not exist, creating: $path"
                # Use sudo if needed
                if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
                    sudo mkdir -p "$path"
                    sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$path"
                else
                    mkdir -p "$path"
                fi
                log_success "Created $description: $path"
            fi
        else
            log_debug "Production path exists: $description ($path)"
        fi
    done
    
    return 0
}

# Validate network configuration
validate_network() {
    log_debug "Validating network configuration..."
    
    # Validate port numbers
    local ports=(
        "$FRONTEND_PORT:Frontend port"
        "$BACKEND_PORT:Backend port"
        "$DB_PORT:Database port"
    )
    
    for port_info in "${ports[@]}"; do
        local port="${port_info%%:*}"
        local description="${port_info#*:}"
        
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            log_error "Invalid $description: $port (must be 1-65535)"
            return 1
        else
            log_debug "Valid $description: $port"
        fi
    done
    
    # Validate URLs format
    local urls=(
        "$FRONTEND_URL|Frontend URL"
        "$BACKEND_URL|Backend URL"
    )
    log_debug "$urls"
    
    for url_info in "${urls[@]}"; do
        local url="${url_info%%|*}"
        local description="${url_info#*:}"

        if [[ ! "$url" =~ ^https?://[^[:space:]]+$ ]]; then
            log_error "Invalid $description format: $url"
            return 1
        else
            log_debug "Valid $description: $url"
        fi
    done
    
    log_success "Network configuration is valid"
    return 0
}

# Validate service configuration
validate_services() {
    log_debug "Validating service configuration..."
    
    # Validate service managers
    local valid_managers=("systemd" "pm2" "manual")
    
    local managers_to_check=(
        "$FRONTEND_SERVICE_MANAGER:Frontend service manager"
        "$BACKEND_SERVICE_MANAGER:Backend service manager"
    )
    
    for manager_info in "${managers_to_check[@]}"; do
        local manager="${manager_info%%:*}"
        local description="${manager_info#*:}"
        
        local valid=false
        for valid_manager in "${valid_managers[@]}"; do
            if [ "$manager" = "$valid_manager" ]; then
                valid=true
                break
            fi
        done
        
        if [ "$valid" = false ]; then
            log_error "Invalid $description: $manager (must be one of: ${valid_managers[*]})"
            return 1
        else
            log_debug "Valid $description: $manager"
        fi
    done
    
    # Check if service user exists (if not current user)
    if [ "$SERVICE_USER" != "$(whoami)" ]; then
        if ! id "$SERVICE_USER" >/dev/null 2>&1; then
            log_error "Service user does not exist: $SERVICE_USER"
            return 1
        else
            log_debug "Service user exists: $SERVICE_USER"
        fi
    fi
    
    log_success "Service configuration is valid"
    return 0
}

# Validate database configuration
validate_database() {
    log_debug "Validating database configuration..."
    
    # Check required database variables
    local db_vars=(
        "DB_HOST"
        "DB_PORT"
        "DB_NAME"
        "DB_USER"
    )
    
    local missing_db_vars=()
    
    for var in "${db_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_db_vars+=("$var")
        fi
    done
    
    if [ ${#missing_db_vars[@]} -gt 0 ]; then
        log_error "Missing database configuration variables:"
        printf '  - %s\n' "${missing_db_vars[@]}"
        return 1
    fi
    
    log_success "Database configuration is valid"
    return 0
}

# Validate backup configuration
validate_backup() {
    log_debug "Validating backup configuration..."
    
    # Validate backup retention count
    if ! [[ "$BACKUP_RETENTION_COUNT" =~ ^[0-9]+$ ]] || [ "$BACKUP_RETENTION_COUNT" -lt 1 ]; then
        log_error "Invalid backup retention count: $BACKUP_RETENTION_COUNT (must be positive integer)"
        return 1
    fi
    
    # Validate backup directories are writable (or can be created)
    local backup_dirs=(
        "$FRONTEND_BACKUP_DIR"
        "$BACKEND_BACKUP_DIR"
    )
    
    for backup_dir in "${backup_dirs[@]}"; do
        local parent_dir=$(dirname "$backup_dir")
        
        if [ ! -d "$parent_dir" ]; then
            log_error "Parent directory for backup does not exist: $parent_dir"
            return 1
        fi
        
        if [ ! -w "$parent_dir" ] && [ "$SERVICE_USER" = "$(whoami)" ]; then
            log_error "Cannot write to backup parent directory: $parent_dir"
            return 1
        fi
        
        log_debug "Backup directory is valid: $backup_dir"
    done
    
    log_success "Backup configuration is valid"
    return 0
}

# Validate build configuration
validate_build() {
    log_debug "Validating build configuration..."
    
    # Validate Node.js memory setting
    if ! [[ "$NODE_MAX_OLD_SPACE_SIZE" =~ ^[0-9]+$ ]] || [ "$NODE_MAX_OLD_SPACE_SIZE" -lt 256 ]; then
        log_error "Invalid Node.js memory setting: $NODE_MAX_OLD_SPACE_SIZE (must be >= 256 MB)"
        return 1
    fi
    
    # Validate timeout settings
    local timeouts=(
        "$BUILD_TIMEOUT:Build timeout"
        "$NPM_INSTALL_TIMEOUT:NPM install timeout"
        "$HEALTH_CHECK_TIMEOUT:Health check timeout"
    )
    
    for timeout_info in "${timeouts[@]}"; do
        local timeout="${timeout_info%%:*}"
        local description="${timeout_info#*:}"
        
        if ! [[ "$timeout" =~ ^[0-9]+$ ]] || [ "$timeout" -lt 10 ]; then
            log_error "Invalid $description: $timeout (must be >= 10 seconds)"
            return 1
        else
            log_debug "Valid $description: $timeout seconds"
        fi
    done
    
    log_success "Build configuration is valid"
    return 0
}

# Validate boolean configuration
validate_boolean_config() {
    log_debug "Validating boolean configuration..."
    
    local boolean_vars=(
        "SKIP_TESTS"
        "SKIP_BACKUP"
        "FORCE_DEPLOY"
        "VERBOSE"
        "DRY_RUN"
        "RSYNC_DELETE"
        "NOTIFY_ON_DEPLOY"
        "NOTIFY_ON_ROLLBACK"
    )
    
    for var in "${boolean_vars[@]}"; do
        local value="${!var}"
        if [ -n "$value" ] && [ "$value" != "true" ] && [ "$value" != "false" ]; then
            log_error "Invalid boolean value for $var: $value (must be 'true' or 'false')"
            return 1
        fi
    done
    
    log_success "Boolean configuration is valid"
    return 0
}

# Comprehensive configuration validation
validate_configuration() {
    log_step "🔍 Validating configuration..."
    
    local validation_functions=(
        "validate_required_config"
        "validate_paths"
        "validate_production_paths"
        "validate_network"
        "validate_services"
        "validate_database"
        "validate_backup"
        "validate_build"
        "validate_boolean_config"
    )
    
    local failed_validations=()
    
    for validation_func in "${validation_functions[@]}"; do
        if ! $validation_func; then
            failed_validations+=("$validation_func")
        fi
    done
    
    if [ ${#failed_validations[@]} -gt 0 ]; then
        log_error "Configuration validation failed:"
        printf '  - %s\n' "${failed_validations[@]}"
        return 1
    fi
    
    log_success "All configuration validations passed"
    return 0
}

# Pre-deployment checks
pre_deployment_checks() {
    local component=${1:-"both"}
    
    log_step "🔍 Pre-deployment checks ($component)..."
    
    # Basic configuration validation
    if ! validate_configuration; then
        return 1
    fi
    
    # Component-specific checks
    case $component in
        "frontend")
            if ! validate_frontend_specific; then
                return 1
            fi
            ;;
        "backend")
            if ! validate_backend_specific; then
                return 1
            fi
            ;;
        "both")
            if ! validate_frontend_specific || ! validate_backend_specific; then
                return 1
            fi
            ;;
    esac
    
    log_success "Pre-deployment checks passed"
    return 0
}

# Frontend-specific validation
validate_frontend_specific() {
    log_debug "Frontend-specific validation..."
    
    # Check if package.json exists
    if [ ! -f "$FRONTEND_SOURCE_PATH/package.json" ]; then
        log_error "package.json not found in frontend source: $FRONTEND_SOURCE_PATH"
        return 1
    fi
    
    # Check if Node.js is available
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js is not installed or not in PATH"
        return 1
    fi
    
    # Check if npm is available
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm is not installed or not in PATH"
        return 1
    fi
    
    log_debug "Frontend-specific validation passed"
    return 0
}

# Backend-specific validation
validate_backend_specific() {
    log_debug "Backend-specific validation..."
    
    # Check if requirements.txt exists
    if [ ! -f "$BACKEND_SOURCE_PATH/requirements.txt" ]; then
        log_error "requirements.txt not found in backend source: $BACKEND_SOURCE_PATH"
        return 1
    fi
    
    # Check if manage.py exists
    if [ ! -f "$BACKEND_SOURCE_PATH/manage.py" ]; then
        log_error "manage.py not found in backend source: $BACKEND_SOURCE_PATH"
        return 1
    fi
    
    # Check if Python 3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Python 3 is not installed or not in PATH"
        return 1
    fi
    
    log_debug "Backend-specific validation passed"
    return 0
}
