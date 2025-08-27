#!/bin/bash
# =============================================================================
# BACKEND DEPLOYMENT SCRIPT - CONFIGURABLE VERSION
# =============================================================================
# Deploy backend application using centralized configuration
# Usage: ./scripts/deploy-backend.sh [environment]
# Environments: production (default), local, staging
# =============================================================================

set -e

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DEPLOY_ROOT")"

# Load configuration and libraries
source "$DEPLOY_ROOT/config/deploy.conf" "${1:-production}"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/health-checks.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Initialize common utilities
init_common

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --skip-migrations)
            SKIP_MIGRATIONS=true
            shift
            ;;
        --skip-static)
            SKIP_STATIC=true
            shift
            ;;
        --force)
            FORCE_DEPLOY=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        production|local|staging)
            # Environment already loaded, skip
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Help function
show_help() {
    cat << EOF
Backend Deployment Script

Usage: $0 [environment] [options]

Environments:
  production    Production deployment (default)
  local         Local testing deployment
  staging       Staging deployment

Options:
  --skip-tests        Skip running tests
  --skip-backup       Skip creating database and static backups
  --skip-migrations   Skip running database migrations
  --skip-static       Skip collecting static files
  --force             Force deployment even if validation fails
  --verbose, -v       Verbose output
  --dry-run           Show what would be done without executing
  --help, -h          Show this help

Examples:
  $0                           # Deploy to production
  $0 local --verbose           # Deploy to local with verbose output
  $0 production --dry-run      # Show production deployment plan
  $0 local --skip-tests        # Deploy to local without tests

Configuration:
  Environment: $ENVIRONMENT
  Source:      $BACKEND_SOURCE_PATH
  Target:      $BACKEND_PROD_PATH
  Service:     $BACKEND_SERVICE_NAME ($BACKEND_SERVICE_MANAGER)
  Database:    $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME

EOF
}

# Pre-deployment validation
run_pre_deployment_checks() {
    log_step "🔍 Pre-deployment validation..."
    
    # Validate configuration for backend
    if ! pre_deployment_checks "backend"; then
        if [ "$FORCE_DEPLOY" = "true" ]; then
            log_warning "Validation failed but continuing due to --force flag"
        else
            log_error "Pre-deployment validation failed"
            log_info "Use --force to override validation errors"
            exit 1
        fi
    fi
    
    log_success "Pre-deployment validation completed"
}

# Run tests
run_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log_info "Skipping tests due to --skip-tests flag"
        return 0
    fi
    
    log_step "🧪 Running backend tests..."
    
    cd "$BACKEND_SOURCE_PATH"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would run backend tests"
        return 0
    fi
    
    # Use Python from production virtual environment
    local python_cmd="python"
    if [ -f "$BACKEND_PROD_PATH/.venv/bin/python" ]; then
        python_cmd="$BACKEND_PROD_PATH/.venv/bin/python"
        log_info "Using Python from production virtual environment"
    else
        log_warning "Production virtual environment not found, using system Python"
    fi
    
    # Run Django tests
    log_info "Running Django tests..."
    if ! $python_cmd manage.py test --settings=config.settings_local; then
        log_error "Backend tests failed"
        return 1
    fi
    
    # Check for pending migrations
    log_info "Checking for pending migrations..."
    if ! $python_cmd manage.py makemigrations --dry-run --check --settings=config.settings_local; then
        log_error "Missing database migrations"
        return 1
    fi
    
    log_success "Backend tests completed successfully"
}

# Create database backup
create_database_backup() {
    log_info "Creating database backup..."
    
    local backup_file="$BACKEND_BACKUP_DIR/db_backup_$TIMESTAMP.custom"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would create database backup to $backup_file"
        return 0
    fi
    
    # Create backup directory
    mkdir -p "$BACKEND_BACKUP_DIR"
    
    # Create database backup
    if command -v pg_dump >/dev/null 2>&1; then
        if PGPASSWORD="$DB_PASSWORD" pg_dump -Fc -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" -f "$backup_file" 2>/dev/null; then
            log_success "Database backup created: $(basename "$backup_file")"
        else
            log_warning "Database backup failed, creating placeholder"
            touch "$backup_file"
            touch "${backup_file}.placeholder"
        fi
    else
        log_warning "pg_dump not available, creating placeholder backup"
        touch "$backup_file"
        touch "${backup_file}.placeholder"
    fi
}

# Create application backup
create_deployment_backup() {
    if [ "$SKIP_BACKUP" = "true" ]; then
        log_info "Skipping backup due to --skip-backup flag"
        return 0
    fi
    
    log_step "📦 Creating deployment backup..."
    
    # Create database backup
    create_database_backup
    
    # Backup static files
    if [ -d "$STATIC_FILES_PATH" ]; then
        create_backup "$STATIC_FILES_PATH" "$BACKEND_BACKUP_DIR" "static_$TIMESTAMP" "static files"
    fi
    
    # Backup requirements.txt
    if [ -f "$BACKEND_PROD_PATH/requirements.txt" ]; then
        create_backup "$BACKEND_PROD_PATH/requirements.txt" "$BACKEND_BACKUP_DIR" "requirements_$TIMESTAMP.txt" "requirements file"
    fi
    
    log_success "Deployment backup completed"
}

# Setup Python environment
setup_python_environment() {
    log_step "🐍 Setting up Python environment..."
    
    cd "$BACKEND_PROD_PATH"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would setup Python virtual environment"
        return 0
    fi
    
    # Create virtual environment if it doesn't exist
    if [ ! -d ".venv" ]; then
        log_info "Creating Python virtual environment..."
        
        local sudo_cmd=""
        if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
            sudo_cmd="sudo -u $SERVICE_USER"
        fi
        
        $sudo_cmd python3 -m venv .venv
        log_success "Virtual environment created"
    else
        log_debug "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    source .venv/bin/activate
    log_debug "Virtual environment activated"
}

# Install Python dependencies
install_dependencies() {
    log_step "📦 Managing Python dependencies..."
    
    cd "$BACKEND_PROD_PATH"
    source .venv/bin/activate
    
    # Check if requirements.txt changed
    local install_needed=true
    if [ -f "$BACKEND_BACKUP_DIR/requirements_$TIMESTAMP.txt" ]; then
        if [ -f "requirements.txt" ] && diff -q "requirements.txt" "$BACKEND_BACKUP_DIR/requirements_$TIMESTAMP.txt" > /dev/null 2>&1; then
            install_needed=false
            log_info "No requirements changes detected, skipping dependency installation"
        fi
    fi
    
    if [ "$install_needed" = "true" ]; then
        log_info "Installing Python dependencies..."
        
        if [ "$DRY_RUN" = "true" ]; then
            log_info "DRY RUN: Would install Python dependencies"
        else
            pip install --upgrade pip
            pip install -r requirements.txt
        fi
        
        log_success "Dependencies installed successfully"
    fi
}

# Run database migrations
run_migrations() {
    if [ "$SKIP_MIGRATIONS" = "true" ]; then
        log_info "Skipping migrations due to --skip-migrations flag"
        return 0
    fi
    
    log_step "🗄️  Running database migrations..."
    
    cd "$BACKEND_PROD_PATH"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would run database migrations"
        return 0
    fi
    
    # Use Python from virtual environment
    local python_cmd=".venv/bin/python"
    if [ ! -f "$python_cmd" ]; then
        log_error "Virtual environment not found at $BACKEND_PROD_PATH/.venv"
        return 1
    fi
    
    if $python_cmd manage.py migrate --noinput --settings=config.settings_local; then
        log_success "Database migrations completed"
    else
        log_error "Database migrations failed"
        return 1
    fi
}

# Collect static files
collect_static_files() {
    if [ "$SKIP_STATIC" = "true" ]; then
        log_info "Skipping static file collection due to --skip-static flag"
        return 0
    fi
    
    log_step "📁 Collecting static files..."
    
    cd "$BACKEND_PROD_PATH"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would collect static files"
        return 0
    fi
    
    # Use Python from virtual environment
    local python_cmd=".venv/bin/python"
    if [ ! -f "$python_cmd" ]; then
        log_error "Virtual environment not found at $BACKEND_PROD_PATH/.venv"
        return 1
    fi
    
    if $python_cmd manage.py collectstatic --noinput --settings=config.settings_local; then
        # Fix permissions for static files
        local sudo_cmd=""
        if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
            sudo_cmd="sudo"
        fi
        
        $sudo_cmd chown -R "$SERVICE_USER:$SERVICE_USER" "$STATIC_FILES_PATH" 2>/dev/null || true
        
        log_success "Static files collected and permissions set"
    else
        log_warning "Static file collection had issues, but continuing..."
    fi
}

# Deploy application
deploy_application() {
    log_step "🚀 Deploying application..."
    
    # Stop service
    log_info "Stopping backend service..."
    stop_service "$BACKEND_SERVICE_MANAGER" "$BACKEND_SERVICE_NAME"
    
    # Sync files from source to production
    log_info "Syncing application files..."
    sync_files "$BACKEND_SOURCE_PATH" "$BACKEND_PROD_PATH" "$RSYNC_EXCLUDE_BACKEND"
    
    # Setup Python environment
    setup_python_environment
    
    # Install dependencies
    install_dependencies
    
    # Run migrations
    run_migrations
    
    # Collect static files
    collect_static_files
    
    # Start service
    log_info "Starting backend service..."
    start_service "$BACKEND_SERVICE_MANAGER" "$BACKEND_SERVICE_NAME"
    
    # Wait for service to start
    wait_for_service 5 "Waiting for backend service to start"
    
    log_success "Application deployed successfully"
}

# Post-deployment verification
run_post_deployment_checks() {
    log_step "✅ Post-deployment verification..."
    
    if ! post_deployment_verification "backend" "detailed"; then
        log_error "Post-deployment verification failed"
        log_warning "Consider rolling back: ./scripts/rollback-backend.sh"
        return 1
    fi
    
    log_success "Post-deployment verification completed"
}

# Cleanup
cleanup_deployment() {
    log_step "🧹 Cleanup..."
    
    # Clean old backups
    cleanup_old_backups "$BACKEND_BACKUP_DIR" "$BACKUP_RETENTION_COUNT" "db_backup_*.custom"
    cleanup_old_backups "$BACKEND_BACKUP_DIR" "$BACKUP_RETENTION_COUNT" "static_*"
    cleanup_old_backups "$BACKEND_BACKUP_DIR" "$BACKUP_RETENTION_COUNT" "requirements_*.txt"
    
    # Send notification if enabled
    if [ "$NOTIFY_ON_DEPLOY" = "true" ]; then
        send_notification "✅ Backend deployment completed successfully ($ENVIRONMENT)"
    fi
    
    log_success "Cleanup completed"
}

# Main deployment function
main() {
    local start_time=$(date +%s)
    
    # Display deployment information
    log_step "🏭 Backend Deployment ($ENVIRONMENT)"
    echo "================================="
    echo "Source:      $BACKEND_SOURCE_PATH"
    echo "Target:      $BACKEND_PROD_PATH"
    echo "Service:     $BACKEND_SERVICE_NAME ($BACKEND_SERVICE_MANAGER)"
    echo "Database:    $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
    echo "Version:     $TIMESTAMP"
    echo "Dry run:     $DRY_RUN"
    echo
    
    # Run deployment steps
    run_pre_deployment_checks
    
    if [ "$SKIP_TESTS" = "false" ]; then
        run_tests
    fi
    
    create_deployment_backup
    deploy_application
    run_post_deployment_checks
    cleanup_deployment
    
    # Calculate deployment time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    # Success summary
    echo
    log_success "🎉 Backend deployment completed successfully!"
    echo "========================================="
    echo "Environment: $ENVIRONMENT"
    echo "Version:     $TIMESTAMP"
    echo "Duration:    ${minutes}m ${seconds}s"
    echo "Completed:   $(date)"
    echo
    
    # Show health summary
    show_health_summary
    
    echo
    log_info "💡 Useful commands:"
    echo "  Status:     ./scripts/deploy-backend.sh $DEPLOY_ENV --dry-run"
    echo "  Logs:       sudo journalctl -u $BACKEND_SERVICE_NAME -f"
    echo "  Shell:      cd $BACKEND_PROD_PATH && source .venv/bin/activate && python manage.py shell --settings=config.settings_local"
    echo "  Rollback:   ./scripts/rollback-backend.sh $DEPLOY_ENV"
    echo "  Health:     curl -I $BACKEND_URL$API_HEALTH_ENDPOINT"
}

# Error handler
handle_deployment_error() {
    local line_no=$1
    local error_code=$2
    
    log_error "Backend deployment failed at line $line_no (exit code: $error_code)"
    
    if [ "$NOTIFY_ON_DEPLOY" = "true" ]; then
        send_notification "❌ Backend deployment failed ($ENVIRONMENT) at line $line_no"
    fi
    
    echo
    log_info "💡 Troubleshooting:"
    echo "  1. Check service: sudo systemctl status $BACKEND_SERVICE_NAME"
    echo "  2. Check logs: sudo journalctl -u $BACKEND_SERVICE_NAME -n 20"
    echo "  3. Database check: cd $BACKEND_PROD_PATH && source .venv/bin/activate && python manage.py dbshell --settings=config.settings_local"
    echo "  4. Manual rollback: ./scripts/rollback-backend.sh $DEPLOY_ENV"
    echo "  5. Health check: curl -I $BACKEND_URL$API_HEALTH_ENDPOINT"
    
    exit 1
}

# Set error handler
trap 'handle_deployment_error $LINENO $?' ERR

# Run main function
main "$@"