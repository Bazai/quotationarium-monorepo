#!/bin/bash
# Rollback script for quick recovery

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

COMPONENT="${1:-frontend}"
TIMESTAMP="${2}"

if [[ -z "$TIMESTAMP" ]]; then
    echo "❌ Error: Timestamp required"
    echo "Usage: $0 <component> <timestamp>"
    echo "Example: $0 frontend 1645123456"
    echo ""
    echo "Available backups:"
    cd "$ANSIBLE_DIR"
    ansible quotes-prod -m shell -a "find /opt/collector_backups -name '*.tar.gz' -printf '%f\n' | sort -r | head -10" --one-line | cut -d'|' -f3 | tail -n +2
    exit 1
fi

cd "$ANSIBLE_DIR"

echo "=== Rollback Operation ==="
echo "Component: $COMPONENT"
echo "Timestamp: $TIMESTAMP"
echo "Started at: $(date)"
echo ""

# Warning prompt
echo "⚠️  WARNING: This will rollback $COMPONENT to timestamp $TIMESTAMP"
echo "   Current version will be stopped and replaced"
echo ""
read -p "Are you sure? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rollback cancelled"
    exit 1
fi

echo ""
echo "🔄 Starting rollback..."

# Execute rollback
if ansible-playbook playbooks/rollback.yml \
    -e "rollback_component=$COMPONENT" \
    -e "rollback_timestamp=$TIMESTAMP" \
    -v; then
    
    echo ""
    echo "🎉 Rollback completed successfully!"
    echo ""
    echo "📊 Rollback Summary:"
    echo "   • Component: $COMPONENT"
    echo "   • Timestamp: $TIMESTAMP"
    echo "   • Status: SUCCESS"
    echo ""
    echo "✅ Next steps:"
    echo "   1. Verify application is working"
    echo "   2. Check service status"
    echo "   3. Review logs for any issues"
    echo ""
    
    case "$COMPONENT" in
        "frontend")
            echo "🔗 Frontend checks:"
            echo "   • PM2 status: pm2 status"
            echo "   • PM2 logs: pm2 logs collect_front"
            echo "   • Browser test: http://YOUR_SERVER:3000"
            ;;
        "backend")
            echo "🔗 Backend checks:"
            echo "   • Service status: systemctl status collector"
            echo "   • Service logs: journalctl -u collector -f"
            echo "   • API test: curl http://YOUR_SERVER:8000/api/"
            ;;
        "all")
            echo "🔗 Full stack checks:"
            echo "   • Backend: systemctl status collector"
            echo "   • Frontend: pm2 status"
            echo "   • Browser test: http://YOUR_SERVER:3000"
            ;;
    esac
    
else
    echo ""
    echo "❌ Rollback failed!"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   1. Check if backup files exist for timestamp $TIMESTAMP"
    echo "   2. Verify SSH connectivity"
    echo "   3. Check server logs"
    echo "   4. Try manual service restart"
    echo ""
    echo "📋 Manual recovery:"
    echo "   • Check backups: ansible quotes-prod -m find -a 'paths=/opt/collector_backups patterns=*.tar.gz'"
    echo "   • Manual service restart: ansible quotes-prod -m service -a 'name=collect_front state=restarted'"
    echo ""
    
    exit 1
fi