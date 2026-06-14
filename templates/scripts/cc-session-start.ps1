# Auto-inject project context — SessionStart hook (ai-ship)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$ai = Join-Path $root '.ai'
$ctx = Join-Path $ai 'context.md'
$handoff = Join-Path $ai 'handoff.md'
$maxAgeHours = 6
$ctxshotLocal = Join-Path $root 'node_modules\.bin\ctxshot.cmd'
$ctxshotNode = 'node'
$ctxshotScript = Join-Path $root 'node_modules\ctxshot\dist\cli.js'

function Write-Section($title, $path) {
  if (-not (Test-Path $path)) { return }
  $body = Get-Content -LiteralPath $path -Raw -Encoding UTF8
  if (-not $body.Trim()) { return }
  Write-Output ""
  Write-Output "## $title"
  Write-Output $body.Trim()
}

$needRefresh = -not (Test-Path $ctx)
if (Test-Path $ctx) {
  $age = (Get-Date) - (Get-Item $ctx).LastWriteTime
  if ($age.TotalHours -ge $maxAgeHours) { $needRefresh = $true }
}

if ($needRefresh) {
  New-Item -ItemType Directory -Path $ai -Force | Out-Null
  Push-Location $root
  if (Test-Path $ctxshotScript) {
    & $ctxshotNode $ctxshotScript --compact --diff -o .ai/context.md
  } elseif (Test-Path $ctxshotLocal) {
    & $ctxshotLocal --compact --diff -o .ai/context.md
  } else {
    npx --yes ctxshot@latest --compact --diff -o .ai/context.md
  }
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ctx)) {
    Pop-Location
    Write-Error "ctxshot failed — fix before starting session (no fallback)."
  }
  Pop-Location
}

Write-Output "# Auto-loaded workspace memory (SessionStart hook)"
Write-Output "Project: $root"
Write-Output "Context loaded from .ai/context.md — do NOT ask user to run session_brief."

Write-Section 'Project context (.ai/context.md)' $ctx
Write-Section 'Last handoff (.ai/handoff.md)' $handoff
