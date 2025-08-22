#!/bin/bash
# =============================================================================
# HEALTH CHECK UTILITIES
# =============================================================================
# Health check functions for deployment verification
# Usage: source scripts/lib/health-checks.sh
# =============================================================================

# HTTP health check
check_http_endpoint() {
    local url=$1
    local expected_status=${2:-200}
    local timeout=${3:-$HEALTH_CHECK_TIMEOUT}
    local description=${4:-"$url"}
    
    log_debug "Checking HTTP endpoint: $url (expecting $expected_status)"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would check HTTP endpoint $url"
        return 0
    fi
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [ "$response_code" = "$expected_status" ]; then
        log_debug "HTTP check passed: $description ($response_code)"
        return 0
    else
        log_debug "HTTP check failed: $description (got $response_code, expected $expected_status)"
        return 1
    fi
}

# Frontend health check
check_frontend_health() {
    local retries=${1:-$HEALTH_CHECK_RETRIES}
    local delay=${2:-$HEALTH_CHECK_DELAY}
    
    log_step "🏥 Checking frontend health..."
    
    for ((i=1; i<=retries; i++)); do
        if check_http_endpoint "$FRONTEND_URL$FRONTEND_HEALTH_ENDPOINT" 200 "$HEALTH_CHECK_TIMEOUT" "Frontend"; then
            log_success "Frontend is responding"
            return 0
        fi
        
        if [ $i -lt $retries ]; then
            log_debug "Frontend check attempt $i/$retries failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
    done
    
    log_error "Frontend health check failed after $retries attempts"
    return 1
}

# Backend health check
check_backend_health() {
    local retries=${1:-$HEALTH_CHECK_RETRIES}
    local delay=${2:-$HEALTH_CHECK_DELAY}
    
    log_step "🏥 Checking backend health..."
    
    for ((i=1; i<=retries; i++)); do
        if check_http_endpoint "$BACKEND_URL$API_HEALTH_ENDPOINT" 200 "$HEALTH_CHECK_TIMEOUT" "Backend API"; then
            log_success "Backend API is responding"
            return 0
        fi
        
        if [ $i -lt $retries ]; then
            log_debug "Backend check attempt $i/$retries failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
    done
    
    log_error "Backend health check failed after $retries attempts"
    return 1
}

# Service status check
check_service_status() {
    local service_manager=$1
    local service_name=$2
    local description=${3:-"$service_name"}
    
    log_debug "Checking service status: $description ($service_manager)"
    
    if is_service_running "$service_manager" "$service_name"; then
        log_success "Service is running: $description"
        return 0
    else
        log_error "Service is not running: $description"
        return 1
    fi
}

# Database connectivity check
check_database_connectivity() {
    local host=${1:-$DB_HOST}
    local port=${2:-$DB_PORT}
    local database=${3:-$DB_NAME}
    local user=${4:-$DB_USER}
    
    log_debug "Checking database connectivity: $user@$host:$port/$database"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would check database connectivity"
        return 0
    fi
    
    # Check if psql is available
    if ! command -v psql >/dev/null 2>&1; then
        log_warning "psql not available, skipping database connectivity check"
        return 0
    fi
    
    # Simple connectivity test
    if PGPASSWORD="$DB_PASSWORD" psql -h "$host" -p "$port" -U "$user" -d "$database" -c '\q' >/dev/null 2>&1; then
        log_success "Database is accessible"
        return 0
    else
        log_error "Database connectivity check failed"
        return 1
    fi
}

# Port availability check
check_port_availability() {
    local host=${1:-localhost}
    local port=$2
    local description=${3:-"$host:$port"}
    
    log_debug "Checking port availability: $description"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would check port $port on $host"
        return 0
    fi
    
    if nc -z "$host" "$port" 2>/dev/null; then
        log_debug "Port is available: $description"
        return 0
    else
        log_debug "Port is not available: $description"
        return 1
    fi
}

# Comprehensive frontend health check
comprehensive_frontend_check() {
    log_step "🎨 Comprehensive frontend health check..."
    
    local checks_passed=0
    local total_checks=0
    
    # Check service status
    ((total_checks++))
    if check_service_status "$FRONTEND_SERVICE_MANAGER" "$FRONTEND_SERVICE_NAME" "Frontend Service"; then
        ((checks_passed++))
    fi
    
    # Check port availability
    ((total_checks++))
    if check_port_availability "localhost" "$FRONTEND_PORT" "Frontend Port"; then
        ((checks_passed++))
    fi
    
    # Check HTTP endpoint
    ((total_checks++))
    if check_frontend_health; then
        ((checks_passed++))
    fi
    
    # Check if build directory exists and has content
    if [ -d "$FRONTEND_PROD_PATH/.next" ]; then
        ((total_checks++))
        local build_size
        build_size=$(du -sh "$FRONTEND_PROD_PATH/.next" 2>/dev/null | cut -f1 || echo "unknown")
        log_success "Build directory exists: $build_size"
        ((checks_passed++))
    fi
    
    log_info "Frontend health: $checks_passed/$total_checks checks passed"
    
    if [ $checks_passed -eq $total_checks ]; then
        return 0
    else
        return 1
    fi
}

# Comprehensive backend health check
comprehensive_backend_check() {
    log_step "🏭 Comprehensive backend health check..."
    
    local checks_passed=0
    local total_checks=0
    
    # Check service status
    ((total_checks++))
    if check_service_status "$BACKEND_SERVICE_MANAGER" "$BACKEND_SERVICE_NAME" "Backend Service"; then
        ((checks_passed++))
    fi
    
    # Check database connectivity
    ((total_checks++))
    if check_database_connectivity; then
        ((checks_passed++))
    fi
    
    # Check HTTP endpoint
    ((total_checks++))
    if check_backend_health; then
        ((checks_passed++))
    fi
    
    # Check static files
    if [ -d "$STATIC_FILES_PATH" ]; then
        ((total_checks++))
        local static_count
        static_count=$(find "$STATIC_FILES_PATH" -type f 2>/dev/null | wc -l || echo "0")
        if [ "$static_count" -gt 0 ]; then
            log_success "Static files available: $static_count files"
            ((checks_passed++))
        else
            log_warning "No static files found"
        fi
    fi
    
    log_info "Backend health: $checks_passed/$total_checks checks passed"
    
    if [ $checks_passed -eq $total_checks ]; then
        return 0
    else
        return 1
    fi
}

# Quick health check (just HTTP endpoints)
quick_health_check() {
    local component=${1:-"both"}
    
    log_step "⚡ Quick health check ($component)..."
    
    case $component in
        "frontend")
            check_frontend_health
            ;;
        "backend")
            check_backend_health
            ;;
        "both")
            local frontend_ok=false
            local backend_ok=false
            
            if check_frontend_health; then
                frontend_ok=true
            fi
            
            if check_backend_health; then
                backend_ok=true
            fi
            
            if [ "$frontend_ok" = true ] && [ "$backend_ok" = true ]; then
                log_success "Both frontend and backend are healthy"
                return 0
            else
                log_error "Health check failed - Frontend: $frontend_ok, Backend: $backend_ok"
                return 1
            fi
            ;;
        *)
            log_error "Unknown component for health check: $component"
            return 1
            ;;
    esac
}

# Health check with detailed output
detailed_health_check() {
    local component=${1:-"both"}
    
    log_step "🔍 Detailed health check ($component)..."
    
    case $component in
        "frontend")
            comprehensive_frontend_check
            ;;
        "backend")
            comprehensive_backend_check
            ;;
        "both")
            local frontend_result=0
            local backend_result=0
            
            comprehensive_frontend_check || frontend_result=1
            echo
            comprehensive_backend_check || backend_result=1
            
            if [ $frontend_result -eq 0 ] && [ $backend_result -eq 0 ]; then
                log_success "All health checks passed"
                return 0
            else
                log_error "Some health checks failed"
                return 1
            fi
            ;;
        *)
            log_error "Unknown component for health check: $component"
            return 1
            ;;
    esac
}

# Post-deployment verification
post_deployment_verification() {
    local component=$1
    local verification_level=${2:-"quick"}  # quick, detailed
    
    log_step "✅ Post-deployment verification ($component, $verification_level)..."
    
    # Wait a moment for services to fully start
    wait_for_service 3 "Waiting for services to fully initialize"
    
    case $verification_level in
        "quick")
            quick_health_check "$component"
            ;;
        "detailed")
            detailed_health_check "$component"
            ;;
        *)
            log_error "Unknown verification level: $verification_level"
            return 1
            ;;
    esac
}

# Show health status summary
show_health_summary() {
    echo
    log_step "📊 Health Status Summary"
    echo "========================"
    
    # Frontend status
    echo -n "Frontend: "
    if check_http_endpoint "$FRONTEND_URL$FRONTEND_HEALTH_ENDPOINT" 200 "$HEALTH_CHECK_TIMEOUT" "Frontend" 2>/dev/null; then
        echo -e "${GREEN}✅ Healthy${NC}"
    else
        echo -e "${RED}❌ Unhealthy${NC}"
    fi
    
    # Backend status
    echo -n "Backend:  "
    if check_http_endpoint "$BACKEND_URL$API_HEALTH_ENDPOINT" 200 "$HEALTH_CHECK_TIMEOUT" "Backend" 2>/dev/null; then
        echo -e "${GREEN}✅ Healthy${NC}"
    else
        echo -e "${RED}❌ Unhealthy${NC}"
    fi
    
    # Database status
    echo -n "Database: "
    if check_database_connectivity 2>/dev/null; then
        echo -e "${GREEN}✅ Connected${NC}"
    else
        echo -e "${RED}❌ Connection failed${NC}"
    fi
    
    echo
}