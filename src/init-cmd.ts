import { existsSync, readFileSync, writeFileSync, appendFileSync } from "node:fs";
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
  console.log(pc.dim("改 prompt 后：npx ship-skills eval"));
  console.log(pc.dim("提交前：npx ship-skills check"));
  if (existsSync(join(opts.cwd, "evaldrift.config.yaml"))) {
    console.log(pc.dim("首次 eval：npx evaldrift run && npx evaldrift baseline"));
  }
  return 0;
}
