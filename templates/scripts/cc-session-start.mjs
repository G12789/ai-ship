import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const ai = join(root, ".ai");
const ctxFile = join(ai, "context.md");
const handoffFile = join(ai, "handoff.md");
const focusFile = join(ai, "focus.md");

const MAX_AGE_HOURS = 4;
const CTXSHOT_ARGS = ["--compact", "--diff", "--depth", "3", "--max", "120"];
const npxCmd = process.platform === "win32" ? "npx.cmd" : "npx";

function runCtxshot(args) {
  const cli = process.env.CTXSHOT_CLI;
  if (cli && existsSync(cli)) {
    return spawnSync(process.execPath, [cli, ...args], {
      cwd: root,
      encoding: "utf8",
      windowsHide: true,
    });
  }
  return spawnSync(npxCmd, ["--yes", "ctxshot@latest", ...args], {
    cwd: root,
    encoding: "utf8",
    windowsHide: true,
  });
}

function readFile(path, label) {
  if (!existsSync(path)) return "";
  const body = readFileSync(path, "utf8").trim();
  if (!body) return "";
  return `\n\n## ${label}\n${body}`;
}

function extractHandoffGoals(md) {
  const m = md.match(/## (?:Goals|目标|下次继续|Next)[\s\S]*?(?=\n## |\n---|\Z)/i);
  return m ? m[0].trim() : "";
}

mkdirSync(ai, { recursive: true });

if (!existsSync(focusFile)) {
  writeFileSync(
    focusFile,
    "# 当前焦点\n\n_首次使用：在此写下「正在做什么」和「下次继续」。_\n",
    "utf8",
  );
}

let needRefresh = !existsSync(ctxFile);
if (existsSync(ctxFile)) {
  const ageH = (Date.now() - statSync(ctxFile).mtimeMs) / 3600000;
  if (ageH >= MAX_AGE_HOURS) needRefresh = true;
}

if (needRefresh) {
  const r = runCtxshot([...CTXSHOT_ARGS, "-o", ".ai/context.md"]);
  if (r.status !== 0 && !existsSync(ctxFile)) {
    process.stderr.write(
      `ctxshot refresh failed: ${((r.stderr || r.stdout) || "").toString().slice(0, 200)}\n`,
    );
  }
}

const handoffRaw = existsSync(handoffFile)
  ? readFileSync(handoffFile, "utf8")
  : "";
const handoffGoals = extractHandoffGoals(handoffRaw);

let context =
  "# Workspace memory (priority order)\n" +
  "1) focus.md = what we're doing NOW\n" +
  "2) handoff goals = last session intent\n" +
  "3) context.md = repo snapshot\n" +
  "Never ask user to run session_brief.\n";

context += readFile(focusFile, "CURRENT FOCUS (.ai/focus.md)");
if (handoffGoals) {
  context += `\n\n## LAST SESSION GOALS\n${handoffGoals}`;
} else {
  context += readFile(handoffFile, "HANDOFF (.ai/handoff.md)");
}
context += readFile(ctxFile, "PROJECT SNAPSHOT (.ai/context.md)");

process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: context.slice(0, 9800),
    },
  }),
);
