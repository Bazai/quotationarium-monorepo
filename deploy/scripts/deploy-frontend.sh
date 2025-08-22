#!/bin/bash
# =============================================================================
# FRONTEND DEPLOYMENT SCRIPT - CONFIGURABLE VERSION
# =============================================================================
# Deploy frontend application using centralized configuration
# Usage: ./scripts/deploy-frontend.sh [environment]
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

# Enhanced timeout function with real-time output streaming
run_with_timeout() {
    local timeout_duration="$1"
    local command="$2"
    shift 2
    local args="$@"
    
    log_info "Starting: $command $args with ${timeout_duration}s timeout"
    
    # Strategy 1: Try gtimeout with real-time output streaming
    if command -v gtimeout >/dev/null 2>&1; then
        log_info "Using gtimeout with real-time output streaming"
        
        # Create named pipes for stdout and stderr
        local stdout_pipe=$(mktemp -u)
        local stderr_pipe=$(mktemp -u)
        mkfifo "$stdout_pipe" "$stderr_pipe"
        
        # Background processes to handle pipe output
        (
            while read -r line; do
                echo "$line"
            done < "$stdout_pipe"
        ) &
        local stdout_handler_pid=$!
        
        (
            while read -r line; do
                echo "$line" >&2
            done < "$stderr_pipe"
        ) &
        local stderr_handler_pid=$!
        
        # Run the command with timeout, streaming to named pipes
        gtimeout --preserve-status --kill-after=10s "${timeout_duration}s" \
            bash -c "$command $args > '$stdout_pipe' 2> '$stderr_pipe'" &
        local cmd_pid=$!
        
        # Wait for the command to complete
        wait $cmd_pid 2>/dev/null
        local exit_code=$?
        
        # Clean up pipes and handlers
        kill $stdout_handler_pid $stderr_handler_pid 2>/dev/null || true
        rm -f "$stdout_pipe" "$stderr_pipe"
        
        if [ $exit_code -eq 124 ] || [ $exit_code -eq 137 ]; then
            log_error "Command timed out after ${timeout_duration}s (exit code: $exit_code)"
            # Cleanup any remaining processes
            pkill -f "$command" 2>/dev/null || true
            sleep 2
            pkill -9 -f "$command" 2>/dev/null || true
        fi
        
        return $exit_code
    
    # Strategy 2: Manual timeout with real-time output streaming
    else
        log_info "Using manual timeout with real-time output streaming"
        
        # Create named pipes for stdout and stderr
        local stdout_pipe=$(mktemp -u)
        local stderr_pipe=$(mktemp -u)
        mkfifo "$stdout_pipe" "$stderr_pipe"
        
        # Start background processes to handle pipe output
        (
            while read -r line; do
                echo "$line"
            done < "$stdout_pipe"
        ) &
        local stdout_handler_pid=$!
        
        (
            while read -r line; do
                echo "$line" >&2
            done < "$stderr_pipe"
        ) &
        local stderr_handler_pid=$!
        
        # Run command in background with output redirection
        (
            exec $command $args > "$stdout_pipe" 2> "$stderr_pipe"
        ) &
        local cmd_pid=$!
        
        local counter=0
        local success=false
        local cmd_exit_code=1
        
        while [ $counter -lt $timeout_duration ]; do
            # Check if main process still exists
            if ! kill -0 $cmd_pid 2>/dev/null; then
                wait $cmd_pid 2>/dev/null
                cmd_exit_code=$?
                success=true
                break
            fi
            
            sleep 1
            counter=$((counter + 1))
            
            # Progress indicator every 30 seconds
            if [ $((counter % 30)) -eq 0 ]; then
                log_info "$command still running... (${counter}/${timeout_duration}s)"
            fi
        done
        
        # Clean up pipe handlers
        sleep 1  # Give pipes time to flush
        kill $stdout_handler_pid $stderr_handler_pid 2>/dev/null || true
        rm -f "$stdout_pipe" "$stderr_pipe"
        
        if [ "$success" = "true" ]; then
            return $cmd_exit_code
        fi
        
        # Timeout reached - aggressive process termination
        log_warning "Timeout reached after ${timeout_duration}s, terminating $command and children (PID: $cmd_pid)"
        
        # Kill the main process and its children
        if command -v pgrep >/dev/null 2>&1; then
            # Find all processes matching the command pattern
            local pids=$(pgrep -f "$command" 2>/dev/null || true)
            if [ -n "$pids" ]; then
                log_info "Found processes to terminate: $pids"
                for pid in $pids; do
                    kill -TERM "$pid" 2>/dev/null || true
                done
                
                # Give processes 5 seconds to terminate gracefully
                sleep 5
                
                # Force kill any remaining processes
                for pid in $pids; do
                    if kill -0 "$pid" 2>/dev/null; then
                        log_warning "Force killing process $pid"
                        kill -KILL "$pid" 2>/dev/null || true
                    fi
                done
            fi
        fi
        
        # Additional cleanup for npm/node processes
        if [ "$command" = "npm" ]; then
            log_info "Cleaning up npm and node processes"
            pkill -f "npm.*build" 2>/dev/null || true
            sleep 2
            pkill -9 -f "npm.*build" 2>/dev/null || true
            pkill -f "next.*build" 2>/dev/null || true
            sleep 2
            pkill -9 -f "next.*build" 2>/dev/null || true
        fi
        
        # Final cleanup - kill the main process if it still exists
        if kill -0 $cmd_pid 2>/dev/null; then
            kill -KILL $cmd_pid 2>/dev/null || true
        fi
        
        return 124  # timeout exit code
    fi
}

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
Frontend Deployment Script

Usage: $0 [environment] [options]

Environments:
  production    Production deployment (default)
  local         Local testing deployment
  staging       Staging deployment

Options:
  --skip-tests     Skip running tests
  --skip-backup    Skip creating backup
  --force          Force deployment even if validation fails
  --verbose, -v    Verbose output
  --dry-run        Show what would be done without executing
  --help, -h       Show this help

Examples:
  $0                          # Deploy to production
  $0 local --verbose          # Deploy to local with verbose output
  $0 production --dry-run     # Show production deployment plan
  $0 local --skip-tests       # Deploy to local without tests

Configuration:
  Environment: $ENVIRONMENT
  Source:      $FRONTEND_SOURCE_PATH
  Target:      $FRONTEND_PROD_PATH
  Service:     $FRONTEND_SERVICE_NAME ($FRONTEND_SERVICE_MANAGER)

EOF
}

# Pre-deployment validation
run_pre_deployment_checks() {
    log_step "🔍 Pre-deployment validation..."
    
    # Validate configuration for frontend
    if ! pre_deployment_checks "frontend"; then
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
    
    log_step "🧪 Running frontend tests..."
    
    cd "$FRONTEND_SOURCE_PATH"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would run frontend tests"
        return 0
    fi
    
    # Type checking
    log_info "Running type check..."
    if ! npm run type-check; then
        log_error "Frontend type checking failed"
        return 1
    fi
    
    # Linting
    log_info "Running linter..."
    if ! npm run lint; then
        log_error "Frontend linting failed"
        return 1
    fi
    
    log_success "Frontend tests completed successfully"
}

# Create backup
create_deployment_backup() {
    if [ "$SKIP_BACKUP" = "true" ]; then
        log_info "Skipping backup due to --skip-backup flag"
        return 0
    fi
    
    log_step "📦 Creating deployment backup..."
    
    # Backup current build
    if [ -d "$FRONTEND_PROD_PATH/.next" ]; then
        create_backup "$FRONTEND_PROD_PATH/.next" "$FRONTEND_BACKUP_DIR" ".next_$TIMESTAMP" "build directory"
    fi
    
    # Backup package-lock.json if exists
    if [ -f "$FRONTEND_PROD_PATH/package-lock.json" ]; then
        create_backup "$FRONTEND_PROD_PATH/package-lock.json" "$FRONTEND_BACKUP_DIR" "package-lock_$TIMESTAMP.json" "package lock"
    fi
    
    log_success "Deployment backup completed"
}

# Install dependencies
install_dependencies() {
    log_step "📦 Managing dependencies..."
    
    cd "$FRONTEND_PROD_PATH"
    
    # Check if package.json changed or if node_modules is missing
    local install_needed=true
    local reason="first deployment"
    
    if [ -f "$FRONTEND_BACKUP_DIR/package-lock_$TIMESTAMP.json" ]; then
        if [ -f "package-lock.json" ] && diff -q "package-lock.json" "$FRONTEND_BACKUP_DIR/package-lock_$TIMESTAMP.json" > /dev/null 2>&1; then
            if [ -d "node_modules" ] && [ -n "$(ls -A node_modules 2>/dev/null)" ]; then
                # Check if devDependencies are installed (needed for TypeScript builds)
                if [ -f "package.json" ] && command -v jq >/dev/null 2>&1; then
                    local has_dev_deps=$(jq -r '.devDependencies // {} | keys | length' package.json 2>/dev/null)
                    if [ "$has_dev_deps" -gt 0 ]; then
                        # Check if TypeScript is needed but not installed
                        local needs_typescript=$(jq -r '.devDependencies.typescript // empty' package.json 2>/dev/null)
                        if [ -n "$needs_typescript" ] && [ ! -f "node_modules/typescript/package.json" ]; then
                            install_needed=true
                            reason="TypeScript devDependencies missing"
                        else
                            install_needed=false
                            reason="no package changes and dependencies exist"
                        fi
                    else
                        install_needed=false
                        reason="no package changes and dependencies exist"
                    fi
                else
                    install_needed=false
                    reason="no package changes and dependencies exist"
                fi
            else
                install_needed=true
                reason="node_modules directory missing or empty"
            fi
        else
            reason="package-lock.json changed"
        fi
    else
        reason="no previous backup found"
    fi
    
    if [ "$install_needed" = "true" ]; then
        log_info "Installing dependencies ($reason)..."
        
        if [ "$DRY_RUN" = "true" ]; then
            log_info "DRY RUN: Would install npm dependencies"
        else
            # Install both production and dev dependencies for builds
            log_info "Installing all dependencies (including devDependencies for build process)..."
            if ! run_with_timeout "$NPM_INSTALL_TIMEOUT" npm ci; then
                log_error "npm install failed or timed out"
                return 1
            fi
        fi
        
        log_success "Dependencies installed successfully"
    else
        log_info "Skipping dependency installation ($reason)"
    fi
}

# Build application with enhanced progress tracking
build_application() {
    log_step "🔨 Building application..."
    
    cd "$FRONTEND_PROD_PATH"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would build frontend application"
        return 0
    fi
    
    # Pre-build checks and setup
    log_info "Performing pre-build checks..."
    
    # Check available disk space
    local available_space=$(df -h . | awk 'NR==2 {print $4}')
    log_info "Available disk space: $available_space"
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        log_error "package.json not found in $FRONTEND_PROD_PATH"
        return 1
    fi
    
    # Check if build script exists
    if ! npm run-script --list 2>/dev/null | grep -q "build"; then
        log_error "Build script not found in package.json"
        return 1
    fi
    
    # Set Node.js memory limit
    export NODE_OPTIONS="--max-old-space-size=$NODE_MAX_OLD_SPACE_SIZE"
    
    log_info "Build Configuration:"
    log_info "  Memory limit: ${NODE_MAX_OLD_SPACE_SIZE}MB"
    log_info "  Build timeout: ${BUILD_TIMEOUT}s" 
    log_info "  Node version: $(node --version 2>/dev/null || echo 'unknown')"
    log_info "  NPM version: $(npm --version 2>/dev/null || echo 'unknown')"
    
    # Remove any existing build artifacts
    if [ -d ".next" ]; then
        log_info "Cleaning previous build artifacts..."
        rm -rf ".next"
    fi
    
    # Start build process with enhanced monitoring
    log_info "Starting Next.js build process..."
    log_info "📊 Build progress will be shown below:"
    echo "================================="
    
    # Create a marker file to track build start
    echo "$(date)" > .build-start-time
    
    # Use enhanced timeout function with real-time output
    if run_with_timeout "$BUILD_TIMEOUT" npm run build; then
        # Build completed successfully
        local build_end_time=$(date)
        local build_start_time=$(cat .build-start-time 2>/dev/null || echo "unknown")
        rm -f .build-start-time
        
        echo "================================="
        log_success "Build completed successfully!"
        log_info "Build started: $build_start_time"
        log_info "Build finished: $build_end_time"
        
        # Show detailed build information
        if [ -d ".next" ]; then
            local build_size=$(du -sh .next 2>/dev/null | cut -f1 || echo "unknown")
            log_info "Build artifacts size: $build_size"
            
            # Show some build statistics if available
            if [ -f ".next/BUILD_ID" ]; then
                local build_id=$(cat .next/BUILD_ID)
                log_info "Next.js Build ID: $build_id"
            fi
            
            # Count generated files
            local static_files=$(find .next -name "*.js" -o -name "*.css" | wc -l | xargs)
            log_info "Generated static files: $static_files"
            
            # Check if build is optimized
            if [ -d ".next/static" ]; then
                log_success "Static assets generated successfully"
            fi
        else
            log_warning "Build directory (.next) not found after build"
        fi
        
    else
        # Build failed or timed out
        local build_end_time=$(date)
        local build_start_time=$(cat .build-start-time 2>/dev/null || echo "unknown")
        rm -f .build-start-time
        
        echo "================================="
        log_error "Build failed or timed out!"
        log_info "Build started: $build_start_time"
        log_info "Build failed: $build_end_time"
        
        # Show helpful debugging information
        log_info "💡 Debugging information:"
        if [ -f "package.json" ]; then
            local next_version=$(npm list next --depth=0 2>/dev/null | grep next@ || echo "Next.js version: unknown")
            log_info "  $next_version"
        fi
        
        # Check for common build issues
        if [ ! -d "node_modules" ]; then
            log_error "  node_modules directory missing - run npm install first"
        fi
        
        # Check memory usage
        local memory_usage=$(ps aux | awk '{sum+=$6} END {print sum/1024}' 2>/dev/null || echo "unknown")
        log_info "  Current memory usage: ${memory_usage}MB"
        
        # Show last few lines of any error logs
        if [ -f "npm-debug.log" ]; then
            log_info "  Last lines from npm-debug.log:"
            tail -5 npm-debug.log | while read -r line; do
                log_info "    $line"
            done
        fi
        
        # Attempt rollback if backup exists
        if [ -d "$FRONTEND_BACKUP_DIR/.next_$TIMESTAMP" ]; then
            log_warning "🔄 Attempting to restore from backup..."
            rm -rf ".next" 2>/dev/null || true
            if cp -r "$FRONTEND_BACKUP_DIR/.next_$TIMESTAMP" ".next" 2>/dev/null; then
                if [ "$SERVICE_USER" != "$(whoami)" ] && [ "$SERVICE_USER" != "" ]; then
                    sudo chown -R "$SERVICE_USER:$SERVICE_USER" ".next" 2>/dev/null || true
                fi
                log_success "Previous build restored from backup"
            else
                log_error "Failed to restore backup"
            fi
        else
            log_warning "No backup available for rollback"
        fi
        
        return 1
    fi
}

# Deploy application
deploy_application() {
    log_step "🚀 Deploying application..."
    
    # Sync files from source to production
    log_info "Syncing application files..."
    sync_files "$FRONTEND_SOURCE_PATH" "$FRONTEND_PROD_PATH" "$RSYNC_EXCLUDE_FRONTEND"
    
    # Install dependencies
    install_dependencies
    
    # Build application
    build_application
    
    # Stop service
    log_info "Stopping frontend service..."
    stop_service "$FRONTEND_SERVICE_MANAGER" "$FRONTEND_SERVICE_NAME"
    
    # Start service
    log_info "Starting frontend service..."
    start_service "$FRONTEND_SERVICE_MANAGER" "$FRONTEND_SERVICE_NAME"
    
    # Wait for service to start
    wait_for_service 3 "Waiting for frontend service to start"
    
    log_success "Application deployed successfully"
}

# Post-deployment verification
run_post_deployment_checks() {
    log_step "✅ Post-deployment verification..."
    
    if ! post_deployment_verification "frontend" "detailed"; then
        log_error "Post-deployment verification failed"
        log_warning "Consider rolling back: ./scripts/rollback-frontend.sh"
        return 1
    fi
    
    log_success "Post-deployment verification completed"
}

# Cleanup
cleanup_deployment() {
    log_step "🧹 Cleanup..."
    
    # Clean old backups
    cleanup_old_backups "$FRONTEND_BACKUP_DIR"
    
    # Send notification if enabled
    if [ "$NOTIFY_ON_DEPLOY" = "true" ]; then
        send_notification "✅ Frontend deployment completed successfully ($ENVIRONMENT)"
    fi
    
    log_success "Cleanup completed"
}

# Main deployment function
main() {
    local start_time=$(date +%s)
    
    # Display deployment information
    log_step "🎨 Frontend Deployment ($ENVIRONMENT)"
    echo "================================="
    echo "Source:      $FRONTEND_SOURCE_PATH"
    echo "Target:      $FRONTEND_PROD_PATH"
    echo "Service:     $FRONTEND_SERVICE_NAME ($FRONTEND_SERVICE_MANAGER)"
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
    log_success "🎉 Frontend deployment completed successfully!"
    echo "=========================================="
    echo "Environment: $ENVIRONMENT"
    echo "Version:     $TIMESTAMP"
    echo "Duration:    ${minutes}m ${seconds}s"
    echo "Completed:   $(date)"
    echo
    
    # Show health summary
    show_health_summary
    
    echo
    log_info "💡 Useful commands:"
    echo "  Status:     ./scripts/deploy-frontend.sh $DEPLOY_ENV --dry-run"
    echo "  Logs:       sudo -u $SERVICE_USER pm2 logs $FRONTEND_SERVICE_NAME"
    echo "  Rollback:   ./scripts/rollback-frontend.sh $DEPLOY_ENV"
    echo "  Health:     curl -I $FRONTEND_URL$FRONTEND_HEALTH_ENDPOINT"
}

# Error handler
handle_deployment_error() {
    local line_no=$1
    local error_code=$2
    
    log_error "Frontend deployment failed at line $line_no (exit code: $error_code)"
    
    if [ "$NOTIFY_ON_DEPLOY" = "true" ]; then
        send_notification "❌ Frontend deployment failed ($ENVIRONMENT) at line $line_no"
    fi
    
    echo
    log_info "💡 Troubleshooting:"
    echo "  1. Check logs: sudo -u $SERVICE_USER pm2 logs $FRONTEND_SERVICE_NAME"
    echo "  2. Check service: sudo -u $SERVICE_USER pm2 status"
    echo "  3. Manual rollback: ./scripts/rollback-frontend.sh $DEPLOY_ENV"
    echo "  4. Health check: curl -I $FRONTEND_URL$FRONTEND_HEALTH_ENDPOINT"
    
    exit 1
}

# Set error handler
trap 'handle_deployment_error $LINENO $?' ERR

# Run main function
main "$@"
