#!/bin/bash
# Debug script for Railway deployment issues

echo "🔍 Railway Deployment Debug Script"
echo "=================================="

# Check if required files exist
echo "📁 Checking required files..."
FILES_TO_CHECK=(
  "Dockerfile.railway"
  "railway.json"
  "package.runtime.json"
  "data/nodes.db"
  "src/http-server-sse.ts"
  "src/mcp/server.ts"
  "docker/docker-entrypoint.sh"
)

for file in "${FILES_TO_CHECK[@]}"; do
  if [ -f "$file" ]; then
    echo "✅ $file exists"
  else
    echo "❌ $file missing"
  fi
done

echo ""
echo "🔧 Environment Variables for Railway:"
echo "MCP_MODE=http"
echo "USE_SSE=true"
echo "AUTH_TOKEN=WuME0GaBa34fyl75AfDx1o5hfUJQ2gKiMd/Qr2Vudzg="
echo "PORT=3000"
echo "NODE_ENV=production"
echo "LOG_LEVEL=info"
echo "N8N_API_URL=https://primary-production-fc906.up.railway.app"
echo "N8N_API_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

echo ""
echo "🐳 Testing Docker build locally..."
if command -v docker &> /dev/null; then
  echo "Building with Railway Dockerfile..."
  docker build -f Dockerfile.railway -t n8n-mcp-test . && \
  echo "✅ Docker build successful" || \
  echo "❌ Docker build failed"
  
  echo ""
  echo "🧪 Testing container locally..."
  echo "Starting container with test environment..."
  docker run --rm -d \
    --name n8n-mcp-test \
    -p 3001:3000 \
    -e MCP_MODE=http \
    -e USE_SSE=true \
    -e AUTH_TOKEN=test-token \
    -e PORT=3000 \
    -e NODE_ENV=production \
    -e LOG_LEVEL=info \
    n8n-mcp-test && \
  echo "✅ Container started on port 3001" || \
  echo "❌ Container failed to start"
  
  # Wait a bit for startup
  sleep 5
  
  # Test health endpoint
  echo ""
  echo "🏥 Testing health endpoint..."
  curl -s http://localhost:3001/health | jq '.' 2>/dev/null || \
  curl -s http://localhost:3001/health || \
  echo "❌ Health check failed"
  
  # Clean up
  docker stop n8n-mcp-test 2>/dev/null || true
  docker rm n8n-mcp-test 2>/dev/null || true
else
  echo "❌ Docker not found, skipping container test"
fi

echo ""
echo "📋 Railway Deployment Checklist:"
echo "1. ✅ Fork the repository to your GitHub account"
echo "2. ✅ Push changes to your fork"
echo "3. 🔄 Create new Railway service from GitHub repo"
echo "4. 🔄 Set environment variables in Railway"
echo "5. 🔄 Deploy and check logs"

echo ""
echo "🚀 Next steps:"
echo "1. Go to Railway dashboard"
echo "2. Create new service -> Deploy from GitHub repo"
echo "3. Select your fork: tirones-123/n8n-mcp"
echo "4. Railway will use Dockerfile.railway automatically"
echo "5. Set the environment variables listed above"
echo "6. Deploy and monitor logs"

echo ""
echo "📊 Railway will use:"
echo "- Dockerfile: Dockerfile.railway"
echo "- Config: railway.json"
echo "- Health check: /health"
echo "- Port: 3000 (Railway PORT env var)" 