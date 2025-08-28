#!/bin/bash
# Simplified frontend deployment script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Frontend Deployment Script ==="
echo "Starting deployment at $(date)"
echo ""

cd "$ANSIBLE_DIR"


# Step 1: Pre-deployment checks
echo "🔍 Running pre-deployment checks..."
if ./scripts/pre-deploy-check.sh frontend; then
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
echo "🚀 Starting frontend deployment..."
if ansible-playbook playbooks/deploy-frontend.yml -v -e "deploy_timestamp=$TIMESTAMP"; then
    echo ""
    echo "🎉 Frontend deployment completed successfully!"
    echo ""
    echo "📊 Deployment Summary:"
    echo "   • Timestamp: $TIMESTAMP"
    echo "   • Component: Frontend (Next.js)"
    echo "   • Status: SUCCESS"
    echo ""
    echo "🔗 Access your application:"
    echo "   • Frontend: Check your server IP on port 3000"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Test the application in browser"
    echo "   2. Check PM2 status: pm2 status"
    echo "   3. Monitor logs: pm2 logs collect_front"
    echo ""
    echo "🔄 For rollback (if needed):"
    echo "   ./scripts/rollback.sh frontend $TIMESTAMP"
    
else
    echo ""
    echo "❌ Frontend deployment failed!"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   1. Check the error logs above"
    echo "   2. Verify server requirements"
    echo "   3. Test SSH connectivity: ansible quotes-prod -m ping"
    echo "   4. Check server logs: pm2 logs collect_front"
    echo ""
    echo "🆘 Common fixes:"
    echo "   • Memory issues: Add swap space"
    echo "   • Permission issues: Check user permissions"
    echo "   • Port conflicts: Stop existing services"
    echo ""
    
    exit 1
fi