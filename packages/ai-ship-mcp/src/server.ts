import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerCtxshotTools } from "ctxshot-mcp/register";
import { registerVisionBridgeTools } from "vision-bridge-mcp/register";

const VERSION = "0.1.0";

export function createAiShipMcpServer(cwd: string): McpServer {
  const server = new McpServer({
    name: "ai-ship-mcp",
    version: VERSION,
  });
  registerCtxshotTools(server, cwd);
  registerVisionBridgeTools(server, cwd);
  return server;
}
