import { spawnSync } from "node:child_process";
import pc from "picocolors";

export const STAR_REPOS = [
  "G12789/ctxshot",
  "G12789/ctxshot-mcp",
  "G12789/vision-bridge-mcp",
  "G12789/ai-ship",
] as const;

async function starOne(token: string, full: string): Promise<boolean> {
  const [owner, repo] = full.split("/");
  const res = await fetch(
    `https://api.github.com/user/starred/${owner}/${repo}`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "Content-Length": "0",
      },
    },
  );
  return res.status === 204 || res.status === 304;
}

function tokenFromGhCli(): string | null {
  const r = spawnSync("gh", ["auth", "token"], {
    encoding: "utf8",
    windowsHide: true,
  });
  const t = (r.stdout || "").trim();
  return t || null;
}

export async function cmdStar(): Promise<number> {
  console.log(pc.bold("AI Ship — Star 支持仓库\n"));
  console.log(
    pc.dim(
      "说明：GitHub 无法强制「先 Star 再下载」。此命令在你有 Token 时自动 Star。\n",
    ),
  );

  const token =
    process.env.GITHUB_TOKEN?.trim() ||
    process.env.GH_TOKEN?.trim() ||
    tokenFromGhCli();

  if (!token) {
    console.log(pc.yellow("未检测到 GITHUB_TOKEN / gh auth。请手动 Star：\n"));
    for (const r of STAR_REPOS) {
      console.log(`  https://github.com/${r}`);
    }
    console.log(
      pc.dim(
        "\n自动 Star：gh auth login  或  set GITHUB_TOKEN=ghp_xxx  后重试\n",
      ),
    );
    return 0;
  }

  let ok = 0;
  for (const repo of STAR_REPOS) {
    try {
      const starred = await starOne(token, repo);
      if (starred) {
        console.log(pc.green(`  ★ ${repo}`));
        ok++;
      } else {
        console.log(pc.red(`  ✗ ${repo} (API error)`));
      }
    } catch (e) {
      console.log(
        pc.red(`  ✗ ${repo}: ${e instanceof Error ? e.message : e}`),
      );
    }
  }

  console.log(pc.dim(`\n已处理 ${ok}/${STAR_REPOS.length} 个仓库`));
  return ok === STAR_REPOS.length ? 0 : 1;
}
