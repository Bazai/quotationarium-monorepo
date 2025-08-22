#!/bin/bash
# =============================================================================
# COMMON DEPLOYMENT UTILITIES
# =============================================================================
# Shared functions for all deployment scripts
# Usage: source scripts/lib/common.sh
# =============================================================================

# Colors for output (unified across all scripts)
setup_colors() {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
    
    # Export for use in other scripts
    export RED GREEN YELLOW BLUE CYAN NC
}

# Logging functions with consistent formatting
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_debug() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}🔍 $1${NC}"
    fi
}

log_step() {
    echo -e "${BLUE}$1${NC}"
}

# Enhanced logging with timestamps
log_with_timestamp() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO") log_info "[$timestamp] $message" ;;
        "SUCCESS") log_success "[$timestamp] $message" ;;
        "WARNING") log_warning "[$timestamp] $message" ;;
        "ERROR") log_error "[$timestamp] $message" ;;
        "DEBUG") log_debug "[$timestamp] $message" ;;
    esac
}

# Backup utilities
create_backup() {
    local source_path=$1
    local backup_dir=$2
    local backup_name=${3:-"backup_$TIMESTAMP"}
    local description=${4:-""}
    
    log_debug "Creating backup: $source_path -> $backup_dir/$backup_name"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"
    
    if [ -d "$source_path" ] || [ -f "$source_path" ]; then
        if [ "$DRY_RUN" = "true" ]; then
            log_info "DRY RUN: Would create backup $backup_name"
            return 0
        fi
        
        # Use sudo if needed based on SERVICE_USER
        local sudo_cmd=""
        if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
            sudo_cmd="sudo"
        fi
        
        if $sudo_cmd cp -r "$source_path" "$backup_dir/$backup_name" 2>/dev/null; then
            log_success "Backup created: $backup_name${description:+ ($description)}"
            return 0
        else
            log_error "Failed to create backup: $backup_name"
            return 1
        fi
    else
        log_warning "Source path for backup does not exist: $source_path"
        return 1
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    local backup_dir=$1
    local retention_count=${2:-$BACKUP_RETENTION_COUNT}
    local pattern=${3:-"backup_*"}
    
    log_debug "Cleaning old backups in $backup_dir (keeping $retention_count)"
    
    if [ ! -d "$backup_dir" ]; then
        log_warning "Backup directory does not exist: $backup_dir"
        return 0
    fi
    
    cd "$backup_dir" || return 1
    
    # Get list of backups sorted by modification time (newest first)
    local backups=($(ls -t $pattern 2>/dev/null))
    local total_backups=${#backups[@]}
    
    if [ $total_backups -le $retention_count ]; then
        log_debug "No cleanup needed ($total_backups <= $retention_count backups)"
        return 0
    fi
    
    # Calculate how many to remove
    local to_remove=$((total_backups - retention_count))
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would remove $to_remove old backups"
        return 0
    fi
    
    # Remove old backups
    for ((i=retention_count; i<total_backups; i++)); do
        local backup_to_remove="${backups[$i]}"
        if [ -n "$backup_to_remove" ]; then
            rm -rf "$backup_to_remove" 2>/dev/null
            log_debug "Removed old backup: $backup_to_remove"
        fi
    done
    
    log_success "Cleaned old backups, kept last $retention_count"
}

# File synchronization with rsync
sync_files() {
    local source_path=$1
    local dest_path=$2
    local exclude_patterns=$3
    local delete_flag=${4:-$RSYNC_DELETE}
    
    log_debug "Syncing files: $source_path -> $dest_path"
    
    # Build rsync command
    local rsync_cmd="rsync -av"
    
    # Add exclude patterns
    if [ -n "$exclude_patterns" ]; then
        rsync_cmd="$rsync_cmd $exclude_patterns"
    fi
    
    # Add delete flag if enabled
    if [ "$delete_flag" = "true" ]; then
        rsync_cmd="$rsync_cmd --delete"
    fi
    
    # Add chown if we need to change ownership
    if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
        rsync_cmd="$rsync_cmd --chown=$SERVICE_USER:$SERVICE_USER"
    fi
    
    # Add source and destination
    rsync_cmd="$rsync_cmd \"$source_path/\" \"$dest_path/\""
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would execute: $rsync_cmd"
        return 0
    fi
    
    log_debug "Executing: $rsync_cmd"
    
    # Use sudo if needed
    local sudo_cmd=""
    if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
        sudo_cmd="sudo"
    fi
    
    if eval "$sudo_cmd $rsync_cmd"; then
        log_success "Files synced successfully"
        return 0
    else
        log_error "File synchronization failed"
        return 1
    fi
}

# Service management utilities
stop_service() {
    local service_manager=$1
    local service_name=$2
    
    log_debug "Stopping service: $service_name ($service_manager)"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would stop service $service_name"
        return 0
    fi
    
    case $service_manager in
        "systemd")
            if sudo systemctl stop "$service_name" 2>/dev/null; then
                log_success "Service stopped: $service_name"
                return 0
            else
                log_warning "Service was not running or failed to stop: $service_name"
                return 1
            fi
            ;;
        "pm2")
            if sudo -u "$SERVICE_USER" pm2 stop "$service_name" 2>/dev/null; then
                log_success "PM2 process stopped: $service_name"
                return 0
            else
                log_warning "PM2 process was not running or failed to stop: $service_name"
                return 1
            fi
            ;;
        "manual")
            log_info "Manual service management - service not stopped automatically"
            return 0
            ;;
        *)
            log_error "Unknown service manager: $service_manager"
            return 1
            ;;
    esac
}

start_service() {
    local service_manager=$1
    local service_name=$2
    
    log_debug "Starting service: $service_name ($service_manager)"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would start service $service_name"
        return 0
    fi
    
    case $service_manager in
        "systemd")
            if sudo systemctl start "$service_name"; then
                log_success "Service started: $service_name"
                return 0
            else
                log_error "Failed to start service: $service_name"
                return 1
            fi
            ;;
        "pm2")
            # Try to start, if fails try restart
            if sudo -u "$SERVICE_USER" pm2 start "$service_name" 2>/dev/null || sudo -u "$SERVICE_USER" pm2 restart "$service_name" 2>/dev/null; then
                log_success "PM2 process started: $service_name"
                return 0
            else
                log_error "Failed to start PM2 process: $service_name"
                return 1
            fi
            ;;
        "manual")
            log_info "Manual service management - service not started automatically"
            return 0
            ;;
        *)
            log_error "Unknown service manager: $service_manager"
            return 1
            ;;
    esac
}

restart_service() {
    local service_manager=$1
    local service_name=$2
    
    log_debug "Restarting service: $service_name ($service_manager)"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would restart service $service_name"
        return 0
    fi
    
    case $service_manager in
        "systemd")
            if sudo systemctl restart "$service_name"; then
                log_success "Service restarted: $service_name"
                return 0
            else
                log_error "Failed to restart service: $service_name"
                return 1
            fi
            ;;
        "pm2")
            if sudo -u "$SERVICE_USER" pm2 restart "$service_name"; then
                log_success "PM2 process restarted: $service_name"
                return 0
            else
                log_error "Failed to restart PM2 process: $service_name"
                return 1
            fi
            ;;
        *)
            # Try stop then start
            stop_service "$service_manager" "$service_name"
            sleep 2
            start_service "$service_manager" "$service_name"
            ;;
    esac
}

# Check if service is running
is_service_running() {
    local service_manager=$1
    local service_name=$2
    
    case $service_manager in
        "systemd")
            systemctl is-active --quiet "$service_name"
            ;;
        "pm2")
            sudo -u "$SERVICE_USER" pm2 list 2>/dev/null | grep -q "$service_name.*online"
            ;;
        "manual")
            # For manual services, assume they're running
            return 0
            ;;
        *)
            log_error "Unknown service manager: $service_manager"
            return 1
            ;;
    esac
}

# Dependency management
has_package_changes() {
    local package_file=$1
    local backup_dir=$2
    local current_timestamp=$3
    
    # Check if package file exists in backup
    local backup_package="$backup_dir/package_lock_$current_timestamp.json"
    if [ -f "$backup_package" ]; then
        if ! diff -q "$package_file" "$backup_package" > /dev/null 2>&1; then
            return 0  # Changes detected
        fi
    else
        return 0  # No backup exists, assume changes
    fi
    
    return 1  # No changes
}

has_requirements_changes() {
    local requirements_file=$1
    local backup_dir=$2
    local current_timestamp=$3
    
    # Check if requirements file exists in backup
    local backup_requirements="$backup_dir/requirements_$current_timestamp.txt"
    if [ -f "$backup_requirements" ]; then
        if ! diff -q "$requirements_file" "$backup_requirements" > /dev/null 2>&1; then
            return 0  # Changes detected
        fi
    else
        return 0  # No backup exists, assume changes
    fi
    
    return 1  # No changes
}

# Utility functions
wait_for_service() {
    local seconds=${1:-5}
    local message=${2:-"Waiting for service to start"}
    
    log_info "$message..."
    sleep "$seconds"
}

confirm_action() {
    local message=$1
    local default_no=${2:-true}
    
    if [ "$FORCE_DEPLOY" = "true" ]; then
        log_info "Force mode enabled, skipping confirmation"
        return 0
    fi
    
    if [ "$default_no" = "true" ]; then
        read -p "$message [y/N] " -n 1 -r
    else
        read -p "$message [Y/n] " -n 1 -r
    fi
    
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    elif [ "$default_no" = "false" ] && [[ $REPLY =~ ^$ ]]; then
        return 0
    else
        return 1
    fi
}

# Error handling
handle_error() {
    local line_no=$1
    local error_code=$2
    local script_name=${3:-"$(basename "$0")"}
    
    log_error "Error in $script_name at line $line_no (exit code: $error_code)"
    
    # Optional: send notification about error
    if [ "$NOTIFY_ON_DEPLOY" = "true" ]; then
        send_notification "❌ Deployment failed in $script_name at line $line_no"
    fi
}

# Simple notification function (placeholder for webhook/email)
send_notification() {
    local message=$1
    local webhook_url=${2:-$NOTIFY_WEBHOOK_URL}
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would send notification: $message"
        return 0
    fi
    
    if [ -n "$webhook_url" ]; then
        # Simple webhook notification
        curl -s -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"$message\"}" \
             "$webhook_url" > /dev/null 2>&1 || true
    fi
    
    # Log notification locally
    log_debug "Notification: $message"
}

# Initialize common setup
init_common() {
    setup_colors
    
    # Set up error handling if not in DRY_RUN mode
    if [ "$DRY_RUN" != "true" ]; then
        set -e  # Exit on error
        trap 'handle_error $LINENO $? "${BASH_SOURCE[0]}"' ERR
    fi
    
    log_debug "Common utilities initialized"
}