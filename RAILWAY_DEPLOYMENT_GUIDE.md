# 🚀 Railway Deployment Guide for n8n-MCP

## 📋 Overview

This guide will help you deploy the n8n-MCP server on Railway with full SSE support for Claude API integration.

## 🛠️ Prerequisites

- [x] Fork of this repository on your GitHub account
- [x] Railway account (free tier works)
- [x] n8n instance running (for optional management tools)

## 🚀 Step-by-Step Deployment

### 1. **Create Railway Service**

1. Go to [Railway](https://railway.app)
2. Click **"New Project"**
3. Select **"Deploy from GitHub repo"**
4. Choose your fork: `your-username/n8n-mcp`
5. Railway will automatically detect `Dockerfile.railway`

### 2. **Configure Environment Variables**

In Railway dashboard, add these variables:

```bash
# Required Variables
MCP_MODE=http
USE_SSE=true
AUTH_TOKEN=your-secure-token-here
PORT=3000
NODE_ENV=production
LOG_LEVEL=info

# Optional: n8n API Integration
N8N_API_URL=https://your-n8n-instance.com
N8N_API_KEY=your-n8n-api-key
```

**Generate a secure AUTH_TOKEN:**
```bash
openssl rand -base64 32
```

### 3. **Deploy and Monitor**

1. Railway will automatically deploy after setting variables
2. Monitor the **Deploy Logs** tab
3. Look for `SERVER_READY` message
4. Check the **Health Check** passes

### 4. **Get Your Service URL**

Railway will provide a URL like:
```
https://your-service-name.up.railway.app
```

## 🧪 Testing Your Deployment

### Quick Health Check

```bash
curl https://your-service-name.up.railway.app/health
```

Expected response:
```json
{
  "status": "ok",
  "mode": "http-sse",
  "version": "2.7.13",
  "transport": "Custom SSE Implementation",
  "capabilities": ["http", "sse", "json-rpc"],
  "auth": "Bearer token required"
}
```

### Full Test Suite

```bash
# Clone your repo locally
git clone https://github.com/your-username/n8n-mcp.git
cd n8n-mcp

# Run comprehensive tests
./scripts/test-sse-support.sh https://your-service-name.up.railway.app your-auth-token
```

## 🔧 Configuration for Claude API

Once deployed, configure your backend to use the MCP server:

```typescript
const response = await anthropic.messages.create({
  model: "claude-3-5-sonnet-20241022",
  max_tokens: 8192,
  messages: [
    {
      role: "user",
      content: "List available n8n workflow automation nodes"
    }
  ],
  mcp_servers: [
    {
      type: "url",
      url: "https://your-service-name.up.railway.app/mcp",
      name: "n8n-mcp",
      authorization_token: "your-auth-token"
    }
  ]
});
```

## 🐛 Troubleshooting

### Health Check Fails

1. **Check Deploy Logs** for error messages
2. **Verify Environment Variables** are set correctly
3. **Check Database** - ensure `data/nodes.db` exists in build

### SSE Connection Issues

1. **Test SSE endpoint** directly:
   ```bash
   curl -N -H "Authorization: Bearer your-token" \
        -H "Accept: text/event-stream" \
        https://your-service-name.up.railway.app/mcp
   ```

2. **Check CORS headers** in response

### Authentication Errors

1. **Verify AUTH_TOKEN** is set correctly
2. **Check token format** - no extra spaces or characters
3. **Test with curl**:
   ```bash
   curl -X POST https://your-service-name.up.railway.app/mcp \
     -H "Authorization: Bearer your-token" \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'
   ```

## 📊 Expected Results

### Successful Deployment Should Show:

- ✅ **Build**: Docker build completes successfully
- ✅ **Health Check**: `/health` endpoint responds
- ✅ **Tools**: 22+ tools available (39+ with n8n API)
- ✅ **SSE**: Server-Sent Events working
- ✅ **Authentication**: Bearer token validation working

### Deploy Logs Should Include:

```
Starting in HTTP mode...
Environment: MCP_MODE=http, USE_SSE=true, PORT=3000
Files check:
-rw-r--r--    1 nodejs   nodejs        xxxx /app/dist/mcp/index.js
-rw-r--r--    1 nodejs   nodejs     xxxxxxx /app/data/nodes.db
Executing: node /app/dist/mcp/index.js
Starting n8n Documentation MCP Server in http mode...
🚀 n8n MCP SSE-enabled HTTP Server running on 0.0.0.0:3000
📊 Health check: http://localhost:3000/health
🔌 MCP endpoint: http://localhost:3000/mcp
✨ Supports: HTTP JSON-RPC and Server-Sent Events (SSE)
🔐 Authentication: Bearer token required
🎯 Optimized for Claude API MCP connector
SERVER_READY
```

## 🔄 Updating Your Deployment

To update your deployment:

1. **Make changes** to your code
2. **Commit and push** to your GitHub repo
3. **Railway auto-deploys** from your main branch
4. **Monitor logs** for successful deployment

## 📝 Key Features

- **SSE Support**: Full Server-Sent Events for Claude API
- **Authentication**: Bearer token security
- **CORS**: Configured for cross-origin requests
- **Health Checks**: Built-in monitoring
- **39+ Tools**: Complete n8n node documentation and management
- **Auto-scaling**: Railway handles scaling automatically

## 🎯 Next Steps

1. **Test with Claude API** - Use your deployed URL
2. **Monitor usage** - Check Railway metrics
3. **Scale if needed** - Railway handles this automatically
4. **Update regularly** - Keep your fork updated

## 📞 Support

If you encounter issues:

1. Check the **Deploy Logs** in Railway
2. Run local tests with `./scripts/test-local-start.sh`
3. Use the debug script: `./scripts/debug-railway.sh`
4. Test SSE support: `./scripts/test-sse-support.sh`

Your n8n-MCP server is now ready for Claude API integration! 🎉 