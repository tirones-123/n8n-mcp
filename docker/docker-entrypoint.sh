#!/bin/sh
set -e

# Environment variable validation
if [ "$MCP_MODE" = "http" ] && [ -z "$AUTH_TOKEN" ] && [ -z "$AUTH_TOKEN_FILE" ]; then
    echo "ERROR: AUTH_TOKEN or AUTH_TOKEN_FILE is required for HTTP mode"
    exit 1
fi

# Validate AUTH_TOKEN_FILE if provided
if [ -n "$AUTH_TOKEN_FILE" ] && [ ! -f "$AUTH_TOKEN_FILE" ]; then
    echo "ERROR: AUTH_TOKEN_FILE specified but file not found: $AUTH_TOKEN_FILE"
    exit 1
fi

# Database check - should already be present from Docker build
if [ ! -f "/app/data/nodes.db" ]; then
    echo "ERROR: Database not found. This should not happen in production." >&2
    echo "The database should be copied during Docker build." >&2
    exit 1
fi

# Fix permissions if running as root (for development)
if [ "$(id -u)" = "0" ]; then
    echo "Running as root, fixing permissions..."
    chown -R nodejs:nodejs /app/data
    # Switch to nodejs user (using Alpine's native su)
    exec su nodejs -c "$*"
fi

# Trap signals for graceful shutdown
# In stdio mode, don't output anything to stdout as it breaks JSON-RPC
if [ "$MCP_MODE" = "stdio" ]; then
    # Silent trap - no output at all
    trap 'kill -TERM $PID 2>/dev/null || true' TERM INT EXIT
else
    # In HTTP mode, output to stderr
    trap 'echo "Shutting down..." >&2; kill -TERM $PID 2>/dev/null' TERM INT EXIT
fi

# Execute the main command in background
# In stdio mode, use the wrapper for clean output
if [ "$MCP_MODE" = "stdio" ]; then
    # Debug: Log to stderr to check if wrapper exists
    if [ "$DEBUG_DOCKER" = "true" ]; then
        echo "MCP_MODE is stdio, checking for wrapper..." >&2
        ls -la /app/dist/mcp/stdio-wrapper.js >&2 || echo "Wrapper not found!" >&2
    fi
    
    if [ -f "/app/dist/mcp/stdio-wrapper.js" ]; then
        # Use the stdio wrapper for clean JSON-RPC output
        exec node /app/dist/mcp/stdio-wrapper.js
    else
        # Fallback: run with explicit environment
        exec env MCP_MODE=stdio DISABLE_CONSOLE_OUTPUT=true LOG_LEVEL=error node /app/dist/mcp/index.js
    fi
else
    # HTTP mode or other - directly run the main command
    echo "Starting in HTTP mode..."
    echo "Environment: MCP_MODE=$MCP_MODE, USE_SSE=$USE_SSE, PORT=$PORT"
    echo "Files check:"
    ls -la /app/dist/mcp/index.js || echo "index.js not found!"
    ls -la /app/data/nodes.db || echo "nodes.db not found!"
    echo "Executing: node /app/dist/mcp/index.js"
    exec node /app/dist/mcp/index.js
fi