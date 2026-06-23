#Requires -Version 5.1
<#
.SYNOPSIS
  Codex 一键安装：Node/Git/VS Code + Codex CLI + DeepSeek 写代码 + Kimi 自动识图
  自包含单文件，无需 ccSwitch，全程只提示输入 API Key。

.DESCRIPTION
  Codex 0.128+ 只认 OpenAI Responses 协议，DeepSeek/Kimi 是 Chat Completions，
  必须经本地 @codeproxy/cli 翻译。本脚本：
    1. 装 Node/Git/VS Code（已装则升级）
    2. 装 Codex CLI + @codeproxy/cli
    3. 写 codeproxy 配置（DeepSeek 主 + 贴图自动切 Kimi）
    4. 写 ~/.codex/config.toml（指向本地代理 + profiles）
    5. 生成「启动Codex.bat」：自动起代理→进 Codex

.EXAMPLE
  irm https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.ps1 | iex

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install-codex.ps1 -SkipSystemInstall
#>
param(
  [switch]$SkipSystemInstall,
  [string]$DeepseekKey = "",
  [string]$KimiKey = "",
  [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch { }
if (-not $env:npm_config_registry) { $env:npm_config_registry = "https://registry.npmmirror.com" }

$CodexDir = Join-Path $env:USERPROFILE ".codex"
$CodexConfig = Join-Path $CodexDir "config.toml"
if (-not $OutputDir) { $OutputDir = (Get-Location).Path }
$ProxyConfig = Join-Path $OutputDir "codeproxy.config.json"
$ProxyPort = 8787

function Write-Step([string]$n, [string]$m) { Write-Host ""; Write-Host "[$n] $m" -ForegroundColor Cyan }
function Write-Ok([string]$m) { Write-Host "  OK  $m" -ForegroundColor Green }
function Write-Skip([string]$m) { Write-Host "  --  $m" -ForegroundColor DarkGray }
function Write-Warn([string]$m) { Write-Host "  !!  $m" -ForegroundColor Yellow }

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

# ─── 提权 ───────────────────────────────────────────────
if (-not $SkipSystemInstall -and -not (Test-Admin)) {
  $self = if ($PSCommandPath) { $PSCommandPath } else { $null }
  if ($self) {
    Write-Host "  需要管理员权限装系统组件，正在请求提权（弹 UAC 点是）..." -ForegroundColor Yellow
    try {
      Start-Process powershell.exe -ArgumentList @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$self`"","-OutputDir","`"$OutputDir`"") -Verb RunAs -ErrorAction Stop
      exit 0
    } catch { Write-Warn "提权取消，以普通权限继续（winget 用户级安装多数可用）" }
  } else {
    Write-Warn "非管理员、管道运行。建议用管理员 PowerShell 重跑；现以普通权限继续。"
  }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  Codex 一键安装（DeepSeek 写代码 + Kimi 识图）" -ForegroundColor Magenta
Write-Host "  Node + Git + VS Code + Codex CLI + 本地协议代理" -ForegroundColor Magenta
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  配置输出目录: $OutputDir"

# ═══ 1. 系统依赖 ═══
if (-not $SkipSystemInstall) {
  Write-Step "1/5" "检测并安装系统依赖 (Node / Git / VS Code)"
  if (-not (Test-Command winget)) { throw "未找到 winget，请先从 Microsoft Store 装「应用安装程序」。" }
  $nm = Get-NodeMajor
  if ($nm -lt 18) { Ensure-WingetPackage "OpenJS.NodeJS.LTS" "Node.js LTS" } else { Write-Ok "Node $(node -v) 已够新" }
  Refresh-Path
  if (-not (Test-Command node)) { throw "Node 安装后仍不可用，请重开终端再跑。" }
  Ensure-WingetPackage "Git.Git" "Git"
  Ensure-WingetPackage "Microsoft.VisualStudioCode" "Visual Studio Code"
} else {
  Write-Step "1/5" "跳过系统安装 (-SkipSystemInstall)"; Refresh-Path
}

# ═══ 2. Codex CLI + 代理 ═══
Write-Step "2/5" "安装 Codex CLI 和 @codeproxy/cli"
if (Test-Command codex) {
  Write-Host "  Codex 已安装 ($(codex --version 2>$null)) → 尝试更新 ..."
  & npm.cmd install -g @openai/codex 2>&1 | Out-Null
} else {
  Write-Host "  安装 Codex CLI ..."
  & npm.cmd install -g @openai/codex 2>&1 | Out-Null
}
Refresh-Path
if (Test-Command codex) { Write-Ok "Codex CLI 就绪：$(codex --version 2>$null)" } else { Write-Warn "Codex 未进 PATH，重开终端后 codex --version 验证" }
Write-Host "  预拉 @codeproxy/cli（首次启动更快）..."
& npm.cmd install -g @codeproxy/cli 2>&1 | Out-Null
Write-Ok "@codeproxy/cli 已就绪（启动器用 npx 调用）"

# ═══ 3. API Key ═══
Write-Step "3/5" "配置 API Key（DeepSeek 写代码 + Kimi 看图）"
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

# ═══ 4. 写配置 ═══
Write-Step "4/5" "写入代理配置 + ~/.codex/config.toml"

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

$toml = @"
# Codex 双模型：DeepSeek 主模型，贴图自动经代理切 Kimi 识图
# 由 install-codex.ps1 生成。需先启动本地代理（启动Codex.bat 会自动起）。

model_provider = "local"
model = "deepseek-v4-pro"

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

# ═══ 5. 启动器 ═══
Write-Step "5/5" "生成启动器"
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
echo.
codex -p deepseek
"@
Write-TextFile $launcher $launcherContent
Write-Ok "启动器 → $launcher"

Write-Host ""
Write-Host "======================================================" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  下一步：双击 $launcher" -ForegroundColor White
Write-Host "  它会自动起代理 → 进入 Codex（DeepSeek 写代码 / 贴图自动 Kimi）" -ForegroundColor DarkGray
Write-Host "  贴图测试：把截图拖进 Codex，应由 Kimi 识别" -ForegroundColor DarkGray
Write-Host ""
