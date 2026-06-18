# 从零安装 AI Ship IDE 环境（录视频用）

> 一条脚本搞定：VS Code + Claude Code + DeepSeek + ai-ship-mcp  
> **不需要 ccSwitch**

## 观众只需要做什么

1. 双击 `一键安装-AI-Ship-IDE.bat`（或运行下方 PowerShell）
2. 输入 **DeepSeek API Key**（必填）
3. 输入 **Moonshot API Key**（可选，贴图识图）
4. 等脚本跑完 → **打开 VS Code** → 开聊

## 录视频推荐命令

```powershell
# 在任意项目目录打开 PowerShell，执行：
cd C:\Users\Administrator\Desktop\opensource-repos\ai-ship
powershell -ExecutionPolicy Bypass -File .\scripts\install-ai-ship-ide.ps1 -ProjectPath "D:\your-project"
```

或指定已有项目：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-ai-ship-ide.ps1 -ProjectPath "C:\Users\Administrator\Desktop\openclaw-deploy"
```

仅重装项目配置（系统已装好）：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-ai-ship-ide.ps1 -SkipSystemInstall -ProjectPath "你的项目路径"
```

## 脚本自动完成的事

| 步骤 | 内容 |
|------|------|
| 1 | winget 安装 Node.js / Git / VS Code / Claude Code |
| 2 | 安装 VS Code 扩展 `anthropic.claude-code` |
| 3 | 写入 `~/.claude/settings.json`（DeepSeek 直连） |
| 4 | `npx ship-skills init`（Skills + context） |
| 5 | 项目 Hook（SessionStart/End 记忆）+ `.mcp.json`（ai-ship-mcp 合一） |
| 6 | 预热 npm 包，可选自动打开 VS Code |

## 装完怎么验收

1. VS Code 打开项目文件夹（不是空窗口）
2. Claude Code 侧边栏开新聊
3. `@import` 弹窗 → **允许**
4. MCP 面板 `ai-ship` 变绿
5. 说「继续上次」→ 应读到 `.ai/focus.md` 内容

## 和 ccSwitch 的关系

**不需要 ccSwitch。**  
DeepSeek 通过 `~/.claude/settings.json` 的 `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 直连，这是 Claude Code 官方支持的第三方端点方式。

## 获取 API Key

- DeepSeek（写代码）：https://platform.deepseek.com/
- Moonshot/Kimi（看图旁路）：https://platform.moonshot.cn/
