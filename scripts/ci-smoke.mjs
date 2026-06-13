import { spawnSync } from "node:child_process";
import { mkdtempSync, existsSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

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
  return r.stdout;
}

run("npm", ["run", "build"], root);

const out = run("node", [join(root, "dist", "cli.js"), "doctor"], root);
if (!out.includes("bundle OK")) throw new Error("doctor failed");

const tmp = mkdtempSync(join(tmpdir(), "ai-ship-smoke-"));
try {
  run("node", [join(root, "dist", "cli.js"), "install", "-s", "session-start", "--no-agents-md"], tmp);
  const skillMd = join(tmp, ".agents", "skills", "session-start", "SKILL.md");
  if (!existsSync(skillMd)) throw new Error("install did not copy skill");
  const text = readFileSync(skillMd, "utf8");
  if (!text.includes("session-start")) throw new Error("SKILL.md content wrong");

  run("node", [join(root, "dist", "cli.js"), "list"], root);
  console.log("ai-ship smoke OK");
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
