import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdtempSync,
  readFileSync,
  rmSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
const ctxshotCli = join(import.meta.dirname, "..", "..", "ctxshot", "dist", "cli.js");
const evaldriftCli = join(import.meta.dirname, "..", "..", "prompt-drift", "dist", "cli.js");

function run(cmd, args, cwd, env = {}) {
  const r = spawnSync(cmd, args, {
    cwd,
    encoding: "utf8",
    shell: process.platform === "win32",
    env: { ...process.env, ...env },
    stdio: ["ignore", "pipe", "pipe"],
  });
  if (r.status !== 0) {
    console.error("FAIL:", cmd, args.join(" "));
    console.error(r.stdout, r.stderr);
    process.exit(1);
  }
  return r.stdout;
}

run("npm", ["run", "build"], root);
run("npm", ["run", "build"], join(root, "..", "ctxshot"));
run("npm", ["run", "build"], join(root, "..", "prompt-drift"));

const env = {
  AI_SHIP_CTXSHOT_BIN: ctxshotCli,
  AI_SHIP_EVALDRIFT_BIN: evaldriftCli,
};

const tmp = mkdtempSync(join(tmpdir(), "ai-ship-e2e-"));
try {
  run("node", [join(root, "dist", "cli.js"), "init", "--skip-eval"], tmp, env);

  const ctxFile = join(tmp, ".ai", "context.md");
  if (!existsSync(ctxFile)) throw new Error("missing .ai/context.md");
  const ctx = readFileSync(ctxFile, "utf8");
  if (!ctx.includes("Project context")) throw new Error("bad context content");

  const skillDir = join(tmp, ".agents", "skills", "session-start", "SKILL.md");
  if (!existsSync(skillDir)) throw new Error("skills not installed");

  run("node", [join(root, "dist", "cli.js"), "check"], tmp, env);

  run("node", [evaldriftCli, "init"], tmp);
  run("node", [evaldriftCli, "run"], tmp);
  run("node", [join(root, "dist", "cli.js"), "check"], tmp, env);

  console.log("e2e-full OK");
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
