import { existsSync, readFileSync, writeFileSync, appendFileSync } from "node:fs";
import { join } from "node:path";
import pc from "picocolors";
import { run, runNpx } from "./exec.js";
import { ctxshotArgs, evaldriftArgs } from "./deps.js";

export interface CtxOptions {
  cwd: string;
  compact: boolean;
  diff: boolean;
  out?: string;
}

export function cmdCtx(opts: CtxOptions): number {
  const args = ctxshotArgs([]);
  if (opts.compact) args.push("--compact");
  if (opts.diff) args.push("--diff");
  if (opts.out) args.push("-o", opts.out);

  const local = process.env.AI_SHIP_CTXSHOT_BIN;
  const r = local
    ? run("node", args, opts.cwd, { inherit: true })
    : runNpx(args, opts.cwd, { inherit: true });
  return r.code;
}

export function cmdEval(cwd: string, extra: string[]): number {
  const base = evaldriftArgs(["run"]);
  const args = [...base, ...extra];
  const local = process.env.AI_SHIP_EVALDRIFT_BIN;
  const r = local
    ? run("node", args, cwd, { inherit: true })
    : runNpx(args, cwd, { inherit: true });
  return r.code;
}

export function cmdMcp(cwd: string, args: string[]): number {
  if (!args.length) {
    console.error(
      "用法: ai-ship mcp <name> [--from-openapi <url>] [--from-curl <cmd>]",
    );
    return 1;
  }
  const r = run("npm", ["create", "mcp-quickstart@0.6.0", ...args], cwd, {
    inherit: true,
  });
  return r.code;
}

export interface CheckOptions {
  cwd: string;
}

export function cmdCheck(opts: CheckOptions): number {
  console.log("→ 刷新项目上下文…");
  const ctxCode = cmdCtx({
    cwd: opts.cwd,
    compact: true,
    diff: true,
    out: ".ai/context.md",
  });
  if (ctxCode !== 0) return ctxCode;

  const hasConfig =
    existsSync(join(opts.cwd, "evaldrift.config.yaml")) ||
    existsSync(join(opts.cwd, ".evaldrift.yaml"));

  if (!hasConfig) {
    console.log("→ 跳过 evaldrift（未找到 evaldrift.config.yaml）");
    console.log(pc.green("✓ ship-check 完成（仅上下文）"));
    return 0;
  }

  console.log("→ 跑 prompt 回归测试…");
  const code = cmdEval(opts.cwd, []);
  if (code === 0) console.log(pc.green("✓ ship-check 全部通过"));
  return code;
}

export function ensureGitignoreAi(cwd: string): void {
  const gi = join(cwd, ".gitignore");
  const line = ".ai/";
  if (!existsSync(gi)) {
    writeFileSync(gi, `${line}\n`, "utf8");
    console.log(pc.green("已创建 .gitignore（含 .ai/）"));
    return;
  }
  const text = readFileSync(gi, "utf8");
  if (!text.split("\n").some((l) => l.trim() === ".ai/" || l.trim() === ".ai")) {
    appendFileSync(gi, `\n${line}\n`, "utf8");
    console.log(pc.green("已在 .gitignore 追加 .ai/"));
  }
}

export function cmdInitDeps(cwd: string): number {
  const hasEval =
    existsSync(join(cwd, "evaldrift.config.yaml")) ||
    existsSync(join(cwd, ".evaldrift.yaml"));
  if (hasEval) {
    console.log(pc.dim("evaldrift 配置已存在，跳过 init"));
    return 0;
  }
  console.log("→ 初始化 evaldrift（离线 mock，立即可跑）…");
  const args = evaldriftArgs(["init"]);
  const local = process.env.AI_SHIP_EVALDRIFT_BIN;
  const r = local
    ? run("node", args, cwd, { inherit: true })
    : runNpx(args, cwd, { inherit: true });
  return r.code;
}
