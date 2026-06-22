import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const ai = join(root, ".ai");
const out = join(ai, "handoff.md");
const focusFile = join(ai, "focus.md");
const npxCmd = process.platform === "win32" ? "npx.cmd" : "npx";

function runCtxshot(args) {
  const cli = process.env.CTXSHOT_CLI;
  const r =
    cli && existsSync(cli)
      ? spawnSync(process.execPath, [cli, ...args], {
          cwd: root,
          encoding: "utf8",
          windowsHide: true,
        })
      : spawnSync(npxCmd, ["--yes", "ctxshot@latest", ...args], {
          cwd: root,
          encoding: "utf8",
          windowsHide: true,
        });
  return ((r.stdout || "") + (r.stderr || "")).trim();
}

function runGit(args) {
  const r = spawnSync("git", args, {
    cwd: root,
    encoding: "utf8",
    windowsHide: true,
  });
  return ((r.stdout || "") + (r.stderr || "")).trim();
}

mkdirSync(ai, { recursive: true });

const ctx = runCtxshot(["--compact", "--diff", "--depth", "2", "--max", "60"]);
const status = runGit(["status", "-sb"]);
const log = runGit(["log", "-5", "--oneline"]);
const stamp = new Date().toISOString();

const focus = existsSync(focusFile)
  ? readFileSync(focusFile, "utf8").trim()
  : "_no focus.md_";

const md = `# Session handoff
updated: ${stamp}

## 目标 / 下次继续
> 关聊前把「正在做什么」写进 \`.ai/focus.md\`，此处会引用。

${focus}

## Git
\`\`\`
${status || "(no git)"}
\`\`\`

## Recent commits
\`\`\`
${log || "(no log)"}
\`\`\`

## Project brief (ctxshot)
${ctx || "(ctxshot unavailable)"}
`;

writeFileSync(out, md, "utf8");
process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "SessionEnd",
      additionalContext: `Handoff saved: .ai/handoff.md (${stamp})`,
    },
  }),
);
