import { spawnSync } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const out = join(root, ".ai", "handoff.md");

function run(cmd, args) {
  const r = spawnSync(cmd, args, { cwd: root, encoding: "utf8", shell: process.platform === "win32" });
  return (r.stdout || "") + (r.stderr || "");
}

mkdirSync(join(root, ".ai"), { recursive: true });
const ctx = run("npx", ["--yes", "ctxshot", "--compact", "--diff"]);
const status = run("git", ["status", "-sb"]);
const log = run("git", ["log", "-3", "--oneline"]);
const md = `# Session handoff\n\n## Git\n\`\`\`\n${status.trim()}\n\`\`\`\n\n## Recent commits\n\`\`\`\n${log.trim()}\n\`\`\`\n\n## Project brief\n${ctx}`;
writeFileSync(out, md, "utf8");
console.log("Wrote", out);
