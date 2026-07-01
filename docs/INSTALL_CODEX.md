# Codex 一键安装：CLI + 桌面 App + VS Code 插件（国产 / 官方可选）

和 Claude Code 那套（`install.ps1` / `install.sh`）平级的全自动安装，目标是 **OpenAI Codex（CLI + 桌面 App + VS Code 插件）**。

装时可**选模型来源**（直接 Enter = 国产）：

| | 国产（默认） | 官方 |
|--|--------------|------|
| 模型 | DeepSeek 写代码 + Kimi 识图 | 原生 `gpt-5.x` |
| 登录 | 无需登录，本地代理直连 | ChatGPT 账号（需订阅） |
| 网络 | **国内直连可用** | 需 ChatGPT 订阅 |
| 命令行指定 | `-Source domestic` / `--source domestic` | `-Source official` / `--source official` |

> **CLI、桌面 App、IDE 插件共用 `~/.codex/config.toml`**，装完三种界面都生效。国产模式额外写 `preferred_auth_method = "apikey"` + 占位 `~/.codex/auth.json`，让 VS Code 的 Codex 插件**不弹 ChatGPT 登录**、直接走本地代理（插件里贴图也自动转 Kimi 识图）。

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

1. 装 Node / Git / VS Code / **Codex 桌面 App**（winget msstore / brew cask，已装则升级），npm 默认走 npmmirror（国内免梯子）
2. 装 **Codex CLI**（`npm i -g @openai/codex`，带重试，网络抖动不致命）
3. 装 **Codex IDE 插件**（`openai.chatgpt`，只装进真正的 VS Code（与 Claude Code 一致，不进 Cursor））
4. **国产**：提示 DeepSeek Key（必填）+ Kimi Key（可选）→ 写 `~/.codex/codeproxy.config.json` + `~/.codex/config.toml`（provider 指向本地代理 + profile 文件 + `preferred_auth_method=apikey`）+ 占位 `auth.json`
   **官方**：跳过 Key/代理，写最简 `~/.codex/config.toml`（`model = "gpt-5.1-codex"`）
5. 生成启动器：终端版 **`启动Codex.bat`** / `codex-start.sh`；国产另生成 **`Codex-Proxy-Ensure.bat`** / `codex-proxy-ensure.sh`（后台静默起代理，不用一直开着窗口）、**`启动Codex全套.bat`** / `launch-codex-full.sh`
6. **注册登录自动起代理**（Windows 启动文件夹 / macOS LaunchAgent / Linux autostart），装完会**确保代理在跑 + 自动打开 Codex 桌面 App + VS Code**

## 日常使用

**日常（国产，推荐）**：**直接打开 Codex App 或 VS Code 即可**——登录后代理会在后台自动跑，不用先开代理窗口。

**终端**：双击 `启动Codex.bat`（Mac/Linux：`bash codex-start.sh`）

- 国产：自动起代理 → 探活就绪 → 进 Codex，默认 DeepSeek 写代码；快模型 `codex -p flash`；纯 Kimi `codex -p kimi`
- 官方：首次 `codex login` 登录 ChatGPT 账号
- 退出 Codex 后窗口会停在 `Press any key to close`，方便看任何报错

**全套一次打开**：双击 **`启动Codex全套.bat`**（Mac/Linux：`bash launch-codex-full.sh`）→ 代理 + App + VS Code

**桌面 App**（推荐，界面更完整）：开始菜单 / Launchpad 打开 **Codex**

- 国产：与 CLI/插件共用 `~/.codex` 配置，代理登录后自动在后台跑
- 官方：App 内 Sign in with ChatGPT

**IDE 插件**：在 VS Code 侧边栏打开 Codex（与 CLI 共用同一份 `~/.codex/config.toml`）

- 国产：**直接打开 VS Code 用 Codex**，贴图自动 Kimi 识图。若代理未起，双击 `Codex-Proxy-Ensure.bat`（Mac/Linux：`bash codex-proxy-ensure.sh`）
- 官方：插件里 **Sign in with ChatGPT**

## 故障排查

| 现象 | 原因 / 处理 |
|------|------------|
| 启动器闪一下就关、终端全是乱码 | 旧版 bug，已修：新版 `.bat` 纯 ASCII + 结尾 `pause`。重跑安装脚本重新生成启动器即可 |
| banner 显示 `provider: openai` | config.toml 没生效，确认顶部 `model_provider = "local"` 且代理在 8787 运行 |
| 404 / 空流 | 代理没起或上游协议不对，看代理窗口日志 |
| 贴图没反应 | 没填 Kimi Key（在 `~/.codex/codeproxy.config.json` 补 `kimi.apiKey`），或 `dropImages/fallback` 缺失 |
| IDE 插件弹 ChatGPT 登录（国产） | 确认 `~/.codex/config.toml` 有 `preferred_auth_method = "apikey"` 且 `~/.codex/auth.json` 存在；重启 IDE |
| IDE 插件没反应（国产） | 代理没在跑：双击 `Codex-Proxy-Ensure.bat`（Mac/Linux：`bash codex-proxy-ensure.sh`），或重跑安装脚本注册登录自动起代理 |

## 验证状态

- `@openai/codex` / `@codeproxy/cli` / `openai.chatgpt` 插件均真实存在（已核验）
- 国产 / 官方两路的 config.toml / 代理配置 / auth.json 生成、语法校验、插件安装指令、代理就绪探测均已实测通过
