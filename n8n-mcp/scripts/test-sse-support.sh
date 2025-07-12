#!/bin/bash
# Test SSE support for n8n-MCP server

SERVER_URL=${1:-"https://n8n-mcp-production.up.railway.app"}
AUTH_TOKEN=${2:-"your-auth-token"}

echo "🔍 Testing SSE support on $SERVER_URL"
echo ""

# Test 1: Health check
echo "1️⃣ Health Check:"
curl -s "$SERVER_URL/health" | jq '.'
echo ""

# Test 2: Basic MCP request
echo "2️⃣ Basic MCP Request (JSON-RPC):"
curl -s -X POST "$SERVER_URL/mcp" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | jq '.'
echo ""

# Test 3: SSE connection
echo "3️⃣ SSE Connection Test:"
echo "Attempting SSE connection (Ctrl+C to stop)..."
curl -N \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Accept: text/event-stream" \
  -H "Cache-Control: no-cache" \
  "$SERVER_URL/mcp" \
  --max-time 5 \
  -w "\nHTTP Status: %{http_code}\n"
echo ""

# Test 4: Tools list
echo "4️⃣ Tools List:"
curl -s -X POST "$SERVER_URL/mcp" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' | jq '.result.tools | length'
echo " tools available"
echo ""

# Test 5: Execute a tool
echo "5️⃣ Execute Tool (get_database_statistics):"
curl -s -X POST "$SERVER_URL/mcp" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "method":"tools/call",
    "params":{
      "name":"get_database_statistics",
      "arguments":{}
    },
    "id":3
  }' | jq '.result.content[0].text' | jq -r '.' | jq '.' 