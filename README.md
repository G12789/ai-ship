# ship-skills（ai-ship）

> ⭐ **推荐：** `npx ship-skills init`（已登录 `gh` 会自动支持作者 ⭐）

[![CI](https://github.com/G12789/ai-ship/actions/workflows/ci.yml/badge.svg)](https://github.com/G12789/ai-ship/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/ship-skills?color=cb3837&logo=npm)](https://www.npmjs.com/package/ship-skills)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-7c3aed)](https://agentskills.io)

> npm 包名 **`ship-skills`**，CLI 命令 **`ai-ship`**。  
> 可拆装的 Agent Skills 工作流包 — 每个模块是 `SKILL.md` + 可执行 scripts。

```bash
npx ship-skills init          # 一键：Skills + 记忆 Hook + CLAUDE.md + MCP 规则
npx ai-ship ctx -o .ai/context.md
npx ai-ship star              # 自动 Star 配套仓库（需 gh / GITHUB_TOKEN）
npx ai-ship check
```

📖 **完整架构 / MCP 配置 / API Key / 故障排查** → [docs/STACK.md](docs/STACK.md)

> `ai-ship` 在 npm 已被占用，故发布名为 `ship-skills`。

---

## 🚀 零基础一键装好整套 IDE

不想敲一堆命令？一行装好 **Node + Git + VS Code + Claude Code（CLI + IDE 插件）+ 模型接入 + ai-ship-mcp（记忆+看图）**，全程只在配模型时提示输入 API Key，其余全自动，**无需 ccSwitch**。

装的时候可**选模型来源**：

- **[1] 国产**（默认）：DeepSeek 写代码 + Kimi 识图，便宜，**国内无 VPN 可用**；自动配好 `~/.claude/settings.json` 直连，并关掉插件登录提示
- **[2] 官方**：登录 Anthropic 账号用原生 Claude（需订阅/官方 Key）

> 直接 Enter = 国产。也可命令行指定 `-Source domestic|official`（PowerShell）/ `--source domestic|official`（bash）。
> CLI 与 VS Code 插件**共用同一套配置**，装完两端都能用（国产模式插件里贴图也走 Kimi 识图）。

### Windows

先进入你的项目目录，再在 PowerShell 里粘贴运行：

```powershell
cd D:\my-project
irm https://raw.githubusercontent.com/G12789/ai-ship/master/install.ps1 | iex
```

- 已装的组件自动跳过/升级，没装的自动安装
- 装系统组件需要管理员权限：建议「以管理员身份运行 PowerShell」后再执行

需要传参数时：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/G12789/ai-ship/master/install.ps1))) -SkipSystemInstall -ProjectPath "D:\my-project"
```

> 脚本是**单文件自包含**的。📖 细节见 [docs/INSTALL_IDE.md](docs/INSTALL_IDE.md)。

### macOS / Linux

先进入项目目录，在终端运行：

```bash
cd ~/my-project
curl -fsSL https://raw.githubusercontent.com/G12789/ai-ship/master/install.sh | bash
```

或本地：

```bash
bash install.sh --project-path "$HOME/my-project"
```

- 依赖 **Homebrew**（macOS）或已有 Node 18+ / Git（Linux）
- Claude Code 走官方 `https://claude.ai/install.sh`
- Hook 全用 **Node `.mjs`**，不依赖 PowerShell

仅重装项目配置（系统已装好）：

```bash
bash install.sh --skip-system-install --project-path .
```

---

## 🤖 也支持 Codex（CLI 终端版 + IDE 插件）

用 **OpenAI Codex** 而不是 Claude Code？另有一套平级的全自动脚本，同样装好 **CLI + VS Code/Cursor 插件**，并在装时让你**选模型来源**：

- **[1] 国产**（默认）：DeepSeek 写代码 + Kimi 识图。Codex 0.128+ 只认 OpenAI Responses 协议、无法直连 DeepSeek，脚本会自动配好本地协议代理（`@codeproxy/cli`）实现「贴图自动切 Kimi 识图」；并写 `preferred_auth_method=apikey` 让 IDE 插件免登录直接用本地代理
- **[2] 官方**：登录 ChatGPT 账号用原生 `gpt-5.x`（需订阅）

```powershell
# Windows
irm https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.ps1 | iex
```
```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.sh | bash
```

📖 细节与排查 → [docs/INSTALL_CODEX.md](docs/INSTALL_CODEX.md)

---

## 解决什么问题

| 场景 | 笨办法 | ship-skills |
|---|---|---|
| 每天新 AI 会话 | 反复解释项目 | `session-start` → ctxshot 简报 |
| DeepSeek 文本贴图 | 说看不到图 | `vision-auto` + **ai-ship-mcp** |
| 改 prompt 怕退化 | 靠感觉 | `prompt-guard` → evaldrift |
| 接 REST API | 从零写 MCP | `api-bridge` → mcp-quickstart |
| 提交前检查 | 漏测 | `ship-check` → ctx + eval |

---

## 五个核心 Skill（v0.2 收敛版）

| Skill | CLI / MCP | 频率 |
|---|---|---|
| **vision-auto** | ai-ship-mcp（vision 工具） | 贴截图 / DeepSeek 文本模型 |
| **session-start** | ai-ship-mcp（ctxshot 工具） | 每天 / 每个新会话 |
| **prompt-guard** | evaldrift | 改 prompt / 模板时 |
| **api-bridge** | mcp-quickstart | 接 REST API 时 |
| **ship-check** | ctxshot + evaldrift | 提交 / PR 前 |

> 19 个 niche Skill（blender、TD、ffmpeg 等）已移至 `skills/_archive/`，默认不安装，仅作参考。

---

## 30 秒接入

### 项目内一键配置

```bash
cd your-project
npx ship-skills init
```

`init` 会自动：

1. 安装 5 个 Skill 到 `.agents/skills` 等目录
2. 生成 `AGENTS.md`
3. 创建 / 追加 `CLAUDE.md`（含 **vision-auto 看图硬规则**）
4. 安装 **SessionStart / SessionEnd Hook** + `scripts/cc-session-*.mjs`
5. 写入 **`.mcp.json` + `.cursor/mcp.json`**（**ai-ship-mcp 一个服务**）
6. 生成 `.ai/focus.md`、`.ai/context.md`
7. `.gitignore` 追加 `.ai/`
8. 初始化 evaldrift（若无配置）

跳过 evaldrift：`npx ship-skills init --skip-eval`

**支持作者（GitHub 无法强制先 Star 再下载）：** `npx ai-ship star` — 见 [STACK.md § Star](docs/STACK.md#6-github-star--能否强制先-star-再下载)

### MCP（对外只宣传一个）

`init` 已自动配置 **`ai-ship-mcp`** — 记忆 + 看图 13 个工具，MCP 面板 **一条绿灯**。

手动配置（若未跑 init）：

```json
{
  "mcpServers": {
    "ai-ship": {
      "command": "npx",
      "args": ["-y", "ai-ship-mcp@latest"],
      "env": {
        "VISION_BRIDGE_BASE_URL": "https://api.moonshot.cn/v1",
        "VISION_BRIDGE_API_KEY": "${MOONSHOT_API_KEY}",
        "VISION_BRIDGE_MODELS": "kimi-k2.5,kimi-k2.6,moonshot-v1-8k-vision-preview"
      }
    }
  }
}
```

npm：[ai-ship-mcp](https://www.npmjs.com/package/ai-ship-mcp) · 完整说明 [docs/STACK.md](docs/STACK.md)

> 高级用户可拆成 `ctxshot-mcp` + `vision-bridge-mcp` 两个服务，见各仓库 README。

### 只装部分 Skill

```bash
npx ai-ship install -s vision-auto,session-start
npx ai-ship install -g -a cursor,claude    # 装到用户全局目录
npx ai-ship list                           # 列出内置 skill
```

---

## CLI 命令

| 命令 | 说明 |
|---|---|
| `ai-ship init` | 一键配置（推荐首次） |
| `ai-ship install` | 安装 Skill 到 Agent 目录 |
| `ai-ship ctx` | 打包项目上下文 → ctxshot |
| `ai-ship eval` | prompt 回归 → evaldrift |
| `ai-ship mcp <name>` | 生成 MCP Server → mcp-quickstart |
| `ai-ship check` | 提交前：刷新上下文 + eval |
| `ai-ship list` | 列出内置 skills |
| `ai-ship doctor` | 校验 bundle 完整性 |

### ctx 常用选项

```bash
npx ai-ship ctx --compact --diff -o .ai/context.md
```

---

## 典型一天工作流

```
早上开新会话
  → Agent 读 session-start Skill
  → 调 ctxshot-mcp session_brief 或 ai-ship ctx
  → @.ai/context.md

开发中贴报错截图
  → vision-auto 触发
  → 调 vision-bridge describe_image(mode: ui)
  → 根据描述修 bug

改完 system prompt
  → prompt-guard → npx evaldrift run

提交前
  → npx ai-ship check
```

---

## AI Ship Kit 四件套

| 包 | npm | 角色 |
|---|---|---|
| ctxshot-mcp | `npx ctxshot-mcp` | 每日项目简报 |
| vision-bridge-mcp | `npx vision-bridge-mcp` | 文本模型看图 |
| evaldrift | `npx evaldrift` | Prompt 回归 |
| ship-skills | `npx ship-skills` | 工作流 Skill 包（本仓库） |

---

## 和竞品怎么选？

| 需求 | 用谁 |
|---|---|
| 发现海量 skills | `npx skills`（Vercel） |
| 全库打包 | Repomix |
| **日常五步法 + DeepSeek 看图** | **ship-skills + vision-bridge-mcp** |
| 只要简报 / 只要测 prompt | 单独 `ctxshot` / `evaldrift` |
| TouchDesigner 控网 | [td-mcp](https://github.com/Pantani/tdmcp)（不自研） |

完整对比：[PRODUCT_COMPARISON.md](./PRODUCT_COMPARISON.md)

---

## 常见问题

### `init` 后 Agent 仍说看不到图？

1. MCP 里是否装了 `vision-bridge` 且为绿色
2. `CLAUDE.md` 是否有 vision 规则（`init` 应已写入）
3. `VISION_BRIDGE_API_KEY` 是否填对

### `ai-ship` 和 `ship-skills` 什么关系？

同一个包。`npm install ship-skills` 后命令行用 `ai-ship`。

### 旧版 23 个 Skill 去哪了？

`skills/_archive/`。需要时可手动复制，不再默认安装。

---

## License

MIT
