#!/usr/bin/env node
/**
 * SSE-enabled HTTP server for n8n-MCP that supports Claude API MCP connector
 * Supports both regular HTTP JSON-RPC and Server-Sent Events (SSE)
 */
import express from 'express';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { N8NDocumentationMCPServer } from './mcp/server';
import { logger } from './utils/logger';
import { PROJECT_VERSION } from './utils/version';
import { loadAuthToken } from './http-server';
import dotenv from 'dotenv';

dotenv.config();

let authToken: string | null = null;

export async function startSSEHTTPServer() {
  // Load auth token
  authToken = loadAuthToken();
  if (!authToken || authToken.trim() === '') {
    console.error('ERROR: AUTH_TOKEN is required for HTTP mode');
    process.exit(1);
  }
  authToken = authToken.trim();

  const app = express();
  
  // Trust proxy configuration
  const trustProxy = process.env.TRUST_PROXY ? Number(process.env.TRUST_PROXY) : 0;
  if (trustProxy > 0) {
    app.set('trust proxy', trustProxy);
  }

  // CORS for Claude API
  app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    
    if (req.method === 'OPTIONS') {
      res.sendStatus(204);
      return;
    }
    next();
  });

  // Create MCP server and transport
  const mcpServer = new N8NDocumentationMCPServer();
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: () => `session-${Date.now()}`
  });

  // Connect server to transport
  await mcpServer.connect(transport);
  logger.info('MCP Server connected with SSE transport');

  // Health check
  app.get('/health', (req, res) => {
    res.json({ 
      status: 'ok',
      mode: 'http-sse',
      version: PROJECT_VERSION,
      transport: 'StreamableHTTPServerTransport',
      capabilities: ['http', 'sse']
    });
  });

  // Main MCP endpoint with authentication
  app.use('/mcp', (req, res, next) => {
    // Check authentication
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ 
        jsonrpc: '2.0',
        error: {
          code: -32001,
          message: 'Unauthorized'
        },
        id: null
      });
      return;
    }
    
    const token = authHeader.slice(7).trim();
    if (token !== authToken) {
      res.status(401).json({ 
        jsonrpc: '2.0',
        error: {
          code: -32001,
          message: 'Unauthorized'
        },
        id: null
      });
      return;
    }

    // Pass to transport
    transport.handleRequest(req, res);
  });

  const port = parseInt(process.env.PORT || '3000');
  const host = process.env.HOST || '0.0.0.0';
  
  app.listen(port, host, () => {
    console.log(`n8n MCP SSE-enabled HTTP Server running on ${host}:${port}`);
    console.log(`Health check: http://localhost:${port}/health`);
    console.log(`MCP endpoint: http://localhost:${port}/mcp`);
    console.log('Supports: HTTP JSON-RPC and Server-Sent Events (SSE)');
  });
}

// Start if called directly
if (require.main === module) {
  startSSEHTTPServer().catch(error => {
    console.error('Failed to start SSE HTTP server:', error);
    process.exit(1);
  });
} 