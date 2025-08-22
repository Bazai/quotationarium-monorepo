#!/bin/bash
# =============================================================================
# FRONTEND ROLLBACK SCRIPT - CONFIGURABLE VERSION
# =============================================================================
# Rollback frontend application using centralized configuration
# Usage: ./scripts/rollback-frontend.sh [environment] [target_version]
# =============================================================================

set -e

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$DEPLOY_ROOT")"

# Help function first
show_help() {
    cat << EOF
Frontend Rollback Script

Usage: $0 [environment] [target_version] [options]

Environments:
  production    Production rollback (default)
  local         Local testing rollback
  staging       Staging rollback

Target Version:
  previous      Rollback to previous version (default)
  TIMESTAMP     Rollback to specific version (e.g., 20241201_143000)

Options:
  --force         Force rollback without confirmation
  --verbose, -v   Verbose output
  --dry-run       Show what would be done without executing
  --help, -h      Show this help

Examples:
  $0                                    # Rollback production to previous
  $0 local                             # Rollback local to previous
  $0 production 20241201_143000        # Rollback production to specific version
  $0 local --dry-run                   # Show what local rollback would do

EOF
}

# Check for help first
for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        show_help
        exit 0
    fi
done

# Parse arguments
DEPLOY_ENV="production"
TARGET_VERSION="previous"
DRY_RUN=false
FORCE_DEPLOY=false
VERBOSE=false

# Parse all command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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
            # Already handled above
            shift
            ;;
        production|local|staging)
            DEPLOY_ENV="$1"
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

# Load configuration and libraries
source "$DEPLOY_ROOT/config/deploy.conf" "$DEPLOY_ENV"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/health-checks.sh"

# Initialize common utilities
init_common

# List available backups
list_available_backups() {
    log_step "📋 Available frontend backups:"
    
    if [ ! -d "$FRONTEND_BACKUP_DIR" ]; then
        log_warning "Backup directory not found: $FRONTEND_BACKUP_DIR"
        return 1
    fi
    
    local backups=($(find "$FRONTEND_BACKUP_DIR" -name '.next_*' -type d | sort -r | head -10))
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_warning "No frontend backups found in $FRONTEND_BACKUP_DIR"
        return 1
    fi
    
    echo
    printf "%-3s %-20s %-12s %-10s %s\n" "#" "Backup Name" "Date" "Size" "Age"
    echo "------------------------------------------------------------"
    
    local count=1
    for backup in "${backups[@]}"; do
        if [ -d "$backup" ]; then
            local backup_name=$(basename "$backup")
            local timestamp=${backup_name#.next_}
            
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
            
            printf "%-3d %-20s %-12s %-10s %s\n" "$count" "$backup_name" "$date_formatted" "$size" "$age_str"
            ((count++))
        fi
    done
    echo
}

# Get target backup path
get_target_backup() {
    local target_version="$1"
    
    if [ "$target_version" = "previous" ]; then
        # Find the latest backup using find (compatible with macOS)
        local latest_backup=$(find "$FRONTEND_BACKUP_DIR" -name '.next_*' -type d | sort -r | head -1)
        if [ -z "$latest_backup" ]; then
            log_error "No previous backup found"
            return 1
        fi
        echo "$latest_backup"
    else
        # Use specific version
        local specific_backup="$FRONTEND_BACKUP_DIR/.next_$target_version"
        if [ ! -d "$specific_backup" ]; then
            log_error "Backup not found: .next_$target_version"
            return 1
        fi
        echo "$specific_backup"
    fi
}

# Create rollback snapshot
create_rollback_snapshot() {
    log_step "📸 Creating pre-rollback snapshot..."
    
    if [ -d "$FRONTEND_PROD_PATH/.next" ]; then
        local snapshot_name="rollback_snapshot_$TIMESTAMP"
        create_backup "$FRONTEND_PROD_PATH/.next" "$FRONTEND_BACKUP_DIR" "$snapshot_name" "pre-rollback snapshot"
        echo "$FRONTEND_BACKUP_DIR/$snapshot_name"
    else
        log_warning "No current build to snapshot"
        echo ""
    fi
}

# Perform rollback
perform_rollback() {
    local target_backup="$1"
    local target_version="$2"
    
    log_step "🔄 Performing frontend rollback..."
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would rollback frontend to $target_version"
        log_info "DRY RUN: Would use backup: $target_backup"
        return 0
    fi
    
    # Show rollback information
    log_info "Target version: $target_version"
    log_info "Backup source: $target_backup"
    log_info "Target directory: $FRONTEND_PROD_PATH"
    
    # Confirm rollback unless forced
    if [ "$FORCE_DEPLOY" != "true" ]; then
        echo
        echo -e "${RED}⚠️  WARNING: This will replace the current frontend with the backup!${NC}"
        if ! confirm_action "🤔 Are you sure you want to continue with rollback?"; then
            log_info "Rollback cancelled by user"
            exit 0
        fi
    fi
    
    # Create pre-rollback snapshot
    local snapshot_path
    snapshot_path=$(create_rollback_snapshot)
    
    # Stop service
    log_info "Stopping frontend service..."
    # stop_service "$FRONTEND_SERVICE_MANAGER" "$FRONTEND_SERVICE_NAME"
    
    # Remove current build
    log_info "Removing current frontend build..."
    rm -rf "$FRONTEND_PROD_PATH/.next" 2>/dev/null || true
    
    # Restore from backup
    log_info "Restoring from backup..."
    cp -r "$target_backup" "$FRONTEND_PROD_PATH/.next"
    
    # Fix permissions
    if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
        sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$FRONTEND_PROD_PATH/.next"
    fi
    
    # Start service
    log_info "Starting frontend service..."
    start_service "$FRONTEND_SERVICE_MANAGER" "$FRONTEND_SERVICE_NAME"
    
    # Wait for service to start
    wait_for_service 3 "Waiting for frontend service to start"
    
    log_success "Frontend rollback completed"
    
    if [ -n "$snapshot_path" ]; then
        log_info "Pre-rollback snapshot saved: $(basename "$snapshot_path")"
    fi
}

# Post-rollback verification
verify_rollback() {
    log_step "✅ Post-rollback verification..."
    
    if ! post_deployment_verification "frontend" "quick"; then
        log_error "Post-rollback verification failed"
        log_warning "Frontend may not be working correctly"
        return 1
    fi
    
    log_success "Post-rollback verification completed"
}

# Cleanup after rollback
cleanup_rollback() {
    log_step "🧹 Post-rollback cleanup..."
    
    # Clean old snapshots (keep last 3)
    cleanup_old_backups "$FRONTEND_BACKUP_DIR" 3 "rollback_snapshot_*"
    
    # Send notification if enabled
    if [ "$NOTIFY_ON_ROLLBACK" = "true" ]; then
        send_notification "🔄 Frontend rollback completed ($ENVIRONMENT) to $TARGET_VERSION"
    fi
    
    log_success "Cleanup completed"
}

# Main rollback function
main() {
    local start_time=$(date +%s)
    
    # Display rollback information
    log_step "🔄 Frontend Rollback ($ENVIRONMENT)"
    echo "==================================="
    echo "Target:         $FRONTEND_PROD_PATH"
    echo "Backup Dir:     $FRONTEND_BACKUP_DIR"
    echo "Service:        $FRONTEND_SERVICE_NAME ($FRONTEND_SERVICE_MANAGER)"
    echo "Target Version: $TARGET_VERSION"
    echo "Dry run:        $DRY_RUN"
    echo
    
    # List available backups
    list_available_backups
    
    # Get target backup
    local target_backup
    target_backup=$(get_target_backup "$TARGET_VERSION")
    local actual_version=$(basename "$target_backup" | sed 's/\.next_//')
    
    # Show target information
    log_info "Selected backup: $(basename "$target_backup")"
    log_info "Actual version: $actual_version"
    echo
    
    # Perform rollback
    perform_rollback "$target_backup" "$actual_version"
    verify_rollback
    cleanup_rollback
    
    # Calculate rollback time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Success summary
    echo
    log_success "🎉 Frontend rollback completed successfully!"
    echo "==========================================="
    echo "Environment:    $ENVIRONMENT"
    echo "Rolled back to: $actual_version"
    echo "Duration:       ${duration}s"
    echo "Completed:      $(date)"
    echo
    
    # Show health summary
    show_health_summary
    
    echo
    log_info "💡 Useful commands:"
    echo "  Status:         ./scripts/deploy-frontend.sh $DEPLOY_ENV --dry-run"
    echo "  Logs:           sudo -u $SERVICE_USER pm2 logs $FRONTEND_SERVICE_NAME"
    echo "  Deploy again:   ./scripts/deploy-frontend.sh $DEPLOY_ENV"
    echo "  Health:         curl -I $FRONTEND_URL$FRONTEND_HEALTH_ENDPOINT"
}

# Error handler
handle_rollback_error() {
    local line_no=$1
    local error_code=$2
    
    log_error "Frontend rollback failed at line $line_no (exit code: $error_code)"
    
    if [ "$NOTIFY_ON_ROLLBACK" = "true" ]; then
        send_notification "❌ Frontend rollback failed ($ENVIRONMENT) at line $line_no"
    fi
    
    echo
    log_info "💡 Troubleshooting:"
    echo "  1. Check service: sudo -u $SERVICE_USER pm2 status"
    echo "  2. Check logs: sudo -u $SERVICE_USER pm2 logs $FRONTEND_SERVICE_NAME"
    echo "  3. Manual restart: sudo -u $SERVICE_USER pm2 restart $FRONTEND_SERVICE_NAME"
    echo "  4. List backups: ls -la $FRONTEND_BACKUP_DIR"
    
    exit 1
}

# Set error handler
trap 'handle_rollback_error $LINENO $?' ERR

# Run main function
main "$@"
