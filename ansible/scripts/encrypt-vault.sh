#!/bin/bash
# Script to encrypt Ansible Vault files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Encrypting Ansible Vault files ==="

# Check if vault password file exists
if [[ ! -f "$ANSIBLE_DIR/.ansible-vault-password" ]]; then
    echo "Error: Vault password file not found at $ANSIBLE_DIR/.ansible-vault-password"
    echo "Please create this file with your vault password first."
    exit 1
fi

# Encrypt vault.yml if it exists and is not already encrypted
if [[ -f "$ANSIBLE_DIR/group_vars/all/vault.yml" ]]; then
    if ! grep -q "ANSIBLE_VAULT" "$ANSIBLE_DIR/group_vars/all/vault.yml"; then
        echo "Encrypting group_vars/all/vault.yml..."
        ansible-vault encrypt "$ANSIBLE_DIR/group_vars/all/vault.yml"
        echo "✓ vault.yml encrypted successfully"
    else
        echo "• vault.yml is already encrypted"
    fi
else
    echo "• vault.yml not found, skipping"
fi

# Set proper permissions on vault password file
chmod 600 "$ANSIBLE_DIR/.ansible-vault-password"
echo "✓ Set secure permissions on vault password file"

echo ""
echo "=== Encryption Complete ==="
echo "Remember to:"
echo "1. Never commit .ansible-vault-password to version control"
echo "2. Share vault password securely with team members"
echo "3. Use 'ansible-vault edit' to modify encrypted files"