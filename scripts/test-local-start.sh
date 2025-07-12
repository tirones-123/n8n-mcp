#!/bin/bash
# Test local server startup

echo "🧪 Testing local server startup..."

# Set required environment variables
export MCP_MODE=http
export USE_SSE=true
export AUTH_TOKEN=test-token-123
export PORT=3001
export NODE_ENV=development
export LOG_LEVEL=debug

echo "📋 Environment:"
echo "  MCP_MODE: $MCP_MODE"
echo "  USE_SSE: $USE_SSE"
echo "  AUTH_TOKEN: $AUTH_TOKEN"
echo "  PORT: $PORT"

# Check if files exist
echo ""
echo "📁 Checking files..."
if [ -f "dist/mcp/index.js" ]; then
    echo "✅ dist/mcp/index.js exists"
else
    echo "❌ dist/mcp/index.js missing - run npm run build first"
    exit 1
fi

if [ -f "data/nodes.db" ]; then
    echo "✅ data/nodes.db exists"
else
    echo "❌ data/nodes.db missing - run npm run rebuild first"
    exit 1
fi

# Start server
echo ""
echo "🚀 Starting server..."
echo "Press Ctrl+C to stop"
echo ""

node dist/mcp/index.js 