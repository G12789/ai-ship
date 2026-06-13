# -*- coding: utf-8 -*-
"""批量生成 ai-ship 扩展 Skills（v0.2.0）。"""
from __future__ import annotations

from pathlib import Path

SKILLS = Path(r"C:\Users\Administrator\Desktop\opensource-repos\ai-ship\skills")

TEMPLATE = """---
name: {name}
description: >
  {desc}
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: {category}
  homepage: https://github.com/G12789/ai-ship
---

# {title}

{body}
"""

SKILL_DATA: list[dict] = [
    {
        "name": "vision-bridge",
        "title": "vision-bridge — 文本模型看图",
        "category": "mcp",
        "desc": "Use when the main LLM cannot see images (DeepSeek text, local LLMs). Call vision-bridge-mcp to describe screenshots, UI, TouchDesigner networks, or OCR errors into text.",
        "body": """## 何时使用

- Claude Code / VS Code 主模型是 **DeepSeek 文本版**（无视觉）
- 用户 @ 了截图、设计稿、TouchDesigner 节点图、CI 失败截图
- 需要 OCR 终端/日志图片

## 架构（双模型）

```
主模型 DeepSeek（文本）  ← 读文字
        ↑
vision-bridge-mcp        ← 图片转文字
        ↑
旁路视觉模型（Ollama llava / Qwen-VL / gpt-4o-mini）
```

## MCP 配置

```json
{
  "mcpServers": {
    "vision-bridge": {
      "command": "npx",
      "args": ["-y", "vision-bridge-mcp@latest"],
      "env": {
        "VISION_BRIDGE_BASE_URL": "http://localhost:11434/v1",
        "VISION_BRIDGE_MODEL": "llava"
      }
    }
  }
}
```

## 步骤

1. `ollama pull llava`（或配置云视觉 API）
2. 调用 `describe_image({ path, mode })`
   - `touchdesigner` — 节点网截图
   - `ui` — IDE/设置页
   - `ocr` — 纯文字提取
3. 把返回的 Markdown 当作上下文继续推理

## 工具

- `describe_image` · `extract_text` · `vision_status`

npm: `npx vision-bridge-mcp`""",
    },
    {
        "name": "session-handoff",
        "title": "session-handoff — 换 IDE/模型不丢上下文",
        "category": "workflow",
        "desc": "Use when switching between Cursor, Claude Code, VS Code, or models. Packs ctxshot brief, git status, and handoff notes into .ai/handoff.md.",
        "body": """## 何时使用

- 从 Cursor 换到 Claude Code / VS Code
- 换 DeepSeek ↔ Claude ↔ GPT
- 下班前打包「明天接着干」

## 步骤

```bash
node scripts/handoff.mjs
```

生成 `.ai/handoff.md`：
- ctxshot 项目简报
- 当前分支 + 未提交文件
- 最近 3 条 commit 信息

## 相关

- 依赖 [ctxshot](https://github.com/G12789/ctxshot)
- 配合 vision-bridge 交接截图说明""",
    },
    {
        "name": "ci-log-triage",
        "title": "ci-log-triage — CI 失败日志分拣",
        "category": "devops",
        "desc": "Use when GitHub Actions or CI failed. Parses log excerpts, suggests fix order, pairs with ctxshot project context.",
        "body": """## 何时使用

- CI 红了，日志几百行
- 不确定先修 lockfile 还是先修 types

## 步骤

1. 复制失败 job 日志到 `ci-failure.log`
2. `node scripts/triage.mjs ci-failure.log`
3. 输出：错误分类 + 建议修复顺序
4. 结合 `@.ai/context.md` 让 Agent 改代码

## 识别模式

- TypeScript / ESLint / test snapshot / npm ci / lockfile""",
    },
    {
        "name": "pr-diff-brief",
        "title": "pr-diff-brief — PR 变更简报",
        "category": "workflow",
        "desc": "Use before reviewing or continuing a PR. Summarizes git diff into a compact markdown brief (~500 tokens).",
        "body": """## 步骤

```bash
node scripts/pr-brief.mjs
# 或指定范围
node scripts/pr-brief.mjs main...HEAD
```

输出 `.ai/pr-brief.md`：文件列表、stat、关键 hunks 摘要。""",
    },
    {
        "name": "rules-drift",
        "title": "rules-drift — 规则与代码漂移检测",
        "category": "quality",
        "desc": "Use when AGENTS.md or .cursorrules exist but the codebase may not follow them. Compares stated rules vs manifest/scripts.",
        "body": """## 检查项

- `AGENTS.md` / `CLAUDE.md` 是否存在且被引用
- package.json scripts 是否与文档一致
- .gitignore 是否遗漏 .ai/

## 步骤

阅读规则文件 → glob 关键目录 → 列出漂移点（不自动改代码）。""",
    },
    {
        "name": "subagent-receipt",
        "title": "subagent-receipt — 子 Agent 交接收据",
        "category": "workflow",
        "desc": "Use after a background/subagent task completes. Structures what changed, what was tested, and open risks.",
        "body": """## 输出模板

```markdown
## Subagent receipt
- Task:
- Files changed:
- Commands run:
- Tests:
- Risks / not done:
```

写入 `.ai/subagent-receipt.md` 供主会话读取。""",
    },
    {
        "name": "touchdesigner-dat",
        "title": "touchdesigner-dat — TD Python DAT 生成",
        "category": "creative-coding",
        "desc": "Use for TouchDesigner projects. Generates Python DAT scripts, GLSL hints, operator wiring notes. Pair with vision-bridge for network screenshots.",
        "body": """## 何时使用

- 「有没有 Codex 接入 TouchDesigner 的 skill？」
- 写 OSC/MIDI/CHOP 逻辑
- 看不懂节点网（先 `describe_image` mode=touchdesigner）

## 步骤

1. 描述需求（例：「OSC 接收 /tuio/2Dcur 驱动 Instancing」）
2. 生成 Python DAT 代码 → 粘贴到 Text DAT
3. 给出接线说明（哪个 OP 连哪个）

## 模板

见 `templates/osc-receiver.py`、`audio-chop-drive.py`

## 限制

- 不能直接编辑 .toe 二进制
- 复杂图建议 TD 内跑导出脚本""",
    },
    {
        "name": "glsl-live-fix",
        "title": "glsl-live-fix — GLSL 报错修复",
        "category": "creative-coding",
        "desc": "Use when GLSL in TouchDesigner, Blender, or shadertoy-style shaders fails to compile. Fix from error log + optional vision-bridge screenshot.",
        "body": """## 步骤

1. 粘贴编译报错
2. 粘贴 shader 源码
3. 可选：TOP 截图 → vision-bridge
4. 输出修正版 + 解释 uniform/sampler 问题""",
    },
    {
        "name": "osc-midi-probe",
        "title": "osc-midi-probe — OSC/MIDI 调试",
        "category": "creative-coding",
        "desc": "Use for interactive installs, VJ, TouchDesigner. Generates probe scripts and test message lists.",
        "body": """## 输出

- Python/C++ 探针脚本
- 测试 OSC 地址表示例
- MIDI CC 映射表模板""",
    },
    {
        "name": "processing-port",
        "title": "processing-port — p5/Processing 互转",
        "category": "creative-coding",
        "desc": "Use when porting generative art between p5.js and Processing Java modes.",
        "body": """## 步骤

提供源草图 → 输出目标环境代码 + 坐标系/性能注意事项。""",
    },
    {
        "name": "ffmpeg-reel",
        "title": "ffmpeg-reel — 命令行剪片",
        "category": "media",
        "desc": "Use for short video cuts, vertical crop, subtitle burn, concat. Outputs ffmpeg commands, not GUI.",
        "body": """## 示例

- 竖屏 9:16 裁切
- 批量 concat
- 烧录 srt""",
    },
    {
        "name": "terminal-replay",
        "title": "terminal-replay — 终端排错剧本",
        "category": "workflow",
        "desc": "Use after a painful debug session. Records commands + outcomes into reproducible markdown for Codex/Claude.",
        "body": """## 输出 `.ai/terminal-replay.md`

```markdown
### Step 1
$ command
→ result / error
```""",
    },
    {
        "name": "env-diff",
        "title": "env-diff — 环境变量对齐",
        "category": "devops",
        "desc": "Use when works on my machine but fails in CI/teammate. Compares .env.example vs process.env keys mentioned in code.",
        "body": """## 步骤

1. 读 `.env.example`
2. grep `process.env` / `os.environ`
3. 列出缺失键（不读真实 .env 秘密）""",
    },
    {
        "name": "wrangler-coach",
        "title": "wrangler-coach — Cloudflare Workers 教练",
        "category": "devops",
        "desc": "Use for Workers, D1, wrangler.toml, migrations. Tied to merchant SaaS CF experience.",
        "body": """## 覆盖

- wrangler.toml 结构
- D1 migrations
- Worker 边界（长任务外置）
- 本地 `wrangler dev` 排错""",
    },
    {
        "name": "monorepo-gate",
        "title": "monorepo-gate — 改包影响面",
        "category": "quality",
        "desc": "Use in monorepos. When package A changes, lists which packages need rebuild/test.",
        "body": """## 步骤

1. 识别 workspace 根
2. 看变更路径属于哪个 package
3. 建议 `npm run test -w pkg` 顺序""",
    },
    {
        "name": "blender-bpy",
        "title": "blender-bpy — Blender 脚本",
        "category": "creative-coding",
        "desc": "Use for Blender automation: batch import, render queue, scene cleanup via bpy.",
        "body": """输出可在 Scripting 面板运行的 bpy 脚本。""",
    },
    {
        "name": "ableton-m4l",
        "title": "ableton-m4l — Max for Live 片段",
        "category": "creative-coding",
        "desc": "Use for Ableton Live Max for Live device logic, MIDI routing snippets.",
        "body": """生成 Max patcher 文字说明 + 核心 object 连接。""",
    },
    {
        "name": "homeassistant-yaml",
        "title": "homeassistant-yaml — HA 自动化",
        "category": "iot",
        "desc": "Use for Home Assistant automations, scripts, blueprint-style YAML.",
        "body": """## 注意

提醒用户检查实体 ID，不编造设备名。""",
    },
    {
        "name": "qgis-pyqgis",
        "title": "qgis-pyqgis — QGIS 脚本",
        "category": "gis",
        "desc": "Use for QGIS PyQGIS batch processing, layer styling scripts.",
        "body": """输出 Processing 算法或 PyQGIS 控制台脚本。""",
    },
]


def write_skill(s: dict) -> None:
    d = SKILLS / s["name"]
    d.mkdir(parents=True, exist_ok=True)
    (d / "SKILL.md").write_text(
        TEMPLATE.format(
            name=s["name"],
            desc=s["desc"].replace("\n", " "),
            category=s["category"],
            title=s["title"],
            body=s["body"],
        ),
        encoding="utf-8",
    )
    print("✓", s["name"])


def write_scripts() -> None:
    handoff = SKILLS / "session-handoff" / "scripts" / "handoff.mjs"
    handoff.parent.mkdir(parents=True, exist_ok=True)
    handoff.write_text(
        r"""import { spawnSync } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const out = join(root, ".ai", "handoff.md");

function run(cmd, args) {
  const r = spawnSync(cmd, args, { cwd: root, encoding: "utf8", shell: process.platform === "win32" });
  return (r.stdout || "") + (r.stderr || "");
}

mkdirSync(join(root, ".ai"), { recursive: true });
const ctx = run("npx", ["--yes", "ctxshot", "--compact", "--diff"]);
const status = run("git", ["status", "-sb"]);
const log = run("git", ["log", "-3", "--oneline"]);
const md = `# Session handoff\n\n## Git\n\`\`\`\n${status.trim()}\n\`\`\`\n\n## Recent commits\n\`\`\`\n${log.trim()}\n\`\`\`\n\n## Project brief\n${ctx}`;
writeFileSync(out, md, "utf8");
console.log("Wrote", out);
""",
        encoding="utf-8",
    )

    triage = SKILLS / "ci-log-triage" / "scripts" / "triage.mjs"
    triage.parent.mkdir(parents=True, exist_ok=True)
    triage.write_text(
        r"""import { readFileSync } from "node:fs";

const file = process.argv[2] || "ci-failure.log";
const log = readFileSync(file, "utf8");
const rules = [
  [/TS\d{4}|error TS/, "TypeScript 编译错误 — 先 npm run build 本地复现"],
  [/eslint|ESLint/, "Lint — 跑 npm run lint -- --fix"],
  [/npm ERR!|lockfile|package-lock/, "依赖/lockfile — rm -rf node_modules && npm ci"],
  [/snapshot|Snapshot/, "测试快照 — 审查是否预期变更"],
  [/Cannot find module/, "模块解析 — 检查 exports/types 路径"],
  [/Process completed with exit code/, "通用失败 — 往上找第一个 error"],
];
console.log("# CI triage\n");
let hit = false;
for (const [re, hint] of rules) {
  if (re.test(log)) {
    console.log(`- **${hint}**`);
    hit = true;
  }
}
if (!hit) console.log("- 未匹配常见模式，建议把第一段 error stack 贴给 Agent");
""",
        encoding="utf-8",
    )

    pr = SKILLS / "pr-diff-brief" / "scripts" / "pr-brief.mjs"
    pr.parent.mkdir(parents=True, exist_ok=True)
    pr.write_text(
        r"""import { spawnSync } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const range = process.argv[2] || "HEAD~1...HEAD";
const stat = spawnSync("git", ["diff", "--stat", range], { cwd: root, encoding: "utf8" });
const names = spawnSync("git", ["diff", "--name-only", range], { cwd: root, encoding: "utf8" });
mkdirSync(join(root, ".ai"), { recursive: true });
const out = join(root, ".ai", "pr-brief.md");
const md = `# PR diff brief (${range})\n\n## Files\n${names.stdout}\n## Stat\n\`\`\`\n${stat.stdout}\`\`\``;
writeFileSync(out, md, "utf8");
console.log("Wrote", out);
""",
        encoding="utf-8",
    )

    td = SKILLS / "touchdesigner-dat" / "templates" / "osc-receiver.py"
    td.parent.mkdir(parents=True, exist_ok=True)
    td.write_text(
        '''# TouchDesigner Python DAT — OSC receiver template\n# Paste into Text DAT, connect to CHOP Execute or Timer\n\nclass OSCReceiver:\n    def __init__(self, ownerComp):\n        self.ownerComp = ownerComp\n\n    def onReceiveOSC(self, message, address, args, peer):\n        debug(message, address)\n        # args[0].val — map to custom params\n        return\n''',
        encoding="utf-8",
    )
    print("✓ scripts + templates")


def write_catalog() -> None:
    catalog = Path(r"C:\Users\Administrator\Desktop\opensource-repos\ai-ship\SKILLS_CATALOG.md")
    lines = ["# AI Ship Skills 目录 v0.2.0\n", "| Skill | 类别 | 说明 |", "|---|---|---|"]
    for s in SKILL_DATA:
        lines.append(f"| `{s['name']}` | {s['category']} | {s['title']} |")
    lines.append("\n## MCP 配套\n\n| MCP | npm |\n|---|---|\n| ctxshot-mcp | npx ctxshot-mcp |\n| vision-bridge-mcp | npx vision-bridge-mcp |\n")
    catalog.write_text("\n".join(lines), encoding="utf-8")
    print("✓ SKILLS_CATALOG.md")


def main() -> None:
    for s in SKILL_DATA:
        write_skill(s)
    write_scripts()
    write_catalog()
    print(f"\n共 {len(SKILL_DATA)} 个新 Skill")


if __name__ == "__main__":
    main()
