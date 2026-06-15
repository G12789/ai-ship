#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createAiShipMcpServer } from "./server.js";

const server = createAiShipMcpServer(process.cwd());
const transport = new StdioServerTransport();
await server.connect(transport);
