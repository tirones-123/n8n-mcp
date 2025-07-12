#!/bin/bash
# Test SSE support for n8n-MCP server

SERVER_URL=${1:-"https://n8n-mcp-production.up.railway.app"}
AUTH_TOKEN=${2:-"WuME0GaBa34fyl75AfDx1o5hfUJQ2gKiMd/Qr2Vudzg="}

echo "🔍 Testing SSE support on $SERVER_URL"
echo "🔑 Using auth token: ${AUTH_TOKEN:0:20}..."
echo ""

# Test 1: Health check
echo "1️⃣ Health Check:"
curl -s "$SERVER_URL/health" | jq '.' 2>/dev/null || curl -s "$SERVER_URL/health"
echo ""

# Test 2: Basic MCP request
echo "2️⃣ Basic MCP Request (JSON-RPC):"
curl -s -X POST "$SERVER_URL/mcp" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}' | jq '.' 2>/dev/null || \
curl -s -X POST "$SERVER_URL/mcp" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{},"id":1}'
echo ""

# Test 3: SSE connection (/mcp endpoint)
echo "3️⃣ SSE Connection Test (/mcp):"
echo "Attempting SSE connection (5 seconds timeout)..."
timeout 5 curl -N \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Accept: text/event-stream" \
  -H "Cache-Control: no-cache" \
  "$SERVER_URL/mcp" \
  -w "\nHTTP Status: %{http_code}\n" 2>/dev/null || echo "SSE connection failed or timed out"
echo ""

# Test 3b: SSE connection (/sse endpoint)
echo "3️⃣b SSE Connection Test (/sse):"
echo "Attempting SSE connection (5 seconds timeout)..."
timeout 5 curl -N \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Accept: text/event-stream" \
  -H "Cache-Control: no-cache" \
  "$SERVER_URL/sse" \
  -w "\nHTTP Status: %{http_code}\n" 2>/dev/null || echo "SSE connection failed or timed out"
echo ""

# Test 4: Tools list
echo "4️⃣ Tools List:"
TOOLS_COUNT=$(curl -s -X POST "$SERVER_URL/mcp" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}' | jq '.result.tools | length' 2>/dev/null)

if [ "$TOOLS_COUNT" != "null" ] && [ "$TOOLS_COUNT" != "" ]; then
  echo "✅ $TOOLS_COUNT tools available"
else
  echo "❌ Failed to get tools list"
fi
echo ""

# Test 5: Execute a tool
echo "5️⃣ Execute Tool (get_database_statistics):"
STATS=$(curl -s -X POST "$SERVER_URL/mcp" \
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
  }' | jq '.result.content[0].text' 2>/dev/null)

if [ "$STATS" != "null" ] && [ "$STATS" != "" ]; then
  echo "✅ Tool executed successfully"
  echo "$STATS" | jq -r '.' 2>/dev/null | jq '.' 2>/dev/null || echo "$STATS"
else
  echo "❌ Failed to execute tool"
fi
echo ""

# Test 6: Test with Claude API format (/mcp)
echo "6️⃣ Claude API Compatibility Test (/mcp):"
curl -s -X POST "$SERVER_URL/mcp" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Claude-API/1.0" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":"claude-test"}' | jq '.result.tools | length' 2>/dev/null && \
echo "✅ Claude API format compatible (/mcp)" || echo "❌ Claude API format failed (/mcp)"
echo ""

# Test 6b: Test with Claude API format (/sse)
echo "6️⃣b Claude API Compatibility Test (/sse):"
curl -s -X POST "$SERVER_URL/sse" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Claude-API/1.0" \
  -d '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":"claude-test"}' | jq '.result.tools | length' 2>/dev/null && \
echo "✅ Claude API format compatible (/sse)" || echo "❌ Claude API format failed (/sse)"
echo ""

echo "🎯 Test Summary:"
echo "   - Health check: Basic server status"
echo "   - JSON-RPC: Standard MCP communication"
echo "   - SSE: Server-Sent Events for Claude API"
echo "   - Tools: Available MCP tools"
echo "   - Execution: Tool execution capability"
echo "   - Claude API: Compatibility with Anthropic's format"
echo ""
echo "💡 If SSE connection works, your server is ready for Claude API!" 