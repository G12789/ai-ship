# 从零安装 AI Ship IDE 环境

> 一条脚本搞定：VS Code + Claude Code + DeepSeek + ai-ship-mcp  
> **不需要 ccSwitch**

## 观众只需要做什么

1. 运行对应系统的一键脚本
2. 输入 **DeepSeek API Key**（必填）
3. 输入 **Moonshot API Key**（可选，贴图识图）
4. 等脚本跑完 → **打开 VS Code** → 开聊

---

## Windows

双击 `一键安装.bat`，或 PowerShell：

```powershell
cd D:\your-project
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ProjectPath "D:\your-project"
```

远程一行装：

```powershell
cd D:\your-project
irm https://raw.githubusercontent.com/G12789/ai-ship/master/install.ps1 | iex
```

---

## macOS / Linux

```bash
cd ~/your-project
curl -fsSL https://raw.githubusercontent.com/G12789/ai-ship/master/install.sh | bash
```

或：

```bash
bash install.sh --project-path "$HOME/your-project"
```

**macOS 前置：** 已装 [Homebrew](https://brew.sh)。脚本会通过 brew 安装 Node / Git / VS Code，并通过官方脚本安装 Claude Code。

**Linux：** 尽量用系统包管理器装 Node 18+；若无则先手动装 Node 后 `--skip-system-install`。

仅重装项目（Hook / MCP / Skills）：

```bash
bash install.sh --skip-system-install --project-path .
```

---

## npm 包（跨平台，不含装系统软件）

若 Node 18+ 已有，只需项目内工作流：

```bash
cd your-project
npx ship-skills init
```

`init` 会安装 Skills、`.mcp.json`、**Node 版 Hook（.mjs）**、`.claude/settings.local.json`，Mac / Windows 通用。

---

## 脚本自动完成的事

| 步骤 | Windows (`install.ps1`) | Mac/Linux (`install.sh`) |
|------|-------------------------|---------------------------|
| 1 | winget 装 Node/Git/VS Code/Claude | brew / apt 装依赖 + `claude.ai/install.sh` |
| 2 | 交互输入 API Key | 同左 |
| 3 | `~/.claude/settings.json` DeepSeek 直连 | 同左 |
| 4 | 项目 Hook + MCP + CLAUDE.md | `npx ship-skills init` |
| 5 | ship-skills + context | 同左 |
| 6 | 预热 npm 缓存 | 同左 |

## 装完怎么验收

1. VS Code 打开**项目文件夹**（不是空窗口）
2. Claude Code 侧边栏开新聊
3. `@import` 弹窗 → **允许**
4. MCP 面板 `ai-ship` 变绿
5. 说「继续上次」→ 应读到 `.ai/focus.md` 内容
6. 贴一张截图 → 应触发识图 MCP

## 和 ccSwitch 的关系

**不需要 ccSwitch。**  
DeepSeek 通过 `~/.claude/settings.json` 的 `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 直连。

## 获取 API Key

- DeepSeek（写代码）：https://platform.deepseek.com/
- Moonshot/Kimi（看图旁路）：https://platform.moonshot.cn/

## Mac 常见问题

| 问题 | 处理 |
|------|------|
| `command not found: claude` | `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc` |
| `command not found: code` | VS Code → Command Palette →「Shell Command: Install 'code' command in PATH」 |
| MCP 不绿 | 确认项目根有 `.mcp.json` 和 `.claude/settings.local.json`，且已配置 `MOONSHOT_API_KEY` |
