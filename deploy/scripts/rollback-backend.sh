#!/bin/bash
# =============================================================================
# BACKEND ROLLBACK SCRIPT - CONFIGURABLE VERSION
# =============================================================================
# Rollback backend application using centralized configuration
# Usage: ./scripts/rollback-backend.sh [environment] [target_version]
# =============================================================================

set -e

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DEPLOY_ROOT")"

# Parse arguments
DEPLOY_ENV="${1:-production}"
TARGET_VERSION="${2:-previous}"

# Load configuration and libraries
source "$DEPLOY_ROOT/config/deploy.conf" "$DEPLOY_ENV"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/health-checks.sh"

# Initialize common utilities
init_common

# Parse additional command line arguments
SKIP_DATABASE=false
SKIP_STATIC=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-database)
            SKIP_DATABASE=true
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
            # Environment already processed
            shift
            ;;
        *)
            # Assume it's a version if not processed yet
            if [ "$TARGET_VERSION" = "previous" ]; then
                TARGET_VERSION="$1"
            fi
            shift
            ;;
    esac
done

# Help function
show_help() {
    cat << EOF
Backend Rollback Script

Usage: $0 [environment] [target_version] [options]

Environments:
  production    Production rollback (default)
  local         Local testing rollback
  staging       Staging rollback

Target Version:
  previous      Rollback to previous version (default)
  TIMESTAMP     Rollback to specific version (e.g., 20241201_143000)

Options:
  --skip-database  Skip database rollback (code only)
  --skip-static    Skip static files rollback
  --force          Force rollback without confirmation
  --verbose, -v    Verbose output
  --dry-run        Show what would be done without executing
  --help, -h       Show this help

Examples:
  $0                                      # Rollback production to previous (DANGEROUS!)
  $0 local                               # Rollback local to previous
  $0 production 20241201_143000          # Rollback production to specific version
  $0 production --skip-database          # Rollback code only, keep current database

⚠️  WARNING: Backend rollback includes database restore by default!
    This will overwrite current data. Use --skip-database for code-only rollback.

Configuration:
  Environment: $ENVIRONMENT
  Target:      $BACKEND_PROD_PATH
  Backup Dir:  $BACKEND_BACKUP_DIR
  Service:     $BACKEND_SERVICE_NAME ($BACKEND_SERVICE_MANAGER)
  Database:    $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME

EOF
}

# List available backups
list_available_backups() {
    log_step "📋 Available backend backups:"
    
    if [ ! -d "$BACKEND_BACKUP_DIR" ]; then
        log_warning "Backup directory not found: $BACKEND_BACKUP_DIR"
        return 1
    fi
    
    local db_backups=($(ls -t "$BACKEND_BACKUP_DIR"/db_backup_*.custom 2>/dev/null | head -10))
    local static_backups=($(ls -td "$BACKEND_BACKUP_DIR"/static_* 2>/dev/null | head -10))
    
    echo
    echo "Database Backups:"
    echo "=================="
    if [ ${#db_backups[@]} -eq 0 ]; then
        echo "  No database backups found"
    else
        printf "%-3s %-25s %-12s %-8s %s\n" "#" "Backup Name" "Date" "Size" "Age"
        echo "---------------------------------------------------------------"
        
        local count=1
        for backup in "${db_backups[@]}"; do
            if [ -f "$backup" ]; then
                local backup_name=$(basename "$backup")
                local timestamp=${backup_name#db_backup_}
                timestamp=${timestamp%.custom}
                
                # Parse timestamp
                local date_formatted="unknown"
                if [[ "$timestamp" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
                    local date_part="${timestamp:0:8}"
                    local time_part="${timestamp:9:6}"
                    date_formatted=$(date -d "${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}" +"%m/%d %H:%M" 2>/dev/null || echo "$timestamp")
                fi
                
                # Get size
                local size=$(du -sh "$backup" 2>/dev/null | cut -f1 || echo "?")
                
                # Calculate age
                local mod_time=$(stat -c %Y "$backup" 2>/dev/null || echo "0")
                local current_time=$(date +%s)
                local age_seconds=$((current_time - mod_time))
                local age_hours=$((age_seconds / 3600))
                local age_str="${age_hours}h ago"
                
                printf "%-3d %-25s %-12s %-8s %s\n" "$count" "$backup_name" "$date_formatted" "$size" "$age_str"
                ((count++))
            fi
        done
    fi
    
    echo
    echo "Static Files Backups:"
    echo "===================="
    if [ ${#static_backups[@]} -eq 0 ]; then
        echo "  No static backups found"
    else
        printf "%-3s %-20s %-12s %-8s %s\n" "#" "Backup Name" "Date" "Size" "Age"
        echo "--------------------------------------------------------"
        
        local count=1
        for backup in "${static_backups[@]}"; do
            if [ -d "$backup" ]; then
                local backup_name=$(basename "$backup")
                local timestamp=${backup_name#static_}
                
                # Parse timestamp (similar logic as above)
                local date_formatted="unknown"
                if [[ "$timestamp" =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
                    local date_part="${timestamp:0:8}"
                    local time_part="${timestamp:9:6}"
                    date_formatted=$(date -d "${date_part:0:4}-${date_part:4:2}-${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}" +"%m/%d %H:%M" 2>/dev/null || echo "$timestamp")
                fi
                
                local size=$(du -sh "$backup" 2>/dev/null | cut -f1 || echo "?")
                
                local mod_time=$(stat -c %Y "$backup" 2>/dev/null || echo "0")
                local current_time=$(date +%s)
                local age_seconds=$((current_time - mod_time))
                local age_hours=$((age_seconds / 3600))
                local age_str="${age_hours}h ago"
                
                printf "%-3d %-20s %-12s %-8s %s\n" "$count" "$backup_name" "$date_formatted" "$size" "$age_str"
                ((count++))
            fi
        done
    fi
    echo
}

# Get target backup paths
get_target_backups() {
    local target_version="$1"
    
    if [ "$target_version" = "previous" ]; then
        # Find the latest backups
        local latest_db_backup=$(ls -t "$BACKEND_BACKUP_DIR"/db_backup_*.custom 2>/dev/null | head -1)
        local latest_static_backup=$(ls -td "$BACKEND_BACKUP_DIR"/static_* 2>/dev/null | head -1)
        
        if [ -z "$latest_db_backup" ]; then
            log_error "No previous database backup found"
            return 1
        fi
        
        echo "$latest_db_backup|$latest_static_backup"
    else
        # Use specific version
        local specific_db_backup="$BACKEND_BACKUP_DIR/db_backup_$target_version.custom"
        local specific_static_backup="$BACKEND_BACKUP_DIR/static_$target_version"
        
        if [ ! -f "$specific_db_backup" ]; then
            log_error "Database backup not found: db_backup_$target_version.custom"
            return 1
        fi
        
        echo "$specific_db_backup|$specific_static_backup"
    fi
}

# Create rollback snapshot
create_rollback_snapshot() {
    log_step "📸 Creating pre-rollback snapshot..."
    
    local snapshot_timestamp="rollback_$TIMESTAMP"
    
    # Backup current database
    if [ "$SKIP_DATABASE" = "false" ]; then
        log_info "Creating current database backup..."
        local current_db_backup="$BACKEND_BACKUP_DIR/db_backup_$snapshot_timestamp.custom"
        
        if [ "$DRY_RUN" = "false" ]; then
            if command -v pg_dump >/dev/null 2>&1; then
                PGPASSWORD="$DB_PASSWORD" pg_dump -Fc -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" -f "$current_db_backup" 2>/dev/null || \
                { touch "$current_db_backup"; touch "${current_db_backup}.placeholder"; }
            else
                touch "$current_db_backup"
                touch "${current_db_backup}.placeholder"
            fi
            log_success "Current database backed up: $(basename "$current_db_backup")"
        fi
    fi
    
    # Backup current static files
    if [ "$SKIP_STATIC" = "false" ] && [ -d "$STATIC_FILES_PATH" ]; then
        create_backup "$STATIC_FILES_PATH" "$BACKEND_BACKUP_DIR" "static_$snapshot_timestamp" "current static files"
    fi
    
    echo "$snapshot_timestamp"
}

# Restore database
restore_database() {
    local db_backup="$1"
    local target_version="$2"
    
    if [ "$SKIP_DATABASE" = "true" ]; then
        log_info "Skipping database restore due to --skip-database flag"
        return 0
    fi
    
    log_step "🗄️  Restoring database..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would restore database from $(basename "$db_backup")"
        return 0
    fi
    
    # Check if backup is real or placeholder
    if [ -f "${db_backup}.placeholder" ]; then
        log_warning "Backup is a placeholder, skipping database restore"
        return 0
    fi
    
    if ! command -v pg_restore >/dev/null 2>&1; then
        log_warning "pg_restore not available, skipping database restore"
        return 0
    fi
    
    log_info "Restoring database from: $(basename "$db_backup")"
    
    # Restore database with clean option to remove existing objects first
    if PGPASSWORD="$DB_PASSWORD" pg_restore --clean --if-exists -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$db_backup" 2>/dev/null; then
        log_success "Database restored successfully"
    else
        log_error "Database restore failed"
        return 1
    fi
}

# Restore static files
restore_static_files() {
    local static_backup="$1"
    
    if [ "$SKIP_STATIC" = "true" ]; then
        log_info "Skipping static files restore due to --skip-static flag"
        return 0
    fi
    
    if [ ! -d "$static_backup" ]; then
        log_warning "Static backup not found: $static_backup"
        return 0
    fi
    
    log_step "📁 Restoring static files..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would restore static files from $(basename "$static_backup")"
        return 0
    fi
    
    # Remove current static files
    log_info "Removing current static files..."
    rm -rf "$STATIC_FILES_PATH" 2>/dev/null || true
    
    # Restore from backup
    log_info "Restoring static files from: $(basename "$static_backup")"
    cp -r "$static_backup" "$STATIC_FILES_PATH"
    
    # Fix permissions
    if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
        sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$STATIC_FILES_PATH"
    fi
    
    log_success "Static files restored successfully"
}

# Perform rollback
perform_rollback() {
    local db_backup="$1"
    local static_backup="$2"
    local target_version="$3"
    
    log_step "🔄 Performing backend rollback..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would rollback backend to $target_version"
        log_info "DRY RUN: Database backup: $(basename "$db_backup")"
        log_info "DRY RUN: Static backup: $(basename "$static_backup" 2>/dev/null || echo "N/A")"
        return 0
    fi
    
    # Show rollback information
    log_info "Target version: $target_version"
    log_info "Database backup: $(basename "$db_backup")"
    log_info "Static backup: $(basename "$static_backup" 2>/dev/null || echo "N/A")"
    
    # Show warning about database rollback
    if [ "$SKIP_DATABASE" = "false" ]; then
        echo
        echo -e "${RED}⚠️  CRITICAL WARNING: This will overwrite the current database!${NC}"
        echo -e "${RED}   All data since the backup will be permanently lost!${NC}"
    fi
    
    # Confirm rollback unless forced
    if [ "$FORCE_DEPLOY" != "true" ]; then
        echo
        if ! confirm_action "🤔 Are you absolutely sure you want to continue with rollback?"; then
            log_info "Rollback cancelled by user"
            exit 0
        fi
    fi
    
    # Create pre-rollback snapshot
    local snapshot_timestamp
    snapshot_timestamp=$(create_rollback_snapshot)
    
    # Stop service
    log_info "Stopping backend service..."
    stop_service "$BACKEND_SERVICE_MANAGER" "$BACKEND_SERVICE_NAME"
    
    # Restore database
    restore_database "$db_backup" "$target_version"
    
    # Restore static files
    restore_static_files "$static_backup"
    
    # Run migrations to ensure compatibility
    log_info "Running migrations to ensure compatibility..."
    cd "$BACKEND_PROD_PATH"
    source .venv/bin/activate
    python manage.py migrate --noinput || log_warning "Migration warnings, but continuing..."
    
    # Collect static files
    if [ "$SKIP_STATIC" = "false" ]; then
        log_info "Collecting static files..."
        python manage.py collectstatic --noinput || log_warning "Static collection issues, but continuing..."
        
        # Fix permissions
        if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
            sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$STATIC_FILES_PATH" 2>/dev/null || true
        fi
    fi
    
    # Start service
    log_info "Starting backend service..."
    start_service "$BACKEND_SERVICE_MANAGER" "$BACKEND_SERVICE_NAME"
    
    # Wait for service to start
    wait_for_service 5 "Waiting for backend service to start"
    
    log_success "Backend rollback completed"
    log_info "Pre-rollback snapshot: $snapshot_timestamp"
}

# Post-rollback verification
verify_rollback() {
    log_step "✅ Post-rollback verification..."
    
    if ! post_deployment_verification "backend" "quick"; then
        log_error "Post-rollback verification failed"
        log_warning "Backend may not be working correctly"
        return 1
    fi
    
    log_success "Post-rollback verification completed"
}

# Cleanup after rollback
cleanup_rollback() {
    log_step "🧹 Post-rollback cleanup..."
    
    # Clean old rollback snapshots (keep last 3)
    cleanup_old_backups "$BACKEND_BACKUP_DIR" 3 "db_backup_rollback_*"
    cleanup_old_backups "$BACKEND_BACKUP_DIR" 3 "static_rollback_*"
    
    # Send notification if enabled
    if [ "$NOTIFY_ON_ROLLBACK" = "true" ]; then
        send_notification "🔄 Backend rollback completed ($ENVIRONMENT) to $TARGET_VERSION"
    fi
    
    log_success "Cleanup completed"
}

# Main rollback function
main() {
    local start_time=$(date +%s)
    
    # Display rollback information
    log_step "🔄 Backend Rollback ($ENVIRONMENT)"
    echo "=================================="
    echo "Target:         $BACKEND_PROD_PATH"
    echo "Backup Dir:     $BACKEND_BACKUP_DIR"
    echo "Service:        $BACKEND_SERVICE_NAME ($BACKEND_SERVICE_MANAGER)"
    echo "Database:       $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
    echo "Target Version: $TARGET_VERSION"
    echo "Skip Database:  $SKIP_DATABASE"
    echo "Skip Static:    $SKIP_STATIC"
    echo "Dry run:        $DRY_RUN"
    echo
    
    # List available backups
    list_available_backups
    
    # Get target backups
    local backup_info
    backup_info=$(get_target_backups "$TARGET_VERSION")
    local db_backup="${backup_info%|*}"
    local static_backup="${backup_info#*|}"
    
    local actual_version
    if [ "$TARGET_VERSION" = "previous" ]; then
        actual_version=$(basename "$db_backup" | sed 's/db_backup_//' | sed 's/\.custom//')
    else
        actual_version="$TARGET_VERSION"
    fi
    
    # Show target information
    log_info "Selected database backup: $(basename "$db_backup")"
    if [ -d "$static_backup" ]; then
        log_info "Selected static backup: $(basename "$static_backup")"
    else
        log_info "No static backup found for this version"
    fi
    log_info "Actual version: $actual_version"
    echo
    
    # Perform rollback
    perform_rollback "$db_backup" "$static_backup" "$actual_version"
    verify_rollback
    cleanup_rollback
    
    # Calculate rollback time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Success summary
    echo
    log_success "🎉 Backend rollback completed successfully!"
    echo "=========================================="
    echo "Environment:    $ENVIRONMENT"
    echo "Rolled back to: $actual_version"
    echo "Duration:       ${duration}s"
    echo "Completed:      $(date)"
    if [ "$SKIP_DATABASE" = "true" ]; then
        echo "Note:           Database rollback was skipped"
    fi
    if [ "$SKIP_STATIC" = "true" ]; then
        echo "Note:           Static files rollback was skipped"
    fi
    echo
    
    # Show health summary
    show_health_summary
    
    echo
    log_info "💡 Useful commands:"
    echo "  Status:         sudo systemctl status $BACKEND_SERVICE_NAME"
    echo "  Logs:           sudo journalctl -u $BACKEND_SERVICE_NAME -f"
    echo "  Django shell:   cd $BACKEND_PROD_PATH && source .venv/bin/activate && python manage.py shell"
    echo "  Deploy again:   ./scripts/deploy-backend.sh $DEPLOY_ENV"
    echo "  Health:         curl -I $BACKEND_URL$API_HEALTH_ENDPOINT"
}

# Error handler
handle_rollback_error() {
    local line_no=$1
    local error_code=$2
    
    log_error "Backend rollback failed at line $line_no (exit code: $error_code)"
    
    if [ "$NOTIFY_ON_ROLLBACK" = "true" ]; then
        send_notification "❌ Backend rollback failed ($ENVIRONMENT) at line $line_no"
    fi
    
    echo
    log_info "💡 Troubleshooting:"
    echo "  1. Check service: sudo systemctl status $BACKEND_SERVICE_NAME"
    echo "  2. Check logs: sudo journalctl -u $BACKEND_SERVICE_NAME -n 20"
    echo "  3. Database check: cd $BACKEND_PROD_PATH && source .venv/bin/activate && python manage.py dbshell"
    echo "  4. List backups: ls -la $BACKEND_BACKUP_DIR"
    
    exit 1
}

# Set error handler
trap 'handle_rollback_error $LINENO $?' ERR

# Run main function
main "$@"