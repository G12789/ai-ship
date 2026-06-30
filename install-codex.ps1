#Requires -Version 5.1
<#
.SYNOPSIS
  Codex 一键安装：Node/Git/VS Code + Codex CLI + Codex 桌面 App + VS Code 插件
  支持两种模型来源（装时可选）：
    - 国产：DeepSeek 写代码 + Kimi 自动识图（经本地 @codeproxy/cli 协议代理）
    - 官方：原生 gpt-5.x（用 ChatGPT 账号登录，需订阅）

.DESCRIPTION
  Codex 0.128+ 只认 OpenAI Responses 协议，DeepSeek/Kimi 是 Chat Completions，
  走国产时必须经本地 @codeproxy/cli 翻译。CLI、桌面 App、IDE 插件(openai.chatgpt)
  共用 ~/.codex/config.toml，装完三种界面都能用同一套配置。

.EXAMPLE
  irm https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.ps1 | iex

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install-codex.ps1 -SkipSystemInstall -Source domestic
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch { }
if (-not $env:npm_config_registry) { $env:npm_config_registry = "https://registry.npmmirror.com" }

# 不用 param()：Windows PowerShell 5.1 下 irm | iex 会在 param 处解析失败。
# 改用手动解析，同时兼容 -File 与 irm | iex 两种入口。
$SkipSystemInstall = $false
$Source = ""
$DeepseekKey = ""
$KimiKey = ""
$OutputDir = ""
$NoExtension = $false
$NoDesktopApp = $false
$NoAutoStart = $false

function Initialize-InstallArgs([object[]]$RawArgs) {
  for ($i = 0; $i -lt $RawArgs.Count; $i++) {
    $a = [string]$RawArgs[$i]
    switch ($a) {
      "-SkipSystemInstall" { $script:SkipSystemInstall = $true; continue }
      "-NoExtension" { $script:NoExtension = $true; continue }
      "-NoDesktopApp" { $script:NoDesktopApp = $true; continue }
      "-NoAutoStart" { $script:NoAutoStart = $true; continue }
      "-Source" {
        if ($i + 1 -ge $RawArgs.Count) { throw "-Source 需要 domestic 或 official" }
        $script:Source = [string]$RawArgs[++$i]
        if ($script:Source -notin @("", "domestic", "official")) { throw "-Source 只能是 domestic 或 official" }
        continue
      }
      "-DeepseekKey" {
        if ($i + 1 -ge $RawArgs.Count) { throw "-DeepseekKey 需要值" }
        $script:DeepseekKey = [string]$RawArgs[++$i]; continue
      }
      "-KimiKey" {
        if ($i + 1 -ge $RawArgs.Count) { throw "-KimiKey 需要值" }
        $script:KimiKey = [string]$RawArgs[++$i]; continue
      }
      "-OutputDir" {
        if ($i + 1 -ge $RawArgs.Count) { throw "-OutputDir 需要路径" }
        $script:OutputDir = [string]$RawArgs[++$i]; continue
      }
      default { throw "未知参数: $a" }
    }
  }
}
Initialize-InstallArgs -RawArgs @($args)

$CodexInstallUrl = "https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.ps1"

function Get-InstallScriptPath {
  if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) { return $PSCommandPath }
  $cached = Join-Path $env:TEMP "install-codex.ps1"
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $CodexInstallUrl -OutFile $cached -UseBasicParsing
  } catch {
    throw "irm | iex 模式下无法缓存安装脚本，请检查网络: $_"
  }
  return $cached
}

$CodexDir = Join-Path $env:USERPROFILE ".codex"
$CodexConfig = Join-Path $CodexDir "config.toml"
$CodexAuth = Join-Path $CodexDir "auth.json"
if (-not $OutputDir) {
  $OutputDir = Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex-DeepSeek-Kimi双模型"
}
if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
# 代理配置放 ~/.codex（ASCII 路径），启动器里用 %USERPROFILE% 引用，避免项目目录含中文导致 .bat 乱码
if (-not (Test-Path -LiteralPath $CodexDir)) { New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null }
$ProxyConfig = Join-Path $CodexDir "codeproxy.config.json"
$ProxyPort = 8787
$CodexExtId = "openai.chatgpt"
$CodexAppStoreId = "9PLM9XGG6VKS"   # Microsoft Store: OpenAI Codex 桌面 App

# 启动器里用 %USERPROFILE% 动态引用代理配置，保证 .bat 内容全 ASCII（防中文路径乱码）
$ProxyConfigBat = '%USERPROFILE%\.codex\codeproxy.config.json'

# 解析「真正的 VS Code」可执行：PATH 上的 code 可能被 Cursor 等抢占。
# Codex 插件必须装进真 VS Code（与 Claude Code 的接入方式一致），不能进 Cursor。
function Resolve-VsCode {
  $found = @()
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
  $cands = @(
    (Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"),
    (Join-Path $env:ProgramFiles "Microsoft VS Code\bin\code.cmd")
  )
  if (${env:ProgramFiles(x86)}) { $cands += (Join-Path ${env:ProgramFiles(x86)} "Microsoft VS Code\bin\code.cmd") }
  foreach ($c in $cands) { if ($c -and (Test-Path $c)) { $found += $c } }
  $g = Get-Command code -ErrorAction SilentlyContinue
  if ($g -and $g.Source -match 'Microsoft VS Code') { $found += $g.Source }
  if ($found.Count -gt 0) { return $found[0] }
  return $null
}
function Resolve-VsCodeExe([string]$CodeCmd) {
  if (-not $CodeCmd) { return $null }
  $installDir = Split-Path -Parent (Split-Path -Parent $CodeCmd)
  $exe = Join-Path $installDir "Code.exe"
  if (Test-Path $exe) { return $exe }
  return $null
}
function Get-VsCodeExtensions([string]$CodeCmd) {
  try {
    $list = & { $ErrorActionPreference = 'Continue'; & $CodeCmd --list-extensions 2>$null }
    return @($list)
  } catch { return @() }
}
function Install-VsCodeExtension([string]$CodeCmd, [string]$Ext, [int]$TimeoutSec = 180) {
  if ((Get-VsCodeExtensions $CodeCmd) -contains $Ext) { return "ok" }
  $out = [System.IO.Path]::GetTempFileName()
  $err = [System.IO.Path]::GetTempFileName()
  try {
    $p = Start-Process -FilePath $CodeCmd `
      -ArgumentList @("--install-extension", $Ext, "--force") `
      -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    $elapsed = 0; $exited = $false
    while ($elapsed -lt $TimeoutSec) {
      if ($p.WaitForExit(2000)) { $exited = $true; break }
      $elapsed += 2; Write-Host "." -NoNewline -ForegroundColor DarkGray
    }
    Write-Host ""
    if (-not $exited) { & cmd /c "taskkill /PID $($p.Id) /T /F" 2>&1 | Out-Null }
    if ((Get-VsCodeExtensions $CodeCmd) -contains $Ext) { return "ok" }
    if (-not $exited) { return "timeout" }
    return "fail"
  } catch { return "fail" }
  finally { Remove-Item -LiteralPath $out, $err -Force -ErrorAction SilentlyContinue }
}

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

# 把 Codex IDE 插件(openai.chatgpt)装进「真正的 VS Code」——与 Claude Code 接入 VS Code 的方式完全一致。
# 不装进 Cursor/Windsurf：它们有各自内置 AI，且用户要的是 VS Code。
function Install-CodexExtension {
  if ($NoExtension) { Write-Skip "已指定 -NoExtension，跳过 VS Code 插件"; return }
  $vscode = Resolve-VsCode
  if (-not $vscode) {
    Write-Warn "未找到真正的 VS Code（PATH 上的 code 可能是 Cursor）。请装 Microsoft VS Code 后，在其扩展面板搜 Codex / OpenAI 安装"
    return
  }
  Write-Host "  安装/更新 VS Code 扩展 $CodexExtId（最多等 180 秒，点号=进行中）..."
  $r = Install-VsCodeExtension $vscode $CodexExtId 180
  switch ($r) {
    "ok"      { Write-Ok "Codex 插件已装入 VS Code：$vscode（侧边栏可贴图识图）" }
    "timeout" { Write-Warn "装 Codex 插件超时（网络），可稍后在 VS Code 扩展面板搜 Codex / OpenAI 手动装" }
    default   { Write-Warn "装 Codex 插件未确认，可在 VS Code 扩展面板搜 Codex / OpenAI 手动装" }
  }
}

function Test-CodexDesktopAppInstalled {
  $pkg = Get-AppxPackage -Name "OpenAI.Codex" -ErrorAction SilentlyContinue
  if ($pkg) { return $true }
  $list = winget list --id $CodexAppStoreId -s msstore -e --accept-source-agreements 2>$null
  return [bool]($LASTEXITCODE -eq 0 -and ($list | Select-String -SimpleMatch $CodexAppStoreId))
}

function Install-CodexDesktopApp {
  if ($NoDesktopApp) { Write-Skip "已指定 -NoDesktopApp，跳过 Codex 桌面 App"; return }
  if (Test-CodexDesktopAppInstalled) {
    Write-Host "  Codex 桌面 App 已安装 → 检查更新 ..."
    winget upgrade --id $CodexAppStoreId -s msstore --accept-package-agreements --accept-source-agreements --disable-interactivity 2>$null | Out-Null
    Write-Ok "Codex 桌面 App 已是最新（或已更新）"
    return
  }
  Write-Host "  安装 Codex 桌面 App（Microsoft Store，界面比终端更完整）..."
  & winget install --id $CodexAppStoreId -s msstore --accept-package-agreements --accept-source-agreements --disable-interactivity
  if ((Test-CodexDesktopAppInstalled)) {
    Write-Ok "Codex 桌面 App 已安装（与 CLI / VS Code 插件共用 ~/.codex 配置）"
  } else {
    Write-Warn "Codex 桌面 App 安装未确认（需 Microsoft Store）。可手动：winget install Codex -s msstore"
  }
}

function Start-CodexDesktopApp {
  try {
    $app = Get-StartApps | Where-Object { $_.AppID -like "OpenAI.Codex*" } | Select-Object -First 1
    if ($app) {
      Start-Process "explorer.exe" -ArgumentList "shell:AppsFolder\$($app.AppID)"
      return $true
    }
  } catch { }
  return $false
}

function Test-CodexProxyRunning {
  try {
    & curl.exe -s --max-time 2 "http://127.0.0.1:$ProxyPort/v1/models" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
  } catch { return $false }
}

function Ensure-CodexProxyRunning {
  if (Test-CodexProxyRunning) { return $true }
  try {
    Start-Process "cmd.exe" -ArgumentList @(
      "/c", "start `"Codex Proxy BG`" /min cmd /c npx --yes @codeproxy/cli --config `"$ProxyConfig`" --host 127.0.0.1 --port $ProxyPort"
    ) -WindowStyle Hidden | Out-Null
    for ($i = 0; $i -lt 15; $i++) {
      Start-Sleep -Seconds 1
      if (Test-CodexProxyRunning) { return $true }
    }
  } catch { }
  return $false
}

function Get-CodexProxyEnsureBatContent([switch]$SilentOnly) {
  if ($SilentOnly) {
    return @"
@echo off
curl -s http://127.0.0.1:$ProxyPort/v1/models >nul 2>&1
if not errorlevel 1 exit /b 0
start "Codex Proxy BG" /min cmd /c npx --yes @codeproxy/cli --config "$ProxyConfigBat" --host 127.0.0.1 --port $ProxyPort
exit /b 0
"@
  }
  return @"
@echo off
chcp 65001 >nul
if /I "%~1"=="silent" goto run
curl -s http://127.0.0.1:$ProxyPort/v1/models >nul 2>&1
if not errorlevel 1 (
  echo Codex proxy already running on 127.0.0.1:$ProxyPort
  timeout /t 2 >nul
  exit /b 0
)
:run
curl -s http://127.0.0.1:$ProxyPort/v1/models >nul 2>&1
if not errorlevel 1 exit /b 0
start "Codex Proxy BG" /min cmd /c npx --yes @codeproxy/cli --config "$ProxyConfigBat" --host 127.0.0.1 --port $ProxyPort
set /a tries=0
:wait
ping -n 2 127.0.0.1 >nul
curl -s http://127.0.0.1:$ProxyPort/v1/models >nul 2>&1
if not errorlevel 1 goto done
set /a tries+=1
if %tries% lss 15 goto wait
:done
if /I not "%~1"=="silent" (
  echo Proxy started in background. Open Codex App or VS Code directly.
  timeout /t 2 >nul
)
exit /b 0
"@
}

function Register-CodexProxyAutoStart {
  if ($NoAutoStart) { Write-Skip "已指定 -NoAutoStart，跳过登录时自动起代理"; return }
  try {
    # 固定路径 ~/.codex/，避免启动器目录被删后开机自启失效
    $stableBat = Join-Path $CodexDir "Codex-Proxy-AutoStart.bat"
    Write-TextFile $stableBat (Get-CodexProxyEnsureBatContent -SilentOnly)

    $startup = [Environment]::GetFolderPath("Startup")
    if ($startup) {
      $dest = Join-Path $startup "Codex-Proxy-AutoStart.bat"
      Write-TextFile $dest "@echo off`r`ncall `"$stableBat`""
      Write-Ok "已注册启动文件夹 → $dest"
    } else {
      Write-Warn "无法定位 Windows 启动文件夹"
    }

    $taskName = "CodexProxyAutoStart"
    $tr = "`"$stableBat`""
    & schtasks.exe /Query /TN $taskName /FO LIST 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      & schtasks.exe /Change /TN $taskName /TR $tr /SC ONLOGON /RL LIMITED /F 2>$null | Out-Null
    } else {
      & schtasks.exe /Create /TN $taskName /TR $tr /SC ONLOGON /RL LIMITED /F 2>$null | Out-Null
    }
    if ($LASTEXITCODE -eq 0) {
      Write-Ok "已注册计划任务 ONLOGON → $taskName（重启/重新登录后代理自动在后台起）"
    } else {
      Write-Warn "计划任务注册未确认（启动文件夹仍可用）"
    }
  } catch {
    Write-Warn "注册登录自动起代理失败，可手动双击 Codex-Proxy-Ensure.bat"
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
  Write-Host "  需要管理员权限装系统组件，正在请求提权（弹 UAC 点是）..." -ForegroundColor Yellow
  try {
    $self = Get-InstallScriptPath
    $argList = @(
      "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$self`"",
      "-OutputDir", "`"$OutputDir`""
    )
    if ($SkipSystemInstall) { $argList += "-SkipSystemInstall" }
    if ($Source) { $argList += @("-Source", $Source) }
    if ($DeepseekKey) { $argList += @("-DeepseekKey", $DeepseekKey) }
    if ($KimiKey) { $argList += @("-KimiKey", $KimiKey) }
    if ($NoExtension) { $argList += "-NoExtension" }
    if ($NoDesktopApp) { $argList += "-NoDesktopApp" }
    if ($NoAutoStart) { $argList += "-NoAutoStart" }
    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -ErrorAction Stop
    exit 0
  } catch { Write-Warn "提权取消，以普通权限继续（winget 用户级安装多数可用）" }
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Magenta
Write-Host "  Codex 一键安装（CLI + 桌面 App + IDE 插件）" -ForegroundColor Magenta
Write-Host "  Node + Git + VS Code + Codex App + 模型接入" -ForegroundColor Magenta
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
  Write-Step "1/6" "检测并安装系统依赖 (Node / Git / VS Code / Codex 桌面 App)"
  if (-not (Test-Command winget)) { throw "未找到 winget，请先从 Microsoft Store 装「应用安装程序」。" }
  $nm = Get-NodeMajor
  if ($nm -lt 18) { Ensure-WingetPackage "OpenJS.NodeJS.LTS" "Node.js LTS" } else { Write-Ok "Node $(node -v) 已够新" }
  Refresh-Path
  if (-not (Test-Command node)) { throw "Node 安装后仍不可用，请重开终端再跑。" }
  Ensure-WingetPackage "Git.Git" "Git"
  Ensure-WingetPackage "Microsoft.VisualStudioCode" "Visual Studio Code"
  Install-CodexDesktopApp
} else {
  Write-Step "1/6" "跳过系统安装 (-SkipSystemInstall)"; Refresh-Path
  if (-not $NoDesktopApp) { Install-CodexDesktopApp }
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
  # 全 ASCII，避免中文 Windows 下乱码；异常 pause 不闪退
  $launcherContent = @"
@echo off
chcp 65001 >nul
title Codex (official gpt-5.x)
cd /d "%USERPROFILE%"

where codex >nul 2>&1
if errorlevel 1 (
  echo [ERROR] 'codex' not found. Open a NEW terminal, or run: npm i -g @openai/codex
  pause
  exit /b 1
)

echo Official mode: on first use, sign in to your ChatGPT account.
echo   CLI: run  codex login
echo   IDE: open the Codex panel in VS Code/Cursor and Sign in with ChatGPT
echo.
codex

echo.
echo Codex exited. Press any key to close.
pause >nul
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

  # preferred_auth_method=apikey 让 IDE 插件跳过 ChatGPT 登录、直接用本地 provider。
  # 注意：codex 0.142+ 已废弃 config.toml 内的 [profiles.*] 内联表（用 -p 会报错），
  # 改为独立文件 ~/.codex/<名>.config.toml，用 --profile <名> 选择。默认 model 即 deepseek。
  $toml = @"
# Codex 双模型：DeepSeek 主模型，贴图自动经代理切 Kimi 识图
# 由 install-codex.ps1 生成。需先启动本地代理（启动Codex.bat 会自动起）。
# preferred_auth_method=apikey：让 VS Code 的 Codex 插件不弹 ChatGPT 登录。
# 默认就是 DeepSeek 写代码；快模型 codex -p flash；纯 Kimi codex -p kimi。

model_provider = "local"
model = "deepseek-v4-pro"
model_context_window = 1000000
preferred_auth_method = "apikey"

[model_providers.local]
name = "DeepSeek+Kimi Local Proxy"
base_url = "http://127.0.0.1:$ProxyPort/v1"
wire_api = "responses"
requires_openai_auth = false
stream_idle_timeout_ms = 300000
"@
  if (Test-Path $CodexConfig) {
    $bak = "$CodexConfig.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $CodexConfig -Destination $bak -Force
    Write-Skip "原 config.toml 已备份 → $([System.IO.Path]::GetFileName($bak))"
  }
  Write-TextFile $CodexConfig $toml
  Write-Ok "Codex 配置 → $CodexConfig"

  # 新机制 profile 文件：codex -p flash / -p kimi 各读对应文件
  $flashToml = @"
# 由 install-codex.ps1 生成：DeepSeek 快模型。用 codex -p flash 选择。
model_provider = "local"
model = "deepseek-v4-flash"
model_context_window = 1000000
preferred_auth_method = "apikey"

[model_providers.local]
name = "DeepSeek+Kimi Local Proxy"
base_url = "http://127.0.0.1:$ProxyPort/v1"
wire_api = "responses"
requires_openai_auth = false
stream_idle_timeout_ms = 300000
"@
  $kimiToml = @"
# 由 install-codex.ps1 生成：Kimi 识图/长上下文。用 codex -p kimi 选择。
model_provider = "local"
model = "kimi-for-coding"
model_context_window = 256000
preferred_auth_method = "apikey"

[model_providers.local]
name = "DeepSeek+Kimi Local Proxy"
base_url = "http://127.0.0.1:$ProxyPort/v1"
wire_api = "responses"
requires_openai_auth = false
stream_idle_timeout_ms = 300000
"@
  Write-TextFile (Join-Path $CodexDir "flash.config.toml") $flashToml
  Write-TextFile (Join-Path $CodexDir "kimi.config.toml") $kimiToml
  Write-Ok "Profile 文件 → flash.config.toml / kimi.config.toml"

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

  Write-Step "6/6" "生成启动器 + 注册登录自动起代理"

  # 后台.ensure 代理（不阻塞、不用一直开着这个窗口）
  $proxyEnsureBat = Join-Path $OutputDir "Codex-Proxy-Ensure.bat"
  Write-TextFile $proxyEnsureBat (Get-CodexProxyEnsureBatContent)
  Write-Ok "代理.ensure → $proxyEnsureBat（缺代理时在后台静默拉起）"

  # 兼容旧文件名：内容与 Ensure 相同，不再要求「窗口别关」
  $proxyBat = Join-Path $OutputDir "Codex-IDE-Proxy.bat"
  Write-TextFile $proxyBat (Get-CodexProxyEnsureBatContent)
  Write-Ok "兼容旧名 → $proxyBat"

  # 全套：代理 + App + VS Code
  $fullBat = Join-Path $OutputDir "Launch-Codex-Full.bat"
  $fullBatCn = Join-Path $OutputDir "启动Codex全套.bat"
  $fullContent = @"
@echo off
chcp 65001 >nul
title Codex Full (Proxy + App + VS Code)
cd /d "%USERPROFILE%"

call "%~dp0Codex-Proxy-Ensure.bat" silent

powershell -NoProfile -Command "try { `$a = Get-StartApps | Where-Object { `$_.AppID -like 'OpenAI.Codex*' } | Select-Object -First 1; if (`$a) { Start-Process explorer.exe ('shell:AppsFolder/' + `$a.AppID) } } catch {}"

set "VSCODE=%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe"
if exist "%VSCODE%" (start "" "%VSCODE%") else (where code >nul 2>&1 && start "" code)

echo.
echo Launched: Codex App + VS Code (proxy runs minimized in background).
timeout /t 2 >nul
"@
  Write-TextFile $fullBat $fullContent
  Write-TextFile $fullBatCn $fullContent
  Write-Ok "全套启动 → $fullBatCn"

  Register-CodexProxyAutoStart

  # 终端版：起代理 -> 等就绪 -> 进 Codex
  $launcher = Join-Path $OutputDir "启动Codex.bat"
  $launcherContent = @"
@echo off
chcp 65001 >nul
title Codex (DeepSeek + Kimi)
cd /d "%USERPROFILE%"

echo [1/3] Ensuring local proxy on 127.0.0.1:$ProxyPort ...
call "%~dp0Codex-Proxy-Ensure.bat" silent

echo [2/3] Waiting for proxy (first run may download, up to ~30s) ...
set /a tries=0
:wait
ping -n 2 127.0.0.1 >nul
curl -s http://127.0.0.1:$ProxyPort/v1/models >nul 2>&1
if not errorlevel 1 goto ready
set /a tries+=1
if %tries% lss 30 goto wait
echo   [warn] proxy not confirmed, trying Codex anyway ...
:ready
echo   proxy is up.

where codex >nul 2>&1
if errorlevel 1 (
  echo.
  echo [ERROR] 'codex' command not found. Open a NEW terminal, or run:
  echo     npm i -g @openai/codex
  echo.
  pause
  exit /b 1
)

echo [3/3] Launching Codex (default model: deepseek) ...
echo   fast model: codex -p flash   ^|   kimi only: codex -p kimi
echo   App/VS Code: open directly (proxy auto-starts at login).
echo.
codex

echo.
echo Codex exited. Press any key to close.
pause >nul
"@
  Write-TextFile $launcher $launcherContent
  Write-Ok "终端启动器 → $launcher"
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
  Write-Host "  桌面 App：开始菜单搜 Codex 打开（界面更完整，与 CLI 共用配置）" -ForegroundColor DarkGray
  Write-Host "  IDE ：VS Code 侧边栏打开 Codex → Sign in with ChatGPT" -ForegroundColor DarkGray
} else {
  Write-Host "  日常：直接打开 Codex App 或 VS Code 即可（登录后代理自动在后台跑）" -ForegroundColor White
  Write-Host "  终端：双击 $launcher" -ForegroundColor DarkGray
  Write-Host "  全套：双击「启动Codex全套.bat」（代理 + App + VS Code 一次打开）" -ForegroundColor DarkGray
}
Write-Host ""

# ─── 装完：确保代理在跑 → 打开 Codex 桌面 App + VS Code ───
if ($Source -ne "official") {
  if (Ensure-CodexProxyRunning) {
    Write-Ok "本地代理已在后台运行（127.0.0.1:$ProxyPort）；重启后也会自动起"
  } else {
    Write-Warn "代理未能确认就绪，可双击 Codex-Proxy-Ensure.bat"
  }
}

if (-not $NoDesktopApp) {
  if (Start-CodexDesktopApp) {
    Write-Ok "已打开 Codex 桌面 App（推荐，界面更完整）"
  } elseif (Test-CodexDesktopAppInstalled) {
    Write-Warn "Codex 桌面 App 已装但未能自动打开，请从开始菜单搜 Codex"
  }
}

$vscodeOpen = Resolve-VsCode
if ($vscodeOpen -and -not $NoExtension) {
  try {
    Write-Host "  正在打开 VS Code，可在侧边栏直接用 Codex ..." -ForegroundColor White
    & { $ErrorActionPreference = 'Continue'; & $vscodeOpen 2>&1 | Out-Null }
  } catch { Write-Skip "自动打开 VS Code 失败，手动打开即可" }
} elseif (-not $NoExtension) {
  Write-Skip "未找到真正的 VS Code（PATH 上的 code 可能是 Cursor），手动打开 VS Code 后在侧边栏用 Codex"
}
Write-Host ""
