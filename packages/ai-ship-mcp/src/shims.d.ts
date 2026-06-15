declare module "ctxshot-mcp/register" {
  import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
  export function registerCtxshotTools(server: McpServer, cwd: string): void;
  export function createCtxshotMcpServer(cwd: string): McpServer;
}

declare module "vision-bridge-mcp/register" {
  import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
  export function registerVisionBridgeTools(server: McpServer, cwd: string): void;
  export function createVisionBridgeServer(cwd: string): McpServer;
}
