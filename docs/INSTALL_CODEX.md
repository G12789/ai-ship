# Codex 一键安装：DeepSeek 写代码 + Kimi 自动识图

和 Claude Code 那套（`install.ps1` / `install.sh`）平级的全自动安装，目标是 **OpenAI Codex CLI**。

## 为什么 Codex 需要本地代理（和 Claude Code 的本质区别）

| | Claude Code（ai-ship 主脚本） | Codex（本脚本） |
|--|------------------------------|----------------|
| 主模型接入 | DeepSeek **直连**，改 `~/.claude/settings.json` 环境变量即可，**无需代理** | **必须**经本地代理翻译 |
| 协议 | Anthropic 兼容，DeepSeek 提供 `/anthropic` 端点 | Codex 0.128+ **只认 OpenAI Responses 协议**，DeepSeek/Kimi 是 Chat Completions |
| 看图 | ai-ship-mcp（MCP 工具，模型主动调用） | 代理 `dropImages + fallback` 自动把含图请求转 Kimi（更省心） |
| 启动 | 直接 `claude` | 需先起常驻代理（启动器已自动处理） |

> 一句话：**Claude Code 能直连 DeepSeek，Codex 不能**——这就是两者必须分别做脚本的根本原因。
> 本脚本用开源的 [`@codeproxy/cli`](https://github.com/codeproxy-ai/cli) 在本机做 Responses↔ChatCompletions 协议翻译。

## 一键安装

### Windows

```powershell
irm https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.ps1 | iex
```

或本地：`powershell -ExecutionPolicy Bypass -File .\install-codex.ps1`

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.sh | bash
```

### 仅配置（系统已装好）

```powershell
powershell -ExecutionPolicy Bypass -File .\install-codex.ps1 -SkipSystemInstall
```
```bash
bash install-codex.sh --skip-system-install
```

## 安装做了什么

1. 装 Node / Git / VS Code（winget / brew，已装则升级）
2. 装 **Codex CLI**（`npm i -g @openai/codex`）和 **@codeproxy/cli**
3. 提示输入 **DeepSeek Key（必填）** + **Kimi Coding Key（可选，识图用）**
4. 写 `codeproxy.config.json`（DeepSeek 主 + 贴图 fallback 到 Kimi）
5. 写 `~/.codex/config.toml`（provider 指向本地代理 + 三个 profile）
6. 生成启动器 **`启动Codex.bat`** / `codex-start.sh`（自动起代理 → 进 Codex）

## 日常使用

双击 `启动Codex.bat`（Mac/Linux：`bash codex-start.sh`）：

- 默认 DeepSeek 写代码
- 快模型：`codex -p flash`
- 纯 Kimi：把 `codeproxy.config.json` 的 `currentUpstream` 改为 `kimi`，重启代理后 `codex -p kimi`

## 故障排查

| 现象 | 原因 / 处理 |
|------|------------|
| banner 显示 `provider: openai` | config.toml 没生效，确认顶部 `model_provider = "local"` 且代理在 8787 运行 |
| 404 / 空流 | 代理没起或上游协议不对，看代理窗口日志 |
| 贴图没反应 | 没填 Kimi Key，或 `dropImages/fallback` 缺失 |

## 验证状态

- `@openai/codex` / `@codeproxy/cli` 包名真实存在（已核验）
- 安装脚本、config.toml 生成、代理启动、curl 就绪探测均已实测通过
