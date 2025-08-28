#!/bin/bash
# Pre-deployment validation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENT="${1:-frontend}"  # Default to frontend
TARGET="${2:-quotes-prod}"

echo "=== Pre-deployment Validation ==="
echo "Component: $COMPONENT"
echo "Target: $TARGET"
echo ""
echo "⚠️  REMINDER: Ensure you can SSH to server and git works on server:"
echo "   ssh $TARGET  # should work without password"
echo "   On server: git clone should work with deploy key"
echo ""

# Check if we're in the right directory
if [[ ! -f "$ANSIBLE_DIR/ansible.cfg" ]]; then
    echo "❌ Error: ansible.cfg not found. Are you in the right directory?"
    exit 1
fi

cd "$ANSIBLE_DIR"

# Check Ansible installation
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Error: ansible-playbook not found. Please install Ansible."
    exit 1
fi
echo "✅ Ansible installed: $(ansible --version | head -n1)"

# Check inventory file
if [[ ! -f "inventory/production.yml" ]]; then
    echo "❌ Error: inventory/production.yml not found."
    exit 1
fi
echo "✅ Inventory file exists"

# Check vault password file
if [[ ! -f ".ansible-vault-password" ]]; then
    echo "❌ Error: .ansible-vault-password not found."
    echo "   Create this file with your vault password."
    exit 1
fi
echo "✅ Vault password file exists"

# Check if vault.yml is encrypted
if [[ -f "group_vars/all/vault.yml" ]]; then
    if grep -q "ANSIBLE_VAULT" "group_vars/all/vault.yml"; then
        echo "✅ Vault file is encrypted"
    else
        echo "⚠️  Warning: vault.yml is not encrypted. Run ./scripts/encrypt-vault.sh"
    fi
else
    echo "❌ Error: group_vars/all/vault.yml not found."
    exit 1
fi

# Check SSH configuration
echo ""
echo "--- Checking SSH to server ---"

# Test SSH connectivity
echo ""
echo "--- Testing SSH connectivity ---"
if ansible "$TARGET" -m ping > /dev/null 2>&1; then
    echo "✅ SSH connectivity to $TARGET: OK"
else
    echo "❌ Error: Cannot connect to $TARGET via SSH"
    echo "   Troubleshooting steps:"
    echo "   1. Check inventory/production.yml configuration (ansible_host, ansible_user, ansible_ssh_private_key_file)"
    echo "   2. Test direct SSH: ssh user@host"
    echo "   3. Copy your SSH key: ssh-copy-id user@host"
    echo "   4. Check SSH key permissions: chmod 600 ~/.ssh/id_rsa"
    exit 1
fi

# Check server requirements
echo ""
echo "--- Checking server requirements ---"

# Check Node.js version (for frontend)
if [[ "$COMPONENT" == "frontend" || "$COMPONENT" == "all" ]]; then
    # Check for Node.js with NVM support
    NODE_CHECK=$(ansible "$TARGET" -m shell -a "source ~/.bashrc 2>/dev/null; source ~/.profile 2>/dev/null; node --version 2>/dev/null || which node 2>/dev/null || find /root -name node -type f 2>/dev/null | head -1" -o 2>/dev/null)
    
    if echo "$NODE_CHECK" | grep -q "node"; then
        # Extract version from path or direct version output
        NODE_VERSION=$(echo "$NODE_CHECK" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [[ -z "$NODE_VERSION" ]] && echo "$NODE_CHECK" | grep -q "/node"; then
            # If we found node binary path, get version from it
            NODE_PATH=$(echo "$NODE_CHECK" | grep "/node" | head -1)
            NODE_VERSION=$(ansible "$TARGET" -m shell -a "$NODE_PATH --version 2>/dev/null" -o | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 2>/dev/null)
        fi
        
        if [[ -n "$NODE_VERSION" ]]; then
            # Check version requirement
            VERSION_NUM=$(echo "$NODE_VERSION" | sed 's/v//')
            if [[ "$VERSION_NUM" < "18.0.0" ]]; then
                echo "❌ Error: Node.js version $NODE_VERSION is too old (required: >= 18.0.0)"
                exit 1
            else
                echo "✅ Node.js version: $NODE_VERSION (found via NVM)"
            fi
        else
            echo "✅ Node.js found but version detection failed - continuing..."
        fi
    else
        echo "❌ Error: Node.js not found on target server"
        echo "   Node.js should be installed via NVM or system package manager"
        exit 1
    fi

    # Check PM2 (also via NVM like Node.js)
    PM2_CHECK=$(ansible "$TARGET" -m shell -a "source ~/.bashrc 2>/dev/null; source ~/.profile 2>/dev/null; pm2 --version 2>/dev/null || which pm2 2>/dev/null || find /root -name pm2 -type f 2>/dev/null | head -1" -o 2>/dev/null)
    
    if echo "$PM2_CHECK" | grep -q "pm2"; then
        # Extract version from output or try to get version from found pm2 path
        PM2_VERSION=$(echo "$PM2_CHECK" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [[ -z "$PM2_VERSION" ]] && echo "$PM2_CHECK" | grep -q "/pm2"; then
            # If we found pm2 binary path, get version with NVM environment
            PM2_VERSION=$(ansible "$TARGET" -m shell -a "source ~/.bashrc 2>/dev/null; source ~/.profile 2>/dev/null; pm2 --version 2>/dev/null" -o | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 2>/dev/null)
        fi
        
        if [[ -n "$PM2_VERSION" ]]; then
            echo "✅ PM2 version: $PM2_VERSION (found via NVM)"
        else
            echo "✅ PM2 found but version detection failed - continuing..."
        fi
    else
        echo "❌ Error: PM2 not found on target server"
        echo "   PM2 should be installed globally: npm install -g pm2"
        exit 1
    fi
fi

# Check Python version (for backend)
if [[ "$COMPONENT" == "backend" || "$COMPONENT" == "all" ]]; then
    PYTHON_VERSION=$(ansible "$TARGET" -m shell -a "python3 --version 2>/dev/null || echo 'not installed'" -o | grep -oE 'Python [0-9]+\.[0-9]+\.[0-9]+' || echo 'not installed')
    if [[ "$PYTHON_VERSION" == "not installed" ]]; then
        echo "❌ Error: Python3 not installed on target server"
        exit 1
    else
        echo "✅ Python version: $PYTHON_VERSION"
    fi
fi

# Check memory
MEMORY=$(ansible "$TARGET" -m shell -a "free -m | grep '^Mem:' | awk '{print \$2}'" -o | grep -oE '[0-9]+' | tail -1)
if [[ "$MEMORY" -lt 512 ]]; then
    echo "⚠️  Warning: Low memory detected: ${MEMORY}MB (recommended: >= 1024MB)"
    echo "   Consider adding swap space if deployment fails"
else
    echo "✅ Memory: ${MEMORY}MB"
fi

# Check disk space
DISK_AVAIL=$(ansible "$TARGET" -m shell -a "df -BG / | tail -1 | awk '{print \$4}' | sed 's/G//'" -o | grep -oE '[0-9]+' | tail -1)
if [[ "$DISK_AVAIL" -lt 2 ]]; then
    echo "❌ Error: Insufficient disk space: ${DISK_AVAIL}GB (required: >= 2GB)"
    exit 1
else
    echo "✅ Disk space available: ${DISK_AVAIL}GB"
fi

# Check playbook syntax
echo ""
echo "--- Validating playbook syntax ---"
case "$COMPONENT" in
    "frontend")
        PLAYBOOK="playbooks/deploy-frontend.yml"
        ;;
    "backend")
        PLAYBOOK="playbooks/deploy-backend.yml"
        ;;
    "all")
        PLAYBOOK="playbooks/deploy.yml"
        ;;
    *)
        echo "❌ Error: Unknown component '$COMPONENT'. Use: frontend, backend, or all"
        exit 1
        ;;
esac

if ansible-playbook "$PLAYBOOK" --syntax-check > /dev/null 2>&1; then
    echo "✅ Playbook syntax: OK"
else
    echo "❌ Error: Playbook syntax check failed"
    exit 1
fi

# Fix git ownership issue before dry run
echo ""
echo "--- Fixing git ownership for dry run ---"
ansible "$TARGET" -m shell -a "if [ -d /opt/collector_monorepo ]; then chown -R root:root /opt/collector_monorepo; fi; git config --global --add safe.directory /opt/collector_monorepo || true" --become > /dev/null 2>&1 || true

# Dry run
echo ""
echo "--- Performing dry run ---"
if ansible-playbook "$PLAYBOOK" --check --diff > /tmp/ansible-check.log 2>&1; then
    echo "✅ Dry run: OK"
else
    echo "❌ Error: Dry run failed. Check /tmp/ansible-check.log for details"
    echo "Last few lines:"
    tail -n 10 /tmp/ansible-check.log
    exit 1
fi

echo ""
echo "🎉 All pre-deployment checks passed!"
echo ""
echo "Ready to deploy with:"
echo "  ansible-playbook $PLAYBOOK -v"
echo ""
echo "Or for rollback testing:"
echo "  ansible-playbook playbooks/rollback.yml -e rollback_component=$COMPONENT -e rollback_timestamp=TIMESTAMP"