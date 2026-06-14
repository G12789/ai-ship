import { existsSync, readFileSync, writeFileSync, appendFileSync, mkdirSync, copyFileSync } from "node:fs";
import { join } from "node:path";
import pc from "picocolors";
import { cmdCtx, cmdInitDeps, ensureGitignoreAi } from "./commands.js";
import { installSkills, PKG_ROOT } from "./install.js";
import { SKILL_NAMES } from "./types.js";

const VISION_MARKER = "<!-- ai-ship:vision-auto -->";

function ensureClaudeVisionRules(cwd: string): void {
  const snippetPath = join(PKG_ROOT, "templates", "CLAUDE.vision-snippet.md");
  if (!existsSync(snippetPath)) return;
  const snippet = readFileSync(snippetPath, "utf8").trim();
  const claudePath = join(cwd, "CLAUDE.md");
  if (existsSync(claudePath)) {
    const existing = readFileSync(claudePath, "utf8");
    if (existing.includes(VISION_MARKER) || existing.includes("describe_image")) {
      console.log(pc.dim("CLAUDE.md 已含看图规则，跳过"));
      return;
    }
    appendFileSync(
      claudePath,
      `\n\n${VISION_MARKER}\n${snippet}\n`,
      "utf8",
    );
    console.log(pc.green("已在 CLAUDE.md 追加 vision-auto 规则"));
    return;
  }
  writeFileSync(claudePath, `${VISION_MARKER}\n${snippet}\n`, "utf8");
  console.log(pc.green("已生成 CLAUDE.md（含 vision-auto 规则）"));
}

function ensureClaudeHooks(cwd: string): void {
  const scriptsDir = join(cwd, "scripts");
  const claudeDir = join(cwd, ".claude");
  mkdirSync(scriptsDir, { recursive: true });
  mkdirSync(claudeDir, { recursive: true });

  const tplScript = (name: string) =>
    join(PKG_ROOT, "templates", "scripts", name);
  for (const name of ["cc-session-start.ps1", "cc-on-image-prompt.ps1"]) {
    const src = tplScript(name);
    const dest = join(scriptsDir, name);
    if (!existsSync(src)) continue;
    copyFileSync(src, dest);
    console.log(pc.dim(`已安装 scripts/${name}`));
  }

  const settingsPath = join(claudeDir, "settings.json");
  const tplSettings = join(PKG_ROOT, "templates", "claude.settings.hooks.json");
  if (existsSync(tplSettings)) {
    let json = readFileSync(tplSettings, "utf8");
    const rootEsc = cwd.replace(/\\/g, "\\\\");
    json = json.replace(/\{\{PROJECT_ROOT\}\}/g, rootEsc);
    if (!existsSync(settingsPath)) {
      writeFileSync(settingsPath, json, "utf8");
      console.log(pc.green("已生成 .claude/settings.json（SessionStart + 贴图 Hook）"));
    } else {
      console.log(pc.dim(".claude/settings.json 已存在，跳过"));
    }
  }
}

export interface InitOptions {
  cwd: string;
  global: boolean;
  skipEval: boolean;
}

export function cmdInit(opts: InitOptions): number {
  console.log(pc.bold("AI Ship init — 一键配置工作流\n"));

  ensureGitignoreAi(opts.cwd);

  installSkills({
    cwd: opts.cwd,
    agents: ["universal", "claude", "cursor"],
    skills: [...SKILL_NAMES],
    global: opts.global,
    force: false,
    agentsMd: true,
  });

  ensureClaudeVisionRules(opts.cwd);

  if (!existsSync(join(opts.cwd, ".ai", "focus.md"))) {
    writeFileSync(
      join(opts.cwd, ".ai", "focus.md"),
      "# 当前焦点\n\n_在此写「正在做什么」和「下次继续」。_\n",
      "utf8",
    );
    console.log(pc.green("已生成 .ai/focus.md"));
  }

  ensureClaudeHooks(opts.cwd);

  if (!opts.skipEval) {
    const code = cmdInitDeps(opts.cwd);
    if (code !== 0) return code;
  }

  console.log("\n→ 生成首份会话上下文…");
  const ctxCode = cmdCtx({
    cwd: opts.cwd,
    compact: true,
    diff: true,
    out: ".ai/context.md",
  });
  if (ctxCode !== 0) {
    console.log(pc.yellow("ctxshot 未就绪，请先: npx ctxshot@0.1.0 --version"));
    return ctxCode;
  }

  console.log(pc.green("\n✓ init 完成"));
  console.log(pc.dim("日常：npx ship-skills ctx -o .ai/context.md"));
  console.log(pc.dim("支持作者：npx ai-ship star  （需 gh auth 或 GITHUB_TOKEN）"));
  console.log(pc.dim("完整文档：docs/STACK.md"));
  console.log(pc.dim("改 prompt 后：npx ship-skills eval"));
  console.log(pc.dim("提交前：npx ship-skills check"));
  if (existsSync(join(opts.cwd, "evaldrift.config.yaml"))) {
    console.log(pc.dim("首次 eval：npx evaldrift run && npx evaldrift baseline"));
  }
  return 0;
}
