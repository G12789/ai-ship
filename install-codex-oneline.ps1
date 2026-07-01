$ErrorActionPreference = 'Stop'
$url = 'https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.ps1'
$out = Join-Path $env:TEMP 'install-codex.ps1'
if (-not $env:npm_config_registry) { $env:npm_config_registry = 'https://registry.npmmirror.com' }
try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
$argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $out)
if ($args.Count -gt 0) { $argList += $args }
& powershell.exe @argList
exit $LASTEXITCODE
