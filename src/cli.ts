#!/usr/bin/env node
import { parseArgs } from "node:util";
import pc from "picocolors";
import { cmdCheck, cmdCtx, cmdEval, cmdMcp } from "./commands.js";
import { cmdInit } from "./init-cmd.js";
import { cmdStar } from "./star-cmd.js";
import {
  installSkills,
  listBundledSkills,
  parseAgentList,
  parseSkillList,
  validateBundle,
} from "./install.js";
import { AGENTS } from "./paths.js";
import { SKILL_META, SKILL_NAMES } from "./types.js";

const VERSION = "0.2.3";

function help(): void {
  console.log(`
${pc.bold("ai-ship")} — 可拆装的 Agent Skills 工作流包 + CLI

${pc.bold("一键配置")}
  ai-ship init [选项]          安装 skills + .ai/ + evaldrift 模板 + 首份上下文

  init 选项:
    -g, --global               skills 装到用户目录
    --skip-eval                不运行 evaldrift init

${pc.bold("给人用（CLI）")}
  ai-ship ctx [选项]           打包项目上下文 → ctxshot
  ai-ship eval [选项...]       prompt 回归测试 → evaldrift run
  ai-ship mcp <name> [选项]    生成 MCP Server → mcp-quickstart
  ai-ship check                提交前：刷新上下文 + eval（若有配置）
  ai-ship star                 自动 Star 四个配套 GitHub 仓库（需 gh / GITHUB_TOKEN）

  ctx 选项:
    --compact                  更短输出
    --diff                     含 git 改动
    -o, --out <path>           写入文件（默认 stdout）

${pc.bold("给 Agent 用（Skills）")}
  ai-ship install [选项]       安装 SKILL.md + scripts 到 Agent 目录
  ai-ship list                 列出内置 skills

  install 选项:
    -g, --global               安装到用户目录（~/.agents/skills 等）
    -a, --agent <ids>          目标 Agent，逗号分隔（universal,claude,cursor,codex,copilot,gemini）
    -s, --skill <names>        只装指定 skill，逗号分隔或 *
    -f, --force                覆盖已存在目录
    --no-agents-md             不生成 AGENTS.md

${pc.bold("内置模块")}
${SKILL_NAMES.map((n) => `  • ${n} — ${SKILL_META[n].title}（${SKILL_META[n].frequency}）`).join("\n")}

${pc.dim("也可: npx skills add G12789/ai-ship")}
  -h, --help    -v, --version
`);
}

function cmdList(): void {
  console.log(pc.bold("AI Ship Skills\n"));
  for (const name of listBundledSkills()) {
    const m = SKILL_META[name];
    console.log(`  ${pc.cyan(name)}`);
    console.log(`    ${m.title} · ${m.frequency} · CLI: ${m.cli}`);
  }
  console.log(pc.dim("\n安装: npx ai-ship install"));
}

async function main(): Promise<void> {
  const raw = process.argv.slice(2);
  if (!raw.length || raw[0] === "--help" || raw[0] === "-h") {
    help();
    return;
  }
  if (raw[0] === "--version" || raw[0] === "-v") {
    console.log(VERSION);
    return;
  }

  const sub = raw[0];
  const rest = raw.slice(1);

  if (sub === "list" || sub === "ls") {
    cmdList();
    return;
  }

  if (sub === "init") {
    const { values } = parseArgs({
      args: rest,
      options: {
        global: { type: "boolean", short: "g", default: false },
        "skip-eval": { type: "boolean", default: false },
      },
      allowPositionals: true,
    });
    const code = cmdInit({
      cwd: process.cwd(),
      global: values.global ?? false,
      skipEval: values["skip-eval"] ?? false,
    });
    process.exit(code);
  }

  if (sub === "install") {
    const { values } = parseArgs({
      args: rest,
      options: {
        global: { type: "boolean", short: "g", default: false },
        agent: { type: "string", short: "a" },
        skill: { type: "string", short: "s" },
        force: { type: "boolean", short: "f", default: false },
        "agents-md": { type: "boolean", default: true },
        "no-agents-md": { type: "boolean", default: false },
      },
      allowPositionals: true,
    });
    installSkills({
      cwd: process.cwd(),
      agents: parseAgentList(values.agent),
      skills: parseSkillList(values.skill),
      global: values.global ?? false,
      force: values.force ?? false,
      agentsMd: values["no-agents-md"] ? false : (values["agents-md"] ?? true),
    });
    return;
  }

  if (sub === "ctx") {
    const { values } = parseArgs({
      args: rest,
      options: {
        compact: { type: "boolean", default: false },
        diff: { type: "boolean", default: false },
        out: { type: "string", short: "o" },
      },
      allowPositionals: true,
    });
    const code = cmdCtx({
      cwd: process.cwd(),
      compact: values.compact ?? false,
      diff: values.diff ?? false,
      out: values.out,
    });
    process.exit(code);
  }

  if (sub === "eval") {
    const code = cmdEval(process.cwd(), rest);
    process.exit(code);
  }

  if (sub === "mcp") {
    const code = cmdMcp(process.cwd(), rest);
    process.exit(code);
  }

  if (sub === "check") {
    const code = cmdCheck({ cwd: process.cwd() });
    process.exit(code);
  }

  if (sub === "star") {
    const code = await cmdStar();
    process.exit(code);
  }

  if (sub === "doctor") {
    const errs = validateBundle();
    if (errs.length) {
      console.log(pc.red("bundle 校验失败:"));
      errs.forEach((e) => console.log(`  - ${e}`));
      process.exit(1);
    }
    console.log(pc.green("bundle OK"));
    console.log(pc.dim(`Agents: ${AGENTS.map((a) => a.id).join(", ")}`));
    return;
  }

  console.error(pc.red(`未知命令: ${sub}`));
  help();
  process.exit(1);
}

main().catch((err: unknown) => {
  console.error(pc.red(err instanceof Error ? err.message : String(err)));
  process.exit(1);
});
