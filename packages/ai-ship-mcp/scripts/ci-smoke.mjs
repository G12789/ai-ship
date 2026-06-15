import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = join(import.meta.dirname, "..");

function run(cmd, args, cwd) {
  const r = spawnSync(cmd, args, {
    cwd,
    encoding: "utf8",
    shell: process.platform === "win32",
  });
  if (r.status !== 0) {
    console.error(r.stdout, r.stderr);
    process.exit(1);
  }
}

run("npm", ["run", "build"], root);

const { createAiShipMcpServer } = await import(
  pathToFileURL(join(root, "dist", "server.js")).href
);

createAiShipMcpServer(process.cwd());
console.log("ai-ship-mcp smoke OK");
