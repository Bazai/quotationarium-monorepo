#!/bin/bash
# Backend deployment script for Django application

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Backend Deployment Script ==="
echo "Starting deployment at $(date)"
echo ""

cd "$ANSIBLE_DIR"


# Step 1: Pre-deployment checks
echo "🔍 Running pre-deployment checks..."
if ./scripts/pre-deploy-check.sh backend; then
    echo "✅ Pre-deployment checks passed"
else
    echo "❌ Pre-deployment checks failed"
    exit 1
fi

echo ""

# Step 2: Create backup timestamp for potential rollback
TIMESTAMP=$(date +%s)
echo "📝 Deployment timestamp: $TIMESTAMP"
echo "   (Save this for rollback if needed)"

echo ""

# Step 3: Deploy
echo "🚀 Starting backend deployment..."
if ansible-playbook playbooks/deploy-backend.yml -v -e "deploy_timestamp=$TIMESTAMP"; then
    echo ""
    echo "🎉 Backend deployment completed successfully!"
    echo ""
    echo "📊 Deployment Summary:"
    echo "   • Timestamp: $TIMESTAMP"
    echo "   • Component: Backend (Django)"
    echo "   • Status: SUCCESS"
    echo ""
    echo "🔗 Access your application:"
    echo "   • Backend API: Check your server IP on port 8000"
    echo "   • Admin: http://your-server:8000/admin"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Test API endpoints in browser/Postman"
    echo "   2. Check service status: systemctl status collector"
    echo "   3. Monitor logs: journalctl -u collector -f"
    echo "   4. Check Django admin panel"
    echo ""
    echo "🔄 For rollback (if needed):"
    echo "   ./scripts/rollback.sh backend $TIMESTAMP"
    
else
    echo ""
    echo "❌ Backend deployment failed!"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   1. Check the error logs above"
    echo "   2. Verify database connectivity"
    echo "   3. Test SSH connectivity: ansible quotes-prod -m ping"
    echo "   4. Check Django logs: journalctl -u collector -n 50"
    echo ""
    echo "🆘 Common fixes:"
    echo "   • Database issues: Check connection settings"
    echo "   • Migration failures: Run migrations manually"
    echo "   • Static files: Run collectstatic manually"
    echo "   • Port conflicts: Check if port 8000 is available"
    echo ""
    
    exit 1
fi