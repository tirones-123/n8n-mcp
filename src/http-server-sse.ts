#!/usr/bin/env node
/**
 * SSE-enabled HTTP server for n8n-MCP that supports Claude API MCP connector
 * Supports both regular HTTP JSON-RPC and Server-Sent Events (SSE)
 */
import express from 'express';
import { N8NDocumentationMCPServer } from './mcp/server.js';
import { logger } from './utils/logger.js';
import { PROJECT_VERSION } from './utils/version.js';
import { loadAuthToken } from './http-server.js';
import dotenv from 'dotenv';

dotenv.config();

let authToken: string | null = null;

export async function startSSEHTTPServer() {
  try {
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

    // Middleware for parsing JSON
    app.use(express.json({ limit: '10mb' }));

    // CORS for Claude API
    app.use((req, res, next) => {
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept, Cache-Control');
      res.setHeader('Access-Control-Allow-Credentials', 'true');
      
      if (req.method === 'OPTIONS') {
        res.sendStatus(204);
        return;
      }
      next();
    });

    // Create MCP server instance
    const mcpServer = new N8NDocumentationMCPServer();

    // Health check
    app.get('/health', (req, res) => {
      res.json({ 
        status: 'ok',
        mode: 'http-sse',
        version: PROJECT_VERSION,
        transport: 'Custom SSE Implementation',
        capabilities: ['http', 'sse', 'json-rpc'],
        auth: 'Bearer token required',
        endpoints: {
          mcp: '/mcp (GET for SSE, POST for JSON-RPC)',
          sse: '/sse (GET for SSE, POST for JSON-RPC)',
          health: '/health'
        }
      });
    });

    // Authentication middleware
    const authenticate = (req: express.Request, res: express.Response, next: express.NextFunction) => {
      const authHeader = req.headers.authorization;
      
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ 
          jsonrpc: '2.0',
          error: {
            code: -32001,
            message: 'Unauthorized: Bearer token required'
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
            message: 'Unauthorized: Invalid token'
          },
          id: null
        });
        return;
      }

      next();
    };

    // SSE endpoint for Claude API (both /mcp and /sse for compatibility)
    const sseHandler = (req: express.Request, res: express.Response) => {
      // Set SSE headers
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Access-Control-Allow-Headers', 'Cache-Control');

      // Send initial connection event
      res.write('event: connected\n');
      res.write('data: {"type":"connection","status":"connected"}\n\n');

      // Keep connection alive
      const keepAlive = setInterval(() => {
        res.write('event: ping\n');
        res.write('data: {"type":"ping","timestamp":' + Date.now() + '}\n\n');
      }, 30000);

      // Handle client disconnect
      req.on('close', () => {
        clearInterval(keepAlive);
        logger.info('SSE client disconnected');
      });

      req.on('error', (err) => {
        clearInterval(keepAlive);
        logger.error('SSE connection error:', err);
      });

      logger.info('SSE connection established');
    };

    // Register SSE handler for both endpoints
    app.get('/mcp', authenticate, sseHandler);
    app.get('/sse', authenticate, sseHandler);

    // Main MCP endpoint for JSON-RPC (both /mcp and /sse for compatibility)
    const jsonRpcHandler = async (req: express.Request, res: express.Response) => {
      try {
        const { method, params, id } = req.body;
        
        logger.info(`MCP Request: ${method}`, { id, params: params ? Object.keys(params) : [] });

        let result;
        
        switch (method) {
          case 'initialize':
            result = {
              protocolVersion: '2024-11-05',
              capabilities: {
                tools: {},
              },
              serverInfo: {
                name: 'n8n-documentation-mcp',
                version: PROJECT_VERSION,
              },
            };
            break;
            
          case 'tools/list':
            // Get tools dynamically
            try {
              const { n8nDocumentationToolsFinal } = await import('./mcp/tools.js');
              const tools = [...n8nDocumentationToolsFinal];
              
              // Check if n8n API is configured
              try {
                const { isN8nApiConfigured } = await import('./config/n8n-api.js');
                if (isN8nApiConfigured()) {
                  const { n8nManagementTools } = await import('./mcp/tools-n8n-manager.js');
                  tools.push(...n8nManagementTools);
                }
              } catch (e) {
                logger.warn('Could not load n8n API configuration:', e);
              }
              
              result = { tools };
            } catch (e) {
              logger.error('Error loading tools:', e);
              result = { tools: [] };
            }
            break;
            
          case 'tools/call':
            if (!params?.name) {
              throw new Error('Tool name is required');
            }
            result = await mcpServer.executeTool(params.name, params.arguments || {});
            break;
            
          default:
            throw new Error(`Unknown method: ${method}`);
        }

        const response = {
          jsonrpc: '2.0',
          result,
          id
        };

        logger.info(`MCP Response: ${method} success`, { id, resultType: typeof result });
        res.json(response);
        
      } catch (error) {
        logger.error('MCP request failed:', error);
        
        const errorResponse = {
          jsonrpc: '2.0',
          error: {
            code: -32603,
            message: error instanceof Error ? error.message : 'Internal error',
            data: error instanceof Error ? error.stack : undefined
          },
          id: req.body?.id || null
        };
        
        res.status(500).json(errorResponse);
      }
    };

    // Register JSON-RPC handler for both endpoints
    app.post('/mcp', authenticate, jsonRpcHandler);
    app.post('/sse', authenticate, jsonRpcHandler);

    // Start server
    const port = parseInt(process.env.PORT || '3000');
    const host = process.env.HOST || '0.0.0.0';
    
    const server = app.listen(port, host, () => {
      console.log(`🚀 n8n MCP SSE-enabled HTTP Server running on ${host}:${port}`);
      console.log(`📊 Health check: http://localhost:${port}/health`);
      console.log(`🔌 MCP endpoints:`);
      console.log(`   - http://localhost:${port}/mcp (GET for SSE, POST for JSON-RPC)`);
      console.log(`   - http://localhost:${port}/sse (GET for SSE, POST for JSON-RPC)`);
      console.log(`✨ Supports: HTTP JSON-RPC and Server-Sent Events (SSE)`);
      console.log(`🔐 Authentication: Bearer token required`);
      console.log(`🎯 Optimized for Claude API MCP connector`);
      
      // Signal that server is ready for Railway
      console.log('SERVER_READY');
    });
    
    // Handle shutdown gracefully
    process.on('SIGTERM', () => {
      console.log('Received SIGTERM, shutting down gracefully...');
      server.close(() => {
        console.log('Server closed');
        process.exit(0);
      });
    });
  } catch (error) {
    console.error('Failed to start SSE HTTP server:', error);
    process.exit(1);
  }
}

// Start if called directly
if (require.main === module) {
  startSSEHTTPServer().catch(error => {
    console.error('Failed to start SSE HTTP server:', error);
    process.exit(1);
  });
} 