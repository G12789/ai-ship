#Requires -Version 5.1
<#
.SYNOPSIS
  Codex 一键安装：Node/Git/VS Code + Codex CLI(终端版) + Codex IDE 插件
  支持两种模型来源（装时可选）：
    - 国产：DeepSeek 写代码 + Kimi 自动识图（经本地 @codeproxy/cli 协议代理）
    - 官方：原生 gpt-5.x（用 ChatGPT 账号登录，需订阅）

.DESCRIPTION
  Codex 0.128+ 只认 OpenAI Responses 协议，DeepSeek/Kimi 是 Chat Completions，
  走国产时必须经本地 @codeproxy/cli 翻译；IDE 插件(openai.chatgpt)与 CLI 共用
  ~/.codex/config.toml，故同一套配置终端与插件都生效（插件里贴图自动转 Kimi）。

.EXAMPLE
  irm https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.ps1 | iex

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install-codex.ps1 -SkipSystemInstall -Source domestic
#>
param(
  [switch]$SkipSystemInstall,
  [ValidateSet("", "domestic", "official")]
  [string]$Source = "",
  [string]$DeepseekKey = "",
  [string]$KimiKey = "",
  [string]$OutputDir = "",
  [switch]$NoExtension
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch { }
if (-not $env:npm_config_registry) { $env:npm_config_registry = "https://registry.npmmirror.com" }

$CodexDir = Join-Path $env:USERPROFILE ".codex"
$CodexConfig = Join-Path $CodexDir "config.toml"
$CodexAuth = Join-Path $CodexDir "auth.json"
if (-not $OutputDir) { $OutputDir = (Get-Location).Path }
$ProxyConfig = Join-Path $OutputDir "codeproxy.config.json"
$ProxyPort = 8787
$CodexExtId = "openai.chatgpt"

function Write-Step([string]$n, [string]$m) { Write-Host ""; Write-Host "[$n] $m" -ForegroundColor Cyan }
function Write-Ok([string]$m) { Write-Host "  OK  $m" -ForegroundColor Green }
function Write-Skip([string]$m) { Write-Host "  --  $m" -ForegroundColor DarkGray }
$script:InstallWarnings = @()
function Write-Warn([string]$m) { Write-Host "  !!  $m" -ForegroundColor Yellow; $script:InstallWarnings += $m }

function Refresh-Path {
  $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user"
}
function Test-Command([string]$n) { return [bool](Get-Command $n -ErrorAction SilentlyContinue) }

function Test-WingetInstalled([string]$Id) {
  $list = winget list --id $Id -e --accept-source-agreements 2>$null
  return [bool]($LASTEXITCODE -eq 0 -and ($list | Select-String -SimpleMatch $Id))
}
function Ensure-WingetPackage([string]$Id, [string]$Label) {
  if (Test-WingetInstalled $Id) {
    Write-Host "  $Label 已安装 → 检查更新 ..."
    winget upgrade --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity 2>$null | Out-Null
    Write-Ok "$Label 已是最新（或已更新）"; Refresh-Path; return
  }
  Write-Host "  安装 $Label ..."
  winget install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity
  if ($LASTEXITCODE -ne 0) { throw "winget 安装失败: $Id (exit $LASTEXITCODE)" }
  Write-Ok "$Label 安装完成"; Refresh-Path
}
function Get-NodeMajor {
  if (-not (Test-Command node)) { return 0 }
  try { $v = (& node -v) -replace '[^\d.]', ''; return [int]($v.Split('.')[0]) } catch { return 0 }
}

# npm 全局安装带重试 + 非致命：网络抖动(ECONNRESET 等)不再中断整个安装。
# $ErrorActionPreference=Stop 下 npm 往 stderr 写东西会被当成终止错误，这里临时降级。
function Invoke-NpmInstall([string]$Pkg, [string]$Label) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $okFlag = $false
  for ($i = 1; $i -le 3; $i++) {
    try {
      & npm.cmd install -g $Pkg 2>&1 | Out-Null
      if ($LASTEXITCODE -eq 0) { $okFlag = $true; break }
    } catch { }
    if ($i -lt 3) { Write-Host "  $Label 第 $i 次未成功（多为网络抖动），重试 ..." -ForegroundColor DarkGray; Start-Sleep -Seconds 2 }
  }
  $ErrorActionPreference = $prev
  return $okFlag
}

function Read-SecureText([string]$Prompt) {
  $sec = Read-Host -Prompt $Prompt -AsSecureString
  if (-not $sec -or $sec.Length -eq 0) { return "" }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  try { return ([Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)).Trim() }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
function Read-ApiKey([string]$Prompt, [string]$Existing = "", [switch]$Optional) {
  if ($Existing) {
    $v = Read-SecureText "$Prompt 已存在，Enter 保留 / 输入新 Key 覆盖（输入已隐藏）"
    if (-not $v) { return $Existing }
    return $v
  }
  if ($Optional) { return (Read-SecureText "$Prompt（可选，Enter 跳过识图；输入已隐藏）") }
  do { $v = Read-SecureText "$Prompt（必填，输入已隐藏）" } while (-not $v)
  return $v
}
function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Write-TextFile([string]$Path, [string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

# 把 Codex IDE 插件装到检测到的所有受支持编辑器（VS Code / Cursor / Windsurf）
function Install-CodexExtension {
  if ($NoExtension) { Write-Skip "已指定 -NoExtension，跳过 IDE 插件"; return }
  $installed = $false
  $prev = $ErrorActionPreference
  # code/cursor 底层是 node，启动常往 stderr 打 DeprecationWarning，那不是错误。
  # 降级 EAP 避免被当成终止异常，最后用 --list-extensions 校验是否真的装上。
  $ErrorActionPreference = "Continue"
  foreach ($cli in @("code", "cursor", "windsurf", "code-insiders")) {
    if (Test-Command $cli) {
      & $cli --install-extension $CodexExtId --force 2>&1 | Out-Null
      $list = (& $cli --list-extensions 2>$null)
      if ($list -and ($list -join "`n") -match [regex]::Escape($CodexExtId)) {
        Write-Ok "Codex 插件已装入 $cli（侧边栏可贴图）"
        $installed = $true
      } else {
        Write-Skip "$cli 装插件未确认，可在扩展面板搜「Codex」(OpenAI) 手动装"
      }
    }
  }
  $ErrorActionPreference = $prev
  if (-not $installed) {
    Write-Skip "未检测到 code/cursor 命令行 → 在 IDE 扩展面板搜「Codex」(发布者 OpenAI) 手动安装"
  }
}

# ─── 选择模型来源 ───────────────────────────────────────
function Resolve-Source {
  if ($Source) { return $Source }
  if ($DeepseekKey) { return "domestic" }
  Write-Host ""
  Write-Host "  选择模型来源：" -ForegroundColor White
  Write-Host "    [1] 国产 DeepSeek 写代码 + Kimi 识图（便宜，国内无 VPN 可用）  ← 默认" -ForegroundColor Gray
  Write-Host "    [2] 官方原生 gpt-5.x（用 ChatGPT 账号登录，需订阅 + 通常需梯子）" -ForegroundColor Gray
  $c = Read-Host "  输入 1 或 2（直接 Enter = 1）"
  if ($c -eq "2") { return "official" }
  return "domestic"
}

# ─── 提权 ───────────────────────────────────────────────
if (-not $SkipSystemInstall -and -not (Test-Admin)) {
  $self = if ($PSCommandPath) { $PSCommandPath } else { $null }
  if ($self) {
    Write-Host "  需要管理员权限装系统组件，正在请求提权（弹 UAC 点是）..." -ForegroundColor Yellow
    try {
      $argList = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$self`"","-OutputDir","`"$OutputDir`"")
      if ($Source) { $argList += @("-Source", $Source) }
      if ($NoExtension) { $argList += "-NoExtension" }
      Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -ErrorAction Stop
      exit 0
    } catch { Write-Warn "提权取消，以普通权限继续（winget 用户级安装多数可用）" }
  } else {
    Write-Warn "非管理员、管道运行。建议用管理员 PowerShell 重跑；现以普通权限继续。"
  }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  Codex 一键安装（CLI 终端版 + IDE 插件）" -ForegroundColor Magenta
Write-Host "  Node + Git + VS Code + Codex + 模型接入" -ForegroundColor Magenta
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  配置输出目录: $OutputDir"

$Source = Resolve-Source
if ($Source -eq "official") {
  Write-Host "  模型来源：官方原生 gpt-5.x（ChatGPT 登录）" -ForegroundColor Yellow
} else {
  Write-Host "  模型来源：国产 DeepSeek + Kimi（本地代理）" -ForegroundColor Yellow
}

# ═══ 1. 系统依赖 ═══
if (-not $SkipSystemInstall) {
  Write-Step "1/6" "检测并安装系统依赖 (Node / Git / VS Code)"
  if (-not (Test-Command winget)) { throw "未找到 winget，请先从 Microsoft Store 装「应用安装程序」。" }
  $nm = Get-NodeMajor
  if ($nm -lt 18) { Ensure-WingetPackage "OpenJS.NodeJS.LTS" "Node.js LTS" } else { Write-Ok "Node $(node -v) 已够新" }
  Refresh-Path
  if (-not (Test-Command node)) { throw "Node 安装后仍不可用，请重开终端再跑。" }
  Ensure-WingetPackage "Git.Git" "Git"
  Ensure-WingetPackage "Microsoft.VisualStudioCode" "Visual Studio Code"
} else {
  Write-Step "1/6" "跳过系统安装 (-SkipSystemInstall)"; Refresh-Path
}

# ═══ 2. Codex CLI（国产再装代理）═══
Write-Step "2/6" "安装 Codex CLI"
if (Test-Command codex) {
  Write-Host "  Codex 已安装 ($(codex --version 2>$null)) → 尝试更新 ..."
} else {
  Write-Host "  安装 Codex CLI ..."
}
$codexInstalled = Invoke-NpmInstall "@openai/codex" "Codex CLI"
Refresh-Path
if (Test-Command codex) {
  Write-Ok "Codex CLI 就绪：$(codex --version 2>$null)"
} elseif ($codexInstalled) {
  Write-Warn "Codex 已装但未进 PATH，重开终端后 codex --version 验证"
} else {
  Write-Warn "Codex 安装未成功（多为网络），可稍后手动：npm i -g @openai/codex"
}
if ($Source -eq "domestic") {
  Write-Host "  预拉 @codeproxy/cli（国产协议代理，首次启动更快）..."
  if (Invoke-NpmInstall "@codeproxy/cli" "@codeproxy/cli") {
    Write-Ok "@codeproxy/cli 已就绪（启动器用 npx 调用）"
  } else {
    Write-Warn "@codeproxy/cli 预装未成功，启动器首次会用 npx 自动拉取（需联网）"
  }
}

if ($Source -eq "official") {
  # ═══ 官方原生路径 ═══
  Write-Step "3/6" "模型来源：官方原生（跳过 API Key / 代理）"
  Write-Skip "官方模式用 ChatGPT 账号登录，无需 DeepSeek/Kimi Key"

  Write-Step "4/6" "写入 ~/.codex/config.toml（官方）"
  if (Test-Path $CodexConfig) {
    $bak = "$CodexConfig.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $CodexConfig -Destination $bak -Force
    Write-Skip "原 config.toml 已备份 → $([System.IO.Path]::GetFileName($bak))"
  }
  $tomlOfficial = @"
# Codex 官方原生模式：用 ChatGPT 账号登录（codex login / 插件里 Sign in with ChatGPT）
# 由 install-codex.ps1 生成。

model = "gpt-5.1-codex"
model_reasoning_effort = "medium"
"@
  Write-TextFile $CodexConfig $tomlOfficial
  Write-Ok "Codex 配置 → $CodexConfig"

  Write-Step "5/6" "安装 Codex IDE 插件"
  Install-CodexExtension

  Write-Step "6/6" "生成启动器"
  $launcher = Join-Path $OutputDir "启动Codex.bat"
  $launcherContent = @"
@echo off
chcp 65001 >nul
title Codex (官方 gpt-5.x)
cd /d "%USERPROFILE%"
echo 官方原生模式：若首次使用请先登录 ChatGPT 账号
echo （命令行执行 codex login，或在 IDE 插件里 Sign in with ChatGPT）
echo.
codex
"@
  Write-TextFile $launcher $launcherContent
  Write-Ok "启动器 → $launcher"
} else {
  # ═══ 国产路径（DeepSeek + Kimi 经本地代理）═══
  Write-Step "3/6" "配置 API Key（DeepSeek 写代码 + Kimi 看图）"
  if ($DeepseekKey) { $dsk = $DeepseekKey.Trim(); Write-Skip "DeepSeek Key 由参数传入" }
  else {
    Write-Host "  获取 DeepSeek Key: https://platform.deepseek.com/" -ForegroundColor DarkGray
    $dsk = Read-ApiKey "DeepSeek API Key"
  }
  if ($KimiKey) { $kk = $KimiKey.Trim(); Write-Skip "Kimi Key 由参数传入" }
  else {
    Write-Host "  获取 Kimi Coding Key: https://platform.moonshot.cn/ (api.kimi.com coding)" -ForegroundColor DarkGray
    $kk = Read-ApiKey "Kimi Coding API Key" -Optional
  }

  Write-Step "4/6" "写入代理配置 + ~/.codex/config.toml"
  $kimiKeyVal = ""
  if ($kk) { $kimiKeyVal = $kk }
  $proxy = [ordered]@{
    version = "1.0"
    currentUpstream = "deepseek"
    timeoutMs = 300000
    upstreams = [ordered]@{
      deepseek = [ordered]@{
        baseUrl = "https://api.deepseek.com/v1"
        apiKey = $dsk
        model = "deepseek-v4-pro"
        dropImages = $true
        fallback = "kimi"
      }
      kimi = [ordered]@{
        baseUrl = "https://api.kimi.com/coding/v1"
        apiKey = $kimiKeyVal
        model = "kimi-for-coding"
        headers = [ordered]@{ "user-agent" = "KimiCLI/1.39.0" }
      }
    }
  }
  Write-TextFile $ProxyConfig ($proxy | ConvertTo-Json -Depth 12)
  Write-Ok "代理配置 → $ProxyConfig"
  if (-not $kk) { Write-Warn "未填 Kimi Key：贴图时无法自动识图（其余写代码不受影响）" }

  # preferred_auth_method=apikey 让 IDE 插件跳过 ChatGPT 登录、直接用本地 provider
  $toml = @"
# Codex 双模型：DeepSeek 主模型，贴图自动经代理切 Kimi 识图
# 由 install-codex.ps1 生成。需先启动本地代理（启动Codex.bat 会自动起）。
# preferred_auth_method=apikey：让 VS Code/Cursor 的 Codex 插件不弹 ChatGPT 登录。

model_provider = "local"
model = "deepseek-v4-pro"
preferred_auth_method = "apikey"

[model_providers.local]
name = "DeepSeek+Kimi Local Proxy"
base_url = "http://127.0.0.1:$ProxyPort/v1"
wire_api = "responses"
requires_openai_auth = false
stream_idle_timeout_ms = 300000

[profiles.deepseek]
model_provider = "local"
model = "deepseek-v4-pro"
model_context_window = 1000000

[profiles.flash]
model_provider = "local"
model = "deepseek-v4-flash"
model_context_window = 1000000

[profiles.kimi]
model_provider = "local"
model = "kimi-for-coding"
model_context_window = 256000
"@
  if (Test-Path $CodexConfig) {
    $bak = "$CodexConfig.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $CodexConfig -Destination $bak -Force
    Write-Skip "原 config.toml 已备份 → $([System.IO.Path]::GetFileName($bak))"
  }
  Write-TextFile $CodexConfig $toml
  Write-Ok "Codex 配置 → $CodexConfig"

  # 插件 apikey 模式需要 auth.json 里存在一个 key（本地代理不校验，占位即可）
  if (Test-Path $CodexAuth) {
    $bakAuth = "$CodexAuth.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $CodexAuth -Destination $bakAuth -Force
    Write-Skip "原 auth.json 已备份 → $([System.IO.Path]::GetFileName($bakAuth))"
  }
  Write-TextFile $CodexAuth '{"OPENAI_API_KEY":"sk-local-proxy-placeholder"}'
  Write-Ok "auth.json 占位写入（IDE 插件免登录用）"

  Write-Step "5/6" "安装 Codex IDE 插件"
  Install-CodexExtension

  Write-Step "6/6" "生成启动器"
  $launcher = Join-Path $OutputDir "启动Codex.bat"
  $cfgEsc = $ProxyConfig
  $launcherContent = @"
@echo off
chcp 65001 >nul
title Codex (DeepSeek + Kimi)
cd /d "%USERPROFILE%"

echo 启动本地协议代理 (端口 $ProxyPort)...
start "CodeProxy DeepSeek+Kimi" /min cmd /c npx --yes @codeproxy/cli --config "$cfgEsc" --host 127.0.0.1 --port $ProxyPort

echo 等待代理就绪...
set /a tries=0
:wait
timeout /t 1 >nul
curl -s http://127.0.0.1:$ProxyPort/v1/models >nul 2>&1
if not errorlevel 1 goto ready
set /a tries+=1
if %tries% lss 15 goto wait
echo 代理可能未就绪，仍尝试进入 Codex...
:ready

echo.
echo Codex 已连 DeepSeek 主模型（贴图自动切 Kimi）
echo 快模型: codex -p flash  ^|  纯Kimi: codex -p kimi
echo IDE 里用：先保持本代理窗口开着，再在 VS Code/Cursor 侧边栏打开 Codex 贴图
echo.
codex -p deepseek
"@
  Write-TextFile $launcher $launcherContent
  Write-Ok "启动器 → $launcher"
}

Write-Host ""
if ($script:InstallWarnings.Count -gt 0) {
  Write-Host "======================================================" -ForegroundColor Yellow
  Write-Host "  安装结束，但有 $($script:InstallWarnings.Count) 项需注意（多为网络，可重跑或手动处理）：" -ForegroundColor Yellow
  Write-Host "======================================================" -ForegroundColor Yellow
  foreach ($w in $script:InstallWarnings) { Write-Host "    !! $w" -ForegroundColor Yellow }
  Write-Host ""
} else {
  Write-Host "======================================================" -ForegroundColor Green
  Write-Host "  安装完成！" -ForegroundColor Green
  Write-Host "======================================================" -ForegroundColor Green
  Write-Host ""
}
if ($Source -eq "official") {
  Write-Host "  终端：双击 $launcher（或命令行 codex），首次 codex login 登录 ChatGPT" -ForegroundColor White
  Write-Host "  IDE ：VS Code/Cursor 侧边栏打开 Codex → Sign in with ChatGPT" -ForegroundColor DarkGray
} else {
  Write-Host "  终端：双击 $launcher → 自动起代理 → 进 Codex（贴图自动 Kimi）" -ForegroundColor White
  Write-Host "  IDE ：先双击启动器让代理常驻，再在 VS Code/Cursor 侧边栏用 Codex 贴图识图" -ForegroundColor DarkGray
}
Write-Host ""
