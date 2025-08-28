#!/bin/bash
# =============================================================================
# LOCAL ANSIBLE DEPLOYMENT SCRIPT
# =============================================================================
# This script allows you to deploy from your local machine using Ansible
# Usage: ./scripts/ansible-deploy.sh [options]
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Default values
DEPLOY_VERSION="main"
ANSIBLE_HOST=""
INVENTORY="production"
PLAYBOOK="deploy"
VERBOSE=""
DRY_RUN=""
SKIP_TESTS="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Help function
show_help() {
    cat << EOF
Ansible Deployment Script for Quotes Application

Usage: $0 [options]

Options:
  --host HOST           Production server IP/hostname
  --version VERSION     Git branch/tag/commit to deploy (default: main)
  --inventory INVENTORY Ansible inventory to use (default: production)  
  --playbook PLAYBOOK   Playbook to run (deploy, rollback) (default: deploy)
  --skip-tests          Skip running tests
  --verbose, -v         Verbose Ansible output
  --dry-run            Show what would be done without executing
  --help, -h           Show this help

Examples:
  $0 --host 192.168.1.100                    # Deploy main branch
  $0 --host example.com --version v2.1.0     # Deploy specific version
  $0 --host example.com --playbook rollback  # Rollback deployment
  $0 --host example.com --dry-run            # Show deployment plan

Environment Variables:
  ANSIBLE_HOST         Production server (can be used instead of --host)
  SSH_PRIVATE_KEY      Path to SSH private key
  ANSIBLE_VERBOSE      Enable verbose output

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            ANSIBLE_HOST="$2"
            shift 2
            ;;
        --version)
            DEPLOY_VERSION="$2"
            shift 2
            ;;
        --inventory)
            INVENTORY="$2"
            shift 2
            ;;
        --playbook)
            PLAYBOOK="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS="true"
            shift
            ;;
        --verbose|-v)
            VERBOSE="-v"
            shift
            ;;
        --dry-run)
            DRY_RUN="--check"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    log_error "Ansible is not installed. Please install it first:"
    echo "  pip install ansible"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "$ANSIBLE_DIR/ansible.cfg" ]; then
    log_error "ansible.cfg not found. Please run this script from the project root."
    exit 1
fi

# Validate required parameters
if [ -z "$ANSIBLE_HOST" ]; then
    log_error "Host is required. Use --host option or set ANSIBLE_HOST environment variable."
    exit 1
fi

# Change to ansible directory
cd "$ANSIBLE_DIR"

log_info "Starting Ansible deployment..."
echo "=============================================="
echo "Host:        $ANSIBLE_HOST"  
echo "Version:     $DEPLOY_VERSION"
echo "Inventory:   $INVENTORY"
echo "Playbook:    $PLAYBOOK"
echo "Skip Tests:  $SKIP_TESTS"
echo "Dry Run:     ${DRY_RUN:-false}"
echo "=============================================="

# Build ansible-playbook command
ANSIBLE_CMD="ansible-playbook -i inventory/${INVENTORY}.yml playbooks/${PLAYBOOK}.yml"
ANSIBLE_CMD="$ANSIBLE_CMD --extra-vars \"ansible_host=$ANSIBLE_HOST\""
ANSIBLE_CMD="$ANSIBLE_CMD --extra-vars \"deploy_version=$DEPLOY_VERSION\""
ANSIBLE_CMD="$ANSIBLE_CMD --extra-vars \"skip_tests=$SKIP_TESTS\""

if [ -n "$VERBOSE" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD $VERBOSE"
fi

if [ -n "$DRY_RUN" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD $DRY_RUN"
    log_warning "DRY RUN MODE - No changes will be made"
fi

# Set environment variables
export ANSIBLE_HOST_KEY_CHECKING=False

# Run the deployment
log_info "Executing: $ANSIBLE_CMD"
eval $ANSIBLE_CMD

if [ $? -eq 0 ]; then
    log_success "Deployment completed successfully!"
    if [ "$PLAYBOOK" = "deploy" ]; then
        echo ""
        echo "🌍 Your application should be available at: https://expo.timuroki.ink"
        echo "🔍 Check status with: $0 --host $ANSIBLE_HOST --playbook deploy --tags health-check"
    fi
else
    log_error "Deployment failed!"
    echo ""
    echo "🔄 You can rollback with: $0 --host $ANSIBLE_HOST --playbook rollback"
    exit 1
fi