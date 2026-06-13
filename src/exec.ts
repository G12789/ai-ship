import { spawnSync } from "node:child_process";

export interface RunResult {
  ok: boolean;
  code: number;
  stdout: string;
  stderr: string;
}

export function run(
  cmd: string,
  args: string[],
  cwd: string,
  opts: { inherit?: boolean } = {},
): RunResult {
  const useShell = process.platform === "win32";
  const r = spawnSync(cmd, args, {
    cwd,
    encoding: "utf8",
    shell: useShell,
    stdio: opts.inherit ? "inherit" : ["ignore", "pipe", "pipe"],
  });
  return {
    ok: r.status === 0,
    code: r.status ?? 1,
    stdout: (r.stdout ?? "").toString(),
    stderr: (r.stderr ?? "").toString(),
  };
}

export function runNpx(
  pkgArgs: string[],
  cwd: string,
  opts: { inherit?: boolean } = {},
): RunResult {
  return run("npx", ["--yes", ...pkgArgs], cwd, opts);
}

export function runNpmCreate(
  pkg: string,
  args: string[],
  cwd: string,
): RunResult {
  return run("npm", ["create", pkg, ...args], cwd, { inherit: true });
}
