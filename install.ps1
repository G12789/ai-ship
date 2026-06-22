#Requires -Version 5.1
<#
.SYNOPSIS
  AI Ship 一键安装：VS Code + Claude Code + DeepSeek + ai-ship-mcp（记忆+看图）

.DESCRIPTION
  全自动完成你之前让我手工配置的那套环境，无需 ccSwitch。
  运行中只会提示输入 API Key，其余全部自动。

.PARAMETER ProjectPath
  要配置记忆/MCP 的项目目录。默认：脚本运行时当前目录。

.PARAMETER SkipSystemInstall
  跳过 Node/Git/VS Code/Claude Code 安装（仅配置 Key + 项目）

.PARAMETER OpenVsCode
  完成后自动用 VS Code 打开项目，并直接切到 Claude Code 对话框（默认开启）。

.EXAMPLE
  # 双击运行 或：
  powershell -ExecutionPolicy Bypass -File .\install-ai-ship-ide.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install-ai-ship-ide.ps1 -ProjectPath "D:\my-project" -OpenVsCode
#>
param(
  [string]$ProjectPath = "",
  [switch]$SkipSystemInstall,
  [switch]$OpenVsCode = $true,
  # 高级/测试用：直接传 Key 则跳过交互（默认留空 = 隐藏式交互输入）
  [string]$DeepseekKey = "",
  [string]$MoonshotKey = "",
  # 测试用：重定向 Claude 用户配置路径（默认 ~/.claude/settings.json）
  [string]$ClaudeSettingsPath = "",
  # 测试用：重定向 VS Code 用户配置路径（默认 %APPDATA%\Code\User\settings.json）
  [string]$VsCodeSettingsPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 系统执行策略为 Restricted 时，调用 npm/npx 会解析到 npm.ps1/npx.ps1 而被「禁止运行脚本」
# 终止性安全异常中断整个安装。这里给「当前进程」放行（无需管理员、进程退出即恢复）。
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch { }

# 无代理也能下：npm 包默认走国内镜像（仅本次运行内生效，不改用户全局 .npmrc）。
# 用户若已自行配置 registry，则尊重其设置不覆盖。
if (-not $env:npm_config_registry) { $env:npm_config_registry = "https://registry.npmmirror.com" }

# ─── 路径 ─────────────────────────────────────────────
# 自包含脚本：所有模板内联在本文件末尾，不依赖任何外部 templates/ 目录。
# 兼容三种运行方式：双击 / -File / `irm <url> | iex`（管道运行时无文件路径）。
$SelfPath = $null
if ($PSCommandPath) {
  $SelfPath = $PSCommandPath
} else {
  # 管道运行(irm|iex)时 $MyInvocation.MyCommand 没有 Path 属性，
  # StrictMode Latest 下直接访问会抛 PropertyNotFoundStrict，这里先判存在再取。
  try {
    $mc = $MyInvocation.MyCommand
    if ($mc -and $mc.PSObject.Properties['Path'] -and $mc.Path) { $SelfPath = $mc.Path }
  } catch { $SelfPath = $null }
}

if ($ClaudeSettingsPath) {
  $UserClaudeSettings = $ClaudeSettingsPath
  $UserClaudeDir = Split-Path -Parent $ClaudeSettingsPath
} else {
  $UserClaudeDir = Join-Path $env:USERPROFILE ".claude"
  $UserClaudeSettings = Join-Path $UserClaudeDir "settings.json"
}

if ($VsCodeSettingsPath) {
  $UserVsCodeSettings = $VsCodeSettingsPath
} else {
  $UserVsCodeSettings = Join-Path $env:APPDATA "Code\User\settings.json"
}

if (-not $ProjectPath) {
  $ProjectPath = (Get-Location).Path
}
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path

# ─── 输出 ─────────────────────────────────────────────
function Write-Step([string]$n, [string]$msg) {
  Write-Host ""
  Write-Host "[$n] $msg" -ForegroundColor Cyan
}
function Write-Ok([string]$msg) { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Skip([string]$msg) { Write-Host "  --  $msg" -ForegroundColor DarkGray }
function Write-Warn([string]$msg) { Write-Host "  !!  $msg" -ForegroundColor Yellow }

# 检查进度条：和下载进度条同款观感。重跑时已装组件走「快速检查」而非重下，省时又有视频效果。
function Show-CheckBar([string]$Label, [int]$DurationMs = 800) {
  $width = 26
  $delay = [math]::Max(6, [int]($DurationMs / $width))
  for ($i = 1; $i -le $width; $i++) {
    $fill = ("#" * $i).PadRight($width, '.')
    $pct = [int](($i * 100) / $width)
    Write-Host ("`r  检查 {0} [{1}] {2,3}%" -f $Label, $fill, $pct) -NoNewline -ForegroundColor Cyan
    Start-Sleep -Milliseconds $delay
  }
  Write-Host ("`r  检查 {0} [{1}] 100%" -f $Label, ("#" * $width)) -NoNewline -ForegroundColor Green
  Write-Host ""
}

# 写 UTF-8 无 BOM 文本文件（hooks/mjs/json 都用它）
function Write-TextFile([string]$Path, [string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

# 合并 VS Code 用户 settings.json：关掉「信任此文件夹作者」弹窗 + 各种首启打扰
# 这是「装完打开却用不了、还要点一堆东西」的根因（工作区信任=受限模式会禁用扩展/终端）
function Set-VsCodeUserSettings([string]$Path) {
  $desired = [ordered]@{
    "security.workspace.trust.enabled"       = $false
    "security.workspace.trust.startupPrompt" = "never"
    "security.workspace.trust.banner"        = "never"
    "telemetry.telemetryLevel"               = "off"
    "workbench.startupEditor"                = "none"
    "git.openRepositoryInParentFolders"      = "never"
    "extensions.ignoreRecommendations"       = $true
    "update.showReleaseNotes"                = $false
  }
  $merged = [ordered]@{}
  if (Test-Path $Path) {
    try {
      $obj = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
      $obj.PSObject.Properties | ForEach-Object { $merged[$_.Name] = $_.Value }
    } catch {
      # 解析失败（可能含注释/损坏）→ 先备份再用全新配置，避免误删用户内容
      $bak = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
      Copy-Item -LiteralPath $Path -Destination $bak -Force -ErrorAction SilentlyContinue
      Write-Skip "VS Code 旧配置无法解析，已备份 → $([System.IO.Path]::GetFileName($bak))"
    }
  }
  foreach ($k in $desired.Keys) { $merged[$k] = $desired[$k] }
  $json = ($merged | ConvertTo-Json -Depth 20)
  Write-TextFile $Path $json
}

# ═══════════════════════════════════════════════════════
# 内联模板（自包含，无需外部 templates/ 目录）
# ═══════════════════════════════════════════════════════
$TPL_MEMORY = @'
# {{PROJECT_NAME}}

每次新开对话**按优先级**自动加载（`@import`，重启不丢）：

@.ai/focus.md

@.ai/handoff.md

@.ai/context.md

**focus = 正在做什么（最准）** · handoff = 上次快照 · context = 仓库结构+git

---

## 记忆规则

- **禁止**让用户手调 `session_brief`
- 用户说「继续上次」→ 先读 `focus.md`，再 `handoff.md`
- 关聊前说「更新 focus」→ 把当前任务写入 `.ai/focus.md`（SessionEnd 会同步到 handoff）
- context 每 4 小时 SessionStart 自动刷新；感觉不准时说「刷新 context」

## 自动干活

改代码、只读命令直接做；删库、force push 才确认。
'@

$TPL_VISION = @'
## Image / Vision (required for text-only models like DeepSeek)

Your base model **CANNOT** see images. When the user attaches or references an image, pastes a screenshot, or you see `[Unsupported Image]` — you **MUST** call MCP `describe_image` or `extract_text` **BEFORE** answering. Do NOT use Read on binary images. Do NOT guess pixels.

| Situation | Tool | mode |
|-----------|------|------|
| General screenshot | `describe_image` | `general` |
| Error dialog / UI | `describe_image` | `ui` |
| Verbatim text | `extract_text` | — |
| Diagram | `describe_image` | `diagram` |
| Before/after | `compare_images` | — |

Example: `describe_image({ "source": "/abs/path.png", "mode": "ui" })`

Cached: `.ai/vision/*.md`
'@

$TPL_HOOKS = @'
{
  "enableAllProjectMcpServers": true,
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "node \"{{PROJECT_ROOT}}/scripts/cc-session-start.mjs\"",
            "timeout": 120000
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"{{PROJECT_ROOT}}/scripts/cc-session-end.mjs\"",
            "timeout": 120000
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node \"{{PROJECT_ROOT}}/scripts/cc-on-image-prompt.mjs\"",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
'@

$TPL_MCP = @'
{
  "mcpServers": {
    "ai-ship": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "ai-ship-mcp@latest"],
      "env": {
        "VISION_BRIDGE_BASE_URL": "https://api.moonshot.cn/v1",
        "VISION_BRIDGE_API_KEY": "${MOONSHOT_API_KEY}",
        "VISION_BRIDGE_MODELS": "kimi-k2.5,kimi-k2.6,moonshot-v1-8k-vision-preview",
        "VISION_BRIDGE_CACHE": "1"
      }
    }
  }
}
'@

$TPL_CC_START = @'
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const ai = join(root, ".ai");
const ctxFile = join(ai, "context.md");
const handoffFile = join(ai, "handoff.md");
const focusFile = join(ai, "focus.md");

const MAX_AGE_HOURS = 4;
const CTXSHOT_ARGS = ["--compact", "--diff", "--depth", "3", "--max", "120"];
const npxCmd = process.platform === "win32" ? "npx.cmd" : "npx";

// 优先用 CTXSHOT_CLI 指定的本地构建；否则回退到已发布的 npx ctxshot@latest
function runCtxshot(args) {
  const cli = process.env.CTXSHOT_CLI;
  if (cli && existsSync(cli)) {
    return spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: "utf8", windowsHide: true });
  }
  return spawnSync(npxCmd, ["--yes", "ctxshot@latest", ...args], { cwd: root, encoding: "utf8", windowsHide: true });
}

function readFile(path, label) {
  if (!existsSync(path)) return "";
  const body = readFileSync(path, "utf8").trim();
  if (!body) return "";
  return `\n\n## ${label}\n${body}`;
}

function extractHandoffGoals(md) {
  const m = md.match(/## (?:Goals|目标|下次继续|Next)[\s\S]*?(?=\n## |\n---|\Z)/i);
  return m ? m[0].trim() : "";
}

mkdirSync(ai, { recursive: true });

if (!existsSync(focusFile)) {
  writeFileSync(focusFile, "# 当前焦点\n\n_首次使用：在此写下「正在做什么」和「下次继续」。_\n", "utf8");
}

let needRefresh = !existsSync(ctxFile);
if (existsSync(ctxFile)) {
  const ageH = (Date.now() - statSync(ctxFile).mtimeMs) / 3600000;
  if (ageH >= MAX_AGE_HOURS) needRefresh = true;
}

if (needRefresh) {
  const r = runCtxshot([...CTXSHOT_ARGS, "-o", ".ai/context.md"]);
  if (r.status !== 0 && !existsSync(ctxFile)) {
    process.stderr.write(`ctxshot refresh failed: ${((r.stderr || r.stdout) || "").toString().slice(0, 200)}\n`);
  }
}

const handoffRaw = existsSync(handoffFile) ? readFileSync(handoffFile, "utf8") : "";
const handoffGoals = extractHandoffGoals(handoffRaw);

let context =
  "# Workspace memory (priority order)\n" +
  "1) focus.md = what we're doing NOW\n" +
  "2) handoff goals = last session intent\n" +
  "3) context.md = repo snapshot\n" +
  "Never ask user to run session_brief.\n";

context += readFile(focusFile, "CURRENT FOCUS (.ai/focus.md)");
if (handoffGoals) {
  context += `\n\n## LAST SESSION GOALS\n${handoffGoals}`;
} else {
  context += readFile(handoffFile, "HANDOFF (.ai/handoff.md)");
}
context += readFile(ctxFile, "PROJECT SNAPSHOT (.ai/context.md)");

process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: context.slice(0, 9800),
    },
  }),
);
'@

$TPL_CC_END = @'
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const ai = join(root, ".ai");
const out = join(ai, "handoff.md");
const focusFile = join(ai, "focus.md");
const npxCmd = process.platform === "win32" ? "npx.cmd" : "npx";

function runCtxshot(args) {
  const cli = process.env.CTXSHOT_CLI;
  const r = (cli && existsSync(cli))
    ? spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: "utf8", windowsHide: true })
    : spawnSync(npxCmd, ["--yes", "ctxshot@latest", ...args], { cwd: root, encoding: "utf8", windowsHide: true });
  return ((r.stdout || "") + (r.stderr || "")).trim();
}

function runGit(args) {
  const r = spawnSync("git", args, { cwd: root, encoding: "utf8", windowsHide: true });
  return ((r.stdout || "") + (r.stderr || "")).trim();
}

mkdirSync(ai, { recursive: true });

const ctx = runCtxshot(["--compact", "--diff", "--depth", "2", "--max", "60"]);
const status = runGit(["status", "-sb"]);
const log = runGit(["log", "-5", "--oneline"]);
const stamp = new Date().toISOString();

const focus = existsSync(focusFile) ? readFileSync(focusFile, "utf8").trim() : "_no focus.md_";

const md = `# Session handoff
updated: ${stamp}

## 目标 / 下次继续
> 关聊前把「正在做什么」写进 \`.ai/focus.md\`，此处会引用。

${focus}

## Git
\`\`\`
${status || "(no git)"}
\`\`\`

## Recent commits
\`\`\`
${log || "(no log)"}
\`\`\`

## Project brief (ctxshot)
${ctx || "(ctxshot unavailable)"}
`;

writeFileSync(out, md, "utf8");
process.stdout.write(
  JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "SessionEnd",
      additionalContext: `Handoff saved: .ai/handoff.md (${stamp})`,
    },
  }),
);
'@

$TPL_CC_IMG_MJS = @'
import { readFileSync } from "node:fs";

let inputRaw = "";
try {
  inputRaw = readFileSync(0, "utf8");
} catch {
  process.exit(0);
}
if (!inputRaw) process.exit(0);

const lower = inputRaw.toLowerCase();
const hasImage =
  /unsupported image|image\.png|image_url|\.png|\.jpg|\.jpeg|\.webp/.test(
    lower,
  );
if (!hasImage) process.exit(0);

process.stdout.write(`
## Vision auto-hint (UserPromptSubmit)
User sent image(s). DeepSeek cannot see pixels.
REQUIRED now:
1. sync_chat_attachments (multi-paste from IDE)
2. describe_paste_batch if 2+ images else describe_paste
3. Show image preview markdown from tool result to user
`);
'@

function Refresh-Path {
  $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user"
}

function Test-Command([string]$name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# 检测某 winget 包是否已安装
function Test-WingetInstalled([string]$Id) {
  $list = winget list --id $Id -e --accept-source-agreements 2>$null
  return [bool]($LASTEXITCODE -eq 0 -and ($list | Select-String -SimpleMatch $Id))
}

# 核心：装了就更新，没装才安装
function Ensure-WingetPackage {
  param(
    [string]$Id,
    [string]$Label
  )
  if (Test-WingetInstalled $Id) {
    Show-CheckBar "$Label 安装状态" 700
    Write-Host "  $Label 已安装 → 检查更新 ..."
    # 已安装则尝试升级；"无可用更新" 不算失败，照常继续
    winget upgrade --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity 2>$null | Out-Null
    Write-Ok "$Label 已是最新（或已更新）"
    Refresh-Path
    return
  }
  Write-Host "  安装 $Label ..."
  winget install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
  if ($LASTEXITCODE -ne 0) {
    throw "winget 安装失败: $Id (exit $LASTEXITCODE)"
  }
  Write-Ok "$Label 安装完成"
  Refresh-Path
}

# Node 版本号（主版本），未装返回 0
function Get-NodeMajor {
  if (-not (Test-Command node)) { return 0 }
  try {
    $v = (& node -v) -replace '[^\d.]', ''
    return [int]($v.Split('.')[0])
  } catch { return 0 }
}

# 解析「真正的 VS Code」可执行：PATH 上的 code 可能是 Cursor/其它编辑器抢占的，
# 装扩展/打开都必须用真 VS Code，否则扩展装进了别的编辑器、打开的也是别的窗口。
function Resolve-VsCode {
  $found = @()
  # 1) 注册表 vscode:// 处理器里的 Code.exe（最权威，URI 也用它）
  try {
    if (-not (Get-PSDrive HKCR -ErrorAction SilentlyContinue)) {
      New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
    }
    $h = (Get-ItemProperty "HKCR:\vscode\shell\open\command" -ErrorAction SilentlyContinue).'(default)'
    if ($h -and $h -match '"([^"]+Code\.exe)"') {
      $bin = Join-Path (Split-Path $matches[1]) "bin\code.cmd"
      if (Test-Path $bin) { $found += $bin }
    }
  } catch { }
  # 2) 常见安装路径
  $cands = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"),
    (Join-Path $env:ProgramFiles "Microsoft VS Code\bin\code.cmd")
  )
  if (${env:ProgramFiles(x86)}) { $cands += (Join-Path ${env:ProgramFiles(x86)} "Microsoft VS Code\bin\code.cmd") }
  foreach ($c in $cands) { if ($c -and (Test-Path $c)) { $found += $c } }
  # 3) PATH 上的 code，但必须确属 Microsoft VS Code（排除 Cursor 等）
  $g = Get-Command code -ErrorAction SilentlyContinue
  if ($g -and $g.Source -match 'Microsoft VS Code') { $found += $g.Source }
  if ($found.Count -gt 0) { return $found[0] }
  return $null
}

# 由 code.cmd 路径推出 Code.exe（…\Microsoft VS Code\bin\code.cmd → …\Microsoft VS Code\Code.exe）
function Resolve-VsCodeExe([string]$CodeCmd) {
  if (-not $CodeCmd) { return $null }
  $installDir = Split-Path -Parent (Split-Path -Parent $CodeCmd)
  $exe = Join-Path $installDir "Code.exe"
  if (Test-Path $exe) { return $exe }
  return $null
}

# 查 code 已装扩展列表（本地、无网络、秒回）。失败返回空数组。
function Get-VsCodeExtensions([string]$CodeCmd) {
  try {
    $list = & { $ErrorActionPreference = 'Continue'; & $CodeCmd --list-extensions 2>$null }
    return @($list)
  } catch { return @() }
}

# 用「真 VS Code」装扩展：先查本地是否已装（已装秒回，避免 --force 联网校验卡死），
# 没装才带超时 + 心跳点下载，网络不通时绝不无限等待。返回 "ok" / "timeout" / "fail"。
function Install-VsCodeExtension([string]$CodeCmd, [string]$Ext, [int]$TimeoutSec = 180) {
  # 1) 已装直接成功（不联网）—— 这是「明明装过却卡在下载」的根治
  if ((Get-VsCodeExtensions $CodeCmd) -contains $Ext) {
    Show-CheckBar "VS Code 扩展 $Ext" 700
    return "ok"
  }

  $out = [System.IO.Path]::GetTempFileName()
  $err = [System.IO.Path]::GetTempFileName()
  try {
    # 2) 没装才下载（带超时）
    $p = Start-Process -FilePath $CodeCmd `
      -ArgumentList @("--install-extension", $Ext, "--force") `
      -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $elapsed = 0
    $exited = $false
    while ($elapsed -lt $TimeoutSec) {
      if ($p.WaitForExit(2000)) { $exited = $true; break }
      $elapsed += 2
      Write-Host "." -NoNewline -ForegroundColor DarkGray
    }
    Write-Host ""
    if (-not $exited) {
      # 杀整棵进程树（code.cmd 会派生 node 子进程，单杀父进程会留下僵尸子进程）
      & cmd /c "taskkill /PID $($p.Id) /T /F" 2>&1 | Out-Null
    }
    # 3) 以本地 list-extensions 为准（Start-Process -PassThru 的 .ExitCode 在 PS5.1 常为 null 不可靠）
    if ((Get-VsCodeExtensions $CodeCmd) -contains $Ext) { return "ok" }
    if (-not $exited) { return "timeout" }
    return "fail"
  } catch {
    return "fail"
  } finally {
    Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue
  }
}

# 在桌面创建快捷方式（winget 静默装常不建图标，这里补一个，方便用户直接双击打开）
function New-DesktopShortcut([string]$TargetExe, [string]$Name) {
  try {
    if (-not $TargetExe -or -not (Test-Path $TargetExe)) { return $false }
    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not $desktop) { return $false }
    $lnk = Join-Path $desktop "$Name.lnk"
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnk)
    $sc.TargetPath = $TargetExe
    $sc.WorkingDirectory = Split-Path -Parent $TargetExe
    $sc.Description = $Name
    $sc.Save()
    return $true
  } catch { return $false }
}

# Claude Code：检测优先（可能是 npm 装的），装了就更新，没装才安装
function Ensure-ClaudeCode {
  if (Test-Command claude) {
    Show-CheckBar "Claude Code CLI" 700
    Write-Host "  Claude Code 已安装 → 尝试更新 ..."
    # 原生安装器支持 self-update；npm 版则忽略失败
    try { & claude update 2>&1 | Out-Null } catch { }
    try {
      $loc = (Get-Command claude).Source
      if ($loc -match 'npm|node_modules') {
        & npm.cmd update -g "@anthropic-ai/claude-code" 2>&1 | Out-Null
      }
    } catch { }
    Refresh-Path
    Write-Ok "Claude Code 已安装（已尝试更新）"
    return
  }
  Write-Host "  安装 Claude Code CLI ..."
  try {
    winget install --id Anthropic.ClaudeCode -e --accept-package-agreements --accept-source-agreements --disable-interactivity
    Refresh-Path
  } catch {
    Write-Warn "winget 安装 Claude Code 失败，改用官方 install.ps1 ..."
    Invoke-RestMethod -Uri "https://claude.ai/install.ps1" -UseBasicParsing | Invoke-Expression
    Refresh-Path
  }
  if (Test-Command claude) {
    Write-Ok "Claude Code CLI 可用"
  } else {
    Write-Warn "Claude Code CLI 未进 PATH，VS Code 扩展自带 CLI 仍可用"
  }
}

# 隐藏式读取：屏幕上不显示明文（录视频不怕被还原马赛克）
function Read-SecureText([string]$Prompt) {
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  if (-not $sec -or $sec.Length -eq 0) { return "" }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try {
    return ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)).Trim()
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Read-ApiKey {
  param(
    [string]$Prompt,
    [string]$Existing = "",
    [switch]$Optional
  )
  if ($Existing) {
    $v = Read-SecureText "$Prompt 已存在，按 Enter 保留 / 输入新 Key 覆盖（输入已隐藏）"
    if (-not $v) { return $Existing }
    return $v
  }
  if ($Optional) {
    $v = Read-SecureText "$Prompt（可选，直接 Enter 跳过看图功能；输入已隐藏）"
    return $v
  }
  do {
    $v = Read-SecureText "$Prompt（必填，输入已隐藏）"
  } while (-not $v)
  return $v
}

function Write-JsonFile([string]$path, [object]$obj) {
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $json = $obj | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# npm/npx 偶尔抽风（网络），失败自动重试
function Invoke-WithRetry {
  param(
    [scriptblock]$Action,
    [int]$Max = 3,
    [string]$Label = "命令"
  )
  # npx/ctxshot 常往 stderr 写普通日志；StrictMode+Stop 下会被当致命错误。
  # 这里局部降级，避免 stderr 输出导致整个脚本崩溃。
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
  for ($i = 1; $i -le $Max; $i++) {
    & $Action
    if ($LASTEXITCODE -eq 0) { return $true }
    if ($i -lt $Max) {
      Write-Warn "$Label 第 $i/$Max 次失败 (exit $LASTEXITCODE)，3 秒后重试 ..."
      Start-Sleep -Seconds 3
    }
  }
  Write-Warn "$Label 重试 $Max 次仍失败"
  return $false
  } finally {
    $ErrorActionPreference = $prev
  }
}

# ─── 管理员提权（装系统组件需要；UAC 取消则降级继续）──────
if (-not $SkipSystemInstall -and -not (Test-Admin)) {
  if ($SelfPath) {
    # 以本地文件运行：可直接带参数重新提权启动
    Write-Host ""
    Write-Host "  需要管理员权限安装系统组件，正在请求提权（弹 UAC 请点「是」）..." -ForegroundColor Yellow
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$SelfPath`"")
    if ($ProjectPath)     { $argList += @("-ProjectPath", "`"$ProjectPath`"") }
    if (-not $OpenVsCode) { $argList += "-OpenVsCode:`$false" }
    try {
      Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs -ErrorAction Stop
      exit 0
    } catch {
      Write-Warn "提权被取消，将以普通权限继续（winget 安装/更新可能受限）"
    }
  } else {
    # 管道运行（irm | iex）无文件可重启，提示用户用管理员 PowerShell 重跑
    Write-Warn "当前非管理员。装系统组件建议右键「以管理员身份运行 PowerShell」后再执行本命令。"
    Write-Warn "将以普通权限继续（winget 多数包支持用户级安装）。"
  }
}

# ─── Banner ───────────────────────────────────────────
Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  AI Ship IDE 一键安装" -ForegroundColor Magenta
Write-Host "  VS Code + Claude Code + DeepSeek + ai-ship-mcp" -ForegroundColor Magenta
Write-Host "  不需要 ccSwitch" -ForegroundColor Magenta
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  项目目录: $ProjectPath"

# ═══════════════════════════════════════════════════════
# 1. 系统依赖
# ═══════════════════════════════════════════════════════
if (-not $SkipSystemInstall) {
  Write-Step "1/6" "检测并安装/更新系统依赖 (Node / Git / VS Code / Claude Code)"

  if (-not (Test-Command winget)) {
    throw "未找到 winget。请从 Microsoft Store 安装「应用安装程序」后重试。"
  }

  # ── Node：检测版本，<18 或未装则装，已装够新则更新 ──
  $nodeMajor = Get-NodeMajor
  if ($nodeMajor -eq 0) {
    Write-Host "  未检测到 Node，安装 Node.js LTS ..."
    Ensure-WingetPackage -Id "OpenJS.NodeJS.LTS" -Label "Node.js LTS"
  } elseif ($nodeMajor -lt 18) {
    Write-Warn "Node 版本过低 (v$nodeMajor)，升级到 LTS ..."
    Ensure-WingetPackage -Id "OpenJS.NodeJS.LTS" -Label "Node.js LTS"
  } else {
    Show-CheckBar "Node $(node -v)" 700
    Write-Ok "Node 已安装且够新，跳过"
  }
  Refresh-Path
  if (-not (Test-Command node)) { throw "Node 安装后仍不可用，请重开终端再跑脚本。" }

  # ── Git / VS Code：装了就更新，没装才安装 ──
  Ensure-WingetPackage -Id "Git.Git" -Label "Git"
  Ensure-WingetPackage -Id "Microsoft.VisualStudioCode" -Label "Visual Studio Code"

  # ── Claude Code：检测优先（可能 npm 装的），装了更新/没装安装 ──
  Ensure-ClaudeCode

  # ── VS Code 扩展：用「真 VS Code」装，避免装进 Cursor 等 ──
  $VsCodeCmd = Resolve-VsCode
  if ($VsCodeCmd) {
    Write-Host "  安装/更新 VS Code 扩展 anthropic.claude-code（最多等 180 秒，点号=进行中）..."
    # 需联网从扩展市场下载；网络不通会卡死，故用 Start-Process + 超时 + 心跳，绝不无限等待
    $extResult = Install-VsCodeExtension $VsCodeCmd "anthropic.claude-code" 180
    switch ($extResult) {
      "ok"      { Write-Ok "Claude Code 扩展已安装/更新（VS Code: $VsCodeCmd）" }
      "timeout" { Write-Warn "扩展下载超时（多为网络/代理不通），已跳过。联网后在 VS Code 扩展市场搜 Claude Code 手动装" }
      default   { Write-Warn "扩展安装失败（多为网络问题），已跳过。联网后在 VS Code 扩展市场搜 Claude Code 手动装" }
    }
  } else {
    Write-Warn "未找到真正的 VS Code（PATH 上的 code 可能是 Cursor）。请确认已装 VS Code 后手动装 Claude Code 扩展"
  }

  # ── VS Code 用户设置：消除「信任弹窗 / 受限模式 / 首启打扰」──
  Set-VsCodeUserSettings $UserVsCodeSettings
  Write-Ok "VS Code 已关闭工作区信任弹窗等首启打扰（打开即可用）"

  # ── 桌面快捷方式（winget 静默装通常不建图标，这里补上）──
  $codeExe = Resolve-VsCodeExe $VsCodeCmd
  if (New-DesktopShortcut $codeExe "Visual Studio Code") {
    Write-Ok "已在桌面创建 VS Code 快捷方式"
  } else {
    Write-Skip "未创建桌面快捷方式（不影响使用，可从开始菜单打开 VS Code）"
  }
} else {
  Write-Step "1/6" "跳过系统安装 (-SkipSystemInstall)"
}

# ═══════════════════════════════════════════════════════
# 2. API Key（唯一需要手输入的部分）
# ═══════════════════════════════════════════════════════
Write-Step "2/6" "配置 API Key（DeepSeek 写代码 + Moonshot 看图）"

$existingDeepseek = ""
$existingMoonshot = [Environment]::GetEnvironmentVariable("MOONSHOT_API_KEY", "User")
if (Test-Path $UserClaudeSettings) {
  try {
    $old = Get-Content $UserClaudeSettings -Raw -Encoding UTF8 | ConvertFrom-Json
    # StrictMode 下旧文件若无 env 字段，直接点属性会抛错；先判属性存在再取，避免丢失已有 Key
    $oldEnv = $old.PSObject.Properties['env']
    if ($oldEnv -and $oldEnv.Value) {
      $envProps = $oldEnv.Value.PSObject.Properties
      $tok = $envProps['ANTHROPIC_AUTH_TOKEN']
      if ($tok -and $tok.Value) { $existingDeepseek = $tok.Value }
      $msk = $envProps['MOONSHOT_API_KEY']
      if ($msk -and $msk.Value) { $existingMoonshot = $msk.Value }
    }
  } catch { }
}

if ($DeepseekKey) {
  $deepseekKey = $DeepseekKey.Trim()
  Write-Skip "DeepSeek Key 由参数传入"
} else {
  Write-Host ""
  Write-Host "  获取 DeepSeek Key: https://platform.deepseek.com/" -ForegroundColor DarkGray
  $deepseekKey = Read-ApiKey -Prompt "DeepSeek API Key" -Existing $existingDeepseek
}

if ($MoonshotKey) {
  $moonshotKey = $MoonshotKey.Trim()
  Write-Skip "Moonshot Key 由参数传入"
} else {
  Write-Host ""
  Write-Host "  获取 Moonshot/Kimi Key: https://platform.moonshot.cn/ （贴图识图用）" -ForegroundColor DarkGray
  $moonshotKey = Read-ApiKey -Prompt "Moonshot API Key" -Existing $existingMoonshot -Optional
}

# ═══════════════════════════════════════════════════════
# 3. 用户级 Claude Code + DeepSeek（替代 ccSwitch）
# ═══════════════════════════════════════════════════════
Write-Step "3/6" "写入用户配置 ~/.claude/settings.json（DeepSeek 直连，无需 ccSwitch）"

$userSettings = @{
  env = @{
    ANTHROPIC_BASE_URL = "https://api.deepseek.com/anthropic"
    ANTHROPIC_AUTH_TOKEN = $deepseekKey
    ANTHROPIC_MODEL = "deepseek-v4-pro[1m]"
    ANTHROPIC_DEFAULT_OPUS_MODEL = "deepseek-v4-pro[1m]"
    ANTHROPIC_DEFAULT_SONNET_MODEL = "deepseek-v4-pro[1m]"
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "deepseek-v4-flash"
    CLAUDE_CODE_SUBAGENT_MODEL = "deepseek-v4-flash"
    CLAUDE_CODE_EFFORT_LEVEL = "max"
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
    CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK = "1"
    COLORTERM = "truecolor"
    TERM = "xterm-256color"
    FORCE_COLOR = "1"
  }
  enableAllProjectMcpServers = $true
  hasCompletedOnboarding = $true
  theme = "custom:claude-brand"
}

if ($moonshotKey) {
  $userSettings.env.MOONSHOT_API_KEY = $moonshotKey
  if (-not $ClaudeSettingsPath) {
    # 仅正式运行才写真实用户环境变量（测试重定向时不污染）
    [Environment]::SetEnvironmentVariable("MOONSHOT_API_KEY", $moonshotKey, "User")
    $env:MOONSHOT_API_KEY = $moonshotKey
    Write-Ok "MOONSHOT_API_KEY 已写入用户环境变量"
  } else {
    Write-Skip "测试模式：跳过写用户环境变量"
  }
} else {
  Write-Warn "未配置 Moonshot Key，贴图识图 MCP 可能不可用"
}

if (Test-Path $UserClaudeSettings) {
  # 覆盖前先备份现有配置（保留你已有的 Key / 自定义项）
  $backup = "$UserClaudeSettings.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  Copy-Item -LiteralPath $UserClaudeSettings -Destination $backup -Force
  Write-Skip "已备份原配置 → $([System.IO.Path]::GetFileName($backup))"
  try {
    $oldHt = @{}
    $oldObj = Get-Content $UserClaudeSettings -Raw -Encoding UTF8 | ConvertFrom-Json
    $oldObj.PSObject.Properties | ForEach-Object { $oldHt[$_.Name] = $_.Value }
    if ($oldHt["env"]) {
      $envHt = @{}
      $oldHt["env"].PSObject.Properties | ForEach-Object { $envHt[$_.Name] = $_.Value }
      foreach ($k in $userSettings.env.Keys) { $envHt[$k] = $userSettings.env[$k] }
      $oldHt["env"] = $envHt
    } else {
      $oldHt["env"] = $userSettings.env
    }
    $oldHt["enableAllProjectMcpServers"] = $true
    $oldHt["hasCompletedOnboarding"] = $true
    $oldHt["theme"] = "custom:claude-brand"
    Write-JsonFile $UserClaudeSettings $oldHt
  } catch {
    Write-JsonFile $UserClaudeSettings $userSettings
  }
} else {
  Write-JsonFile $UserClaudeSettings $userSettings
}
Write-Ok "DeepSeek 模型配置完成（主模型 deepseek-v4-pro，子任务 deepseek-v4-flash）"

# Claude 终端真彩色 + 橙色品牌主题 + WT 配置
$setupTerminal = Join-Path $SelfPath "Setup-ClaudeTerminal.ps1"
if (-not (Test-Path $setupTerminal) -and $SelfPath) {
  $setupTerminal = Join-Path (Split-Path -Parent $SelfPath) "Setup-ClaudeTerminal.ps1"
}
if (Test-Path $setupTerminal) {
  Write-Host "  配置 Claude 终端橙色主题 ..."
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setupTerminal -ProjectPath $ProjectPath -PackageRoot (Split-Path -Parent $setupTerminal) 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
} else {
  # 内联：至少写入主题文件
  $themesDir = Join-Path $UserClaudeDir "themes"
  New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
  $themePath = Join-Path $themesDir "claude-brand.json"
  if (-not (Test-Path $themePath)) {
    Write-TextFile $themePath '{"name":"Claude 官方橙","base":"dark","overrides":{"claude":"#D97757","claudeShimmer":"#E8956F","permission":"#D97757","permissionShimmer":"#E8956F","promptBorder":"#D97757","promptBorderShimmer":"#E8956F"}}'
    Write-Ok "Claude 官方橙主题已写入 ~/.claude/themes/"
  }
}

# ═══════════════════════════════════════════════════════
# 4. 项目级核心配置：记忆 Hook + MCP + CLAUDE.md（先写，保证不依赖网络）
# ═══════════════════════════════════════════════════════
Write-Step "4/6" "配置项目核心 Hook / MCP / CLAUDE.md: $ProjectPath"

$projScripts = Join-Path $ProjectPath "scripts"
$projAi = Join-Path $ProjectPath ".ai"
$projClaude = Join-Path $ProjectPath ".claude"
New-Item -ItemType Directory -Path $projScripts -Force | Out-Null
New-Item -ItemType Directory -Path $projAi -Force | Out-Null
New-Item -ItemType Directory -Path $projClaude -Force | Out-Null

# Hook 脚本（内联模板）
Write-TextFile (Join-Path $projScripts "cc-session-start.mjs") $TPL_CC_START
Write-TextFile (Join-Path $projScripts "cc-session-end.mjs") $TPL_CC_END
Write-TextFile (Join-Path $projScripts "cc-on-image-prompt.mjs") $TPL_CC_IMG_MJS
Write-Ok "SessionStart/End + 贴图 Hook 已安装"

# .claude/settings.json（项目 Hook）
$rootEsc = $ProjectPath.Replace("\", "\\")
$hooksJson = $TPL_HOOKS.Replace("{{PROJECT_ROOT}}", $rootEsc)
Write-TextFile (Join-Path $projClaude "settings.json") $hooksJson
Write-Ok ".claude/settings.json 已生成"

# .mcp.json（合一 MCP）
Write-TextFile (Join-Path $ProjectPath ".mcp.json") $TPL_MCP
# Cursor 也写一份
$cursorDir = Join-Path $ProjectPath ".cursor"
New-Item -ItemType Directory -Path $cursorDir -Force | Out-Null
Write-TextFile (Join-Path $cursorDir "mcp.json") $TPL_MCP
Write-Ok ".mcp.json 已配置 ai-ship-mcp（记忆+看图合一）"

# .claude/settings.local.json — Windows 上 .mcp.json 必须配套此文件才会加载 MCP
# （见 anthropics/claude-code #9461：需 enabledMcpjsonServers + 权限放行）
$localSettings = @{
  enableAllProjectMcpServers = $true
  enabledMcpjsonServers = @("ai-ship")
  permissions = @{
    allow = @("mcp__ai-ship__*")
    deny = @()
  }
}
Write-JsonFile (Join-Path $projClaude "settings.local.json") $localSettings
Write-Ok ".claude/settings.local.json 已生成（确保 Windows 加载 MCP）"

# CLAUDE.md
$projName = Split-Path -Leaf $ProjectPath
$claudeMd = $TPL_MEMORY.Replace("{{PROJECT_NAME}}", $projName) + "`n`n" + $TPL_VISION.Trim() + "`n"
$claudePath = Join-Path $ProjectPath "CLAUDE.md"
if (Test-Path $claudePath) {
  $existing = Get-Content $claudePath -Raw -Encoding UTF8
  if ($existing -notmatch "@\.ai/focus\.md") {
    $claudeMd = $claudeMd + "`n---`n`n" + $existing.Trim() + "`n"
  } else {
    Write-Skip "CLAUDE.md 已有记忆 @import，保留原文件"
    $claudeMd = $null
  }
}
if ($claudeMd) {
  [System.IO.File]::WriteAllText($claudePath, $claudeMd, [System.Text.UTF8Encoding]::new($false))
  Write-Ok "CLAUDE.md 已生成（记忆三层 + 看图规则）"
}

# focus.md
$focusPath = Join-Path $projAi "focus.md"
if (-not (Test-Path $focusPath)) {
  @"
# 当前焦点

> 在此写「正在做什么」和「下次继续」。关聊前说「更新 focus」让 Claude 帮你写。

## 正在做

- （填写当前任务）

## 下次继续

1. 
"@ | Set-Content -LiteralPath $focusPath -Encoding UTF8
  Write-Ok ".ai/focus.md 已创建"
}

# .gitignore
$gi = Join-Path $ProjectPath ".gitignore"
$giLine = ".ai/"
if (Test-Path $gi) {
  $giContent = Get-Content $gi -Raw -Encoding UTF8
  if ($giContent -notmatch [regex]::Escape($giLine)) {
    Add-Content -LiteralPath $gi -Value "`n# ai-ship session memory`n.ai/`n" -Encoding UTF8
  }
} else {
  Set-Content -LiteralPath $gi -Value "# ai-ship session memory`n.ai/`n" -Encoding UTF8
}

# ═══════════════════════════════════════════════════════
# 5. ship-skills Skills + 首份 context（可选增强，失败不影响核心）
# ═══════════════════════════════════════════════════════
Write-Step "5/6" "安装 Agent Skills + 生成首份 context.md（可选）"

Push-Location $ProjectPath
try {
  Write-Host "  npx ship-skills@latest init --skip-eval ..."
  $ok = Invoke-WithRetry -Label "ship-skills init" -Action {
    & npx.cmd --yes ship-skills@latest init --skip-eval 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
  }
  if (-not $ok) {
    Write-Warn "ship-skills init 失败，改用手动 ctxshot 生成 context ..."
    Invoke-WithRetry -Label "ctxshot" -Action {
      & npx.cmd --yes ctxshot@latest --compact --diff --depth 3 --max 120 -o .ai/context.md 2>&1 | Out-Null
    } | Out-Null
  }
  if (Test-Path ".ai/context.md") {
    Write-Ok ".ai/context.md 已生成"
  } else {
    Write-Warn "context.md 未生成（不影响使用），开聊后说「刷新 context」即可"
  }
} finally {
  Pop-Location
}

# ═══════════════════════════════════════════════════════
# 6. 预热 MCP + 完成
# ═══════════════════════════════════════════════════════
Write-Step "6/6" "预热 npm 包（首次开聊更快）"

# 注意：ai-ship-mcp 是 stdio MCP 服务器，直接 `npx ... --version` 会启动并等待 stdin 而永久挂起。
# 因此预热只用 `npm cache add` 把 tarball 下进缓存（不执行服务器），并加超时兜底。
function Invoke-Prewarm {
  param([string]$Spec, [int]$TimeoutSec = 90)
  $job = Start-Job -ScriptBlock {
    param($s)
    & npm.cmd cache add $s 2>&1 | Out-Null
  } -ArgumentList $Spec
  if (Wait-Job $job -Timeout $TimeoutSec) {
    Receive-Job $job | Out-Null
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return $true
  } else {
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    return $false
  }
}

$warm1 = Invoke-Prewarm "ai-ship-mcp@latest"
$warm2 = Invoke-Prewarm "ctxshot@latest"
if ($warm1 -and $warm2) {
  Write-Ok "ai-ship-mcp / ctxshot 已缓存（首次开聊更快）"
} else {
  Write-Skip "预热超时已跳过（不影响使用，首次开聊会自动下载）"
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  全部就绪，正在自动打开 VS Code 并切到 Claude Code 对话框..." -ForegroundColor White
Write-Host ""
Write-Host "  打开后若有弹窗：@import 授权点「允许」即可（仅一次）" -ForegroundColor DarkGray
Write-Host "  不需要 ccSwitch / 不需要登录 — DeepSeek 已在 ~/.claude/settings.json 配好" -ForegroundColor DarkGray
Write-Host "  主模型: deepseek-v4-pro[1m]  |  看图: Moonshot/Kimi 旁路" -ForegroundColor DarkGray
Write-Host "  快捷键：Ctrl+Esc 在编辑器和 Claude 输入框间切换" -ForegroundColor DarkGray
Write-Host ""

$VsCodeOpen = Resolve-VsCode
if ($OpenVsCode -and $VsCodeOpen) {
  Write-Host "  正在打开 VS Code ..."
  # 1) 先用「真 VS Code」打开项目文件夹（建立工作区上下文：记忆 Hook / MCP / CLAUDE.md 都依赖它）
  & { $ErrorActionPreference = 'Continue'; & $VsCodeOpen -n "$ProjectPath" 2>&1 | Out-Null }
  # 2) 等窗口与扩展就绪，再用官方 URI 处理器打开 Claude Code 标签并预填欢迎语（不自动发送）
  #    见 https://code.claude.com/docs/en/ide-integrations （vscode://anthropic.claude-code/open）
  Start-Sleep -Seconds 6
  $welcome = "你好！请先读 .ai/focus.md 和 CLAUDE.md 了解项目，然后告诉我你想做什么。"
  $enc = [uri]::EscapeDataString($welcome)
  $claudeUri = "vscode://anthropic.claude-code/open?prompt=$enc"
  try {
    Start-Process $claudeUri -ErrorAction Stop
    Write-Ok "已自动打开 Claude Code 对话框（输入框已就绪）"
  } catch {
    Write-Warn "自动聚焦失败，请在 VS Code 里按 Ctrl+Esc 或点左侧 Claude 图标开聊"
  }
} elseif ($OpenVsCode) {
  Write-Warn "未找到 VS Code，跳过自动打开。装好 VS Code 后重跑即可。"
}
