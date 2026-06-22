#!/usr/bin/env bash
# AI Ship IDE 一键安装 — macOS / Linux
# VS Code + Claude Code + DeepSeek + ai-ship-mcp（记忆+看图），不需要 ccSwitch
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/G12789/ai-ship/master/install.sh | bash
#   bash install.sh --project-path "$HOME/projects/my-app"
#   bash install.sh --skip-system-install --project-path .
set -euo pipefail

PROJECT_PATH=""
SKIP_SYSTEM_INSTALL=0
OPEN_VSCODE=1
DEEPSEEK_KEY=""
MOONSHOT_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-path) PROJECT_PATH="${2:-}"; shift 2 ;;
    --skip-system-install) SKIP_SYSTEM_INSTALL=1; shift ;;
    --no-open-vscode) OPEN_VSCODE=0; shift ;;
    --deepseek-key) DEEPSEEK_KEY="${2:-}"; shift 2 ;;
    --moonshot-key) MOONSHOT_KEY="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
AI Ship IDE 一键安装 (macOS / Linux)

  bash install.sh [--project-path DIR] [--skip-system-install] [--no-open-vscode]

环境变量:
  DEEPSEEK_API_KEY   跳过交互输入 DeepSeek Key
  MOONSHOT_API_KEY   可选，贴图识图
EOF
      exit 0
      ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$PROJECT_PATH" ]] || PROJECT_PATH="$(pwd)"
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

USER_CLAUDE_DIR="${HOME}/.claude"
USER_CLAUDE_SETTINGS="${USER_CLAUDE_DIR}/settings.json"

if [[ "$(uname -s)" == "Darwin" ]]; then
  VSCODE_USER_SETTINGS="${HOME}/Library/Application Support/Code/User/settings.json"
else
  VSCODE_USER_SETTINGS="${HOME}/.config/Code/User/settings.json"
fi

step() { echo ""; echo "== [$1] $2"; }
ok() { echo "  ✓ $*"; }
warn() { echo "  ! $*" >&2; }
skip() { echo "  - $*"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

refresh_path() {
  export PATH="${HOME}/.local/bin:${PATH}"
  if [[ -d "${HOME}/.nvm/versions/node" ]]; then
    local nv
    nv="$(ls -1d "${HOME}"/.nvm/versions/node/*/bin 2>/dev/null | tail -1 || true)"
    [[ -n "$nv" ]] && export PATH="${nv}:${PATH}"
  fi
}

node_major() {
  if ! command_exists node; then echo 0; return; fi
  node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0
}

ensure_brew_pkg() {
  local pkg="$1"
  local label="$2"
  if brew list "$pkg" &>/dev/null; then
    ok "${label} 已安装"
    brew upgrade "$pkg" 2>/dev/null || true
  else
    echo "  安装 ${label} ..."
    brew install "$pkg"
    ok "${label} 安装完成"
  fi
}

read_api_key() {
  local prompt="$1"
  local existing="${2:-}"
  local optional="${3:-0}"
  if [[ -n "$existing" ]]; then
    read -r -s -p "${prompt} 已存在，Enter 保留 / 输入新 Key 覆盖: " v
    echo ""
    [[ -z "$v" ]] && { echo "$existing"; return; }
    echo "$v"
    return
  fi
  if [[ "$optional" == "1" ]]; then
    read -r -s -p "${prompt}（可选，Enter 跳过）: " v
    echo ""
    echo "$v"
    return
  fi
  while true; do
    read -r -s -p "${prompt}（必填）: " v
    echo ""
    [[ -n "$v" ]] && { echo "$v"; return; }
  done
}

write_user_claude_settings() {
  local deepseek="$1"
  local moonshot="$2"
  node <<NODE
const fs = require("fs");
const path = require("path");
const settingsPath = process.env.USER_CLAUDE_SETTINGS;
const dir = path.dirname(settingsPath);
fs.mkdirSync(dir, { recursive: true });

let base = {};
if (fs.existsSync(settingsPath)) {
  try {
    base = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
    const bak = settingsPath + ".bak-" + new Date().toISOString().replace(/[:.]/g, "").slice(0, 15);
    fs.copyFileSync(settingsPath, bak);
    console.log("  - 已备份原配置 → " + path.basename(bak));
  } catch {}
}

const env = {
  ...(base.env || {}),
  ANTHROPIC_BASE_URL: "https://api.deepseek.com/anthropic",
  ANTHROPIC_AUTH_TOKEN: process.env.DEEPSEEK_KEY,
  ANTHROPIC_MODEL: "deepseek-v4-pro[1m]",
  ANTHROPIC_DEFAULT_OPUS_MODEL: "deepseek-v4-pro[1m]",
  ANTHROPIC_DEFAULT_SONNET_MODEL: "deepseek-v4-pro[1m]",
  ANTHROPIC_DEFAULT_HAIKU_MODEL: "deepseek-v4-flash",
  CLAUDE_CODE_SUBAGENT_MODEL: "deepseek-v4-flash",
  CLAUDE_CODE_EFFORT_LEVEL: "max",
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: "1",
  CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK: "1",
  COLORTERM: "truecolor",
  TERM: "xterm-256color",
  FORCE_COLOR: "1",
};
if (process.env.MOONSHOT_KEY) env.MOONSHOT_API_KEY = process.env.MOONSHOT_KEY;

const out = {
  ...base,
  env,
  enableAllProjectMcpServers: true,
  hasCompletedOnboarding: true,
  theme: "dark",
};
fs.writeFileSync(settingsPath, JSON.stringify(out, null, 2) + "\n");
NODE
}

write_vscode_trust_settings() {
  node <<'NODE'
const fs = require("fs");
const path = process.env.VSCODE_USER_SETTINGS;
const dir = require("path").dirname(path);
fs.mkdirSync(dir, { recursive: true });
let s = {};
if (fs.existsSync(path)) {
  try { s = JSON.parse(fs.readFileSync(path, "utf8")); } catch {}
}
Object.assign(s, {
  "security.workspace.trust.enabled": false,
  "security.workspace.trust.startupPrompt": "never",
  "security.workspace.trust.emptyWindow": false,
  "workbench.startupEditor": "none",
  "extensions.ignoreRecommendations": true,
});
fs.writeFileSync(path, JSON.stringify(s, null, 2) + "\n");
NODE
}

echo ""
echo "======================================================"
echo "  AI Ship IDE 一键安装 (macOS / Linux)"
echo "  VS Code + Claude Code + DeepSeek + ai-ship-mcp"
echo "  不需要 ccSwitch"
echo "======================================================"
echo "  项目目录: ${PROJECT_PATH}"

# ── 1. 系统依赖 ──
if [[ "$SKIP_SYSTEM_INSTALL" -eq 0 ]]; then
  step "1/6" "检测并安装系统依赖 (Node / Git / VS Code / Claude Code)"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    if ! command_exists brew; then
      echo "未找到 Homebrew。请先安装: https://brew.sh" >&2
      exit 1
    fi
    maj="$(node_major)"
    if [[ "$maj" -lt 18 ]]; then
      ensure_brew_pkg "node@22" "Node.js 22"
      brew link --overwrite --force node@22 2>/dev/null || true
    else
      ok "Node $(node -v) 已够新"
    fi
    ensure_brew_pkg "git" "Git"
    ensure_brew_pkg "visual-studio-code" "Visual Studio Code"
    refresh_path
    if ! command_exists claude; then
      echo "  安装 Claude Code CLI ..."
      curl -fsSL https://claude.ai/install.sh | bash
      refresh_path
    else
      ok "Claude Code 已安装"
      claude update 2>/dev/null || true
    fi
    if command_exists code; then
      echo "  安装 VS Code 扩展 anthropic.claude-code ..."
      code --install-extension anthropic.claude-code --force 2>/dev/null || \
        warn "扩展安装失败，请在 VS Code 扩展市场手动安装 Claude Code"
    else
      warn "未找到 code 命令，请确认 VS Code 已安装并在 PATH 中"
    fi
  else
    # Linux: 尽量用包管理器，不强制 brew
    maj="$(node_major)"
    if [[ "$maj" -lt 18 ]]; then
      if command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y nodejs npm git || true
      elif command_exists dnf; then
        sudo dnf install -y nodejs npm git || true
      else
        warn "请手动安装 Node 18+ 和 Git 后加 --skip-system-install 重跑"
      fi
    fi
    refresh_path
    if ! command_exists claude; then
      curl -fsSL https://claude.ai/install.sh | bash
      refresh_path
    fi
    if command_exists code; then
      code --install-extension anthropic.claude-code --force 2>/dev/null || true
    fi
  fi

  refresh_path
  command_exists node || { echo "Node 不可用，请重开终端后再试" >&2; exit 1; }
  write_vscode_trust_settings
  ok "VS Code 首启打扰已关闭"
else
  step "1/6" "跳过系统安装 (--skip-system-install)"
  refresh_path
fi

# ── 2. API Key ──
step "2/6" "配置 API Key（DeepSeek 写代码 + Moonshot 看图）"

existing_deepseek=""
existing_moonshot="${MOONSHOT_API_KEY:-}"
if [[ -f "$USER_CLAUDE_SETTINGS" ]]; then
  existing_deepseek="$(node -e "
    try {
      const j=JSON.parse(require('fs').readFileSync('${USER_CLAUDE_SETTINGS}','utf8'));
      console.log((j.env&&j.env.ANTHROPIC_AUTH_TOKEN)||'');
    } catch { console.log(''); }
  ")"
  existing_moonshot="$(node -e "
    try {
      const j=JSON.parse(require('fs').readFileSync('${USER_CLAUDE_SETTINGS}','utf8'));
      console.log((j.env&&j.env.MOONSHOT_API_KEY)||'${existing_moonshot}');
    } catch { console.log('${existing_moonshot}'); }
  ")"
fi

[[ -n "$DEEPSEEK_KEY" ]] || DEEPSEEK_KEY="${DEEPSEEK_API_KEY:-}"
[[ -n "$DEEPSEEK_KEY" ]] || DEEPSEEK_KEY="$(read_api_key "DeepSeek API Key" "$existing_deepseek")"
[[ -n "$MOONSHOT_KEY" ]] || MOONSHOT_KEY="$(read_api_key "Moonshot API Key" "$existing_moonshot" 1)"

export DEEPSEEK_KEY MOONSHOT_KEY USER_CLAUDE_SETTINGS
write_user_claude_settings "$DEEPSEEK_KEY" "$MOONSHOT_KEY"
ok "DeepSeek 已写入 ~/.claude/settings.json"

if [[ -n "$MOONSHOT_KEY" ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    grep -q 'MOONSHOT_API_KEY' "${HOME}/.zprofile" 2>/dev/null || \
      echo "export MOONSHOT_API_KEY=\"${MOONSHOT_KEY}\"" >> "${HOME}/.zprofile"
  fi
  export MOONSHOT_API_KEY="$MOONSHOT_KEY"
  ok "MOONSHOT_API_KEY 已配置"
else
  warn "未配置 Moonshot Key，贴图识图 MCP 可能不可用"
fi

# Claude 橙色主题（可选）
mkdir -p "${USER_CLAUDE_DIR}/themes"
if [[ ! -f "${USER_CLAUDE_DIR}/themes/claude-brand.json" ]]; then
  cat > "${USER_CLAUDE_DIR}/themes/claude-brand.json" <<'JSON'
{"name":"Claude 官方橙","base":"dark","overrides":{"claude":"#D97757","claudeShimmer":"#E8956F","permission":"#D97757","permissionShimmer":"#E8956F","promptBorder":"#D97757","promptBorderShimmer":"#E8956F"}}
JSON
  ok "Claude 主题已写入 ~/.claude/themes/"
fi

# ── 3-5. 项目配置 + Skills ──
step "5/6" "配置项目 Hook / MCP / Skills: ${PROJECT_PATH}"
mkdir -p "${PROJECT_PATH}/.ai" "${PROJECT_PATH}/scripts" "${PROJECT_PATH}/.claude"

if [[ -z "${npm_config_registry:-}" ]]; then
  export npm_config_registry="https://registry.npmmirror.com"
fi

cd "$PROJECT_PATH"

ensure_project_hooks() {
  local base="https://raw.githubusercontent.com/G12789/ai-ship/master"
  mkdir -p scripts .claude
  for f in cc-session-start.mjs cc-session-end.mjs cc-on-image-prompt.mjs; do
    curl -fsSL "${base}/templates/scripts/${f}" -o "scripts/${f}" 2>/dev/null || true
  done
  if curl -fsSL "${base}/templates/claude.settings.hooks.json" -o /tmp/ai-ship-hooks.json 2>/dev/null; then
    node -e "
      const fs=require('fs');
      const root=process.argv[1].replace(/\\\\/g,'\\\\\\\\');
      let j=fs.readFileSync('/tmp/ai-ship-hooks.json','utf8').replace(/{{PROJECT_ROOT}}/g, root);
      const p='.claude/settings.json';
      if (!fs.existsSync(p)) fs.writeFileSync(p, j);
    " "$PROJECT_PATH"
  fi
  if [[ ! -f .claude/settings.local.json ]]; then
    cat > .claude/settings.local.json <<'JSON'
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["ai-ship"],
  "permissions": {
    "allow": ["mcp__ai-ship__*"],
    "deny": []
  }
}
JSON
  fi
  ok "Hook / MCP 本地配置已就绪"
}

if npx --yes ship-skills@latest init --skip-eval; then
  ok "ship-skills init 完成"
else
  warn "ship-skills init 失败，改用手动 Hook + ctxshot ..."
  ensure_project_hooks
  npx --yes ctxshot@latest --compact --diff --depth 3 --max 120 -o .ai/context.md 2>/dev/null || true
fi
ensure_project_hooks

# ── 6. 预热 ──
step "6/6" "预热 npm 包（首次开聊更快）"
npm cache add ai-ship-mcp@latest 2>/dev/null && ok "ai-ship-mcp 已缓存" || skip "预热跳过"
npm cache add ctxshot@latest 2>/dev/null && ok "ctxshot 已缓存" || skip "预热跳过"

echo ""
echo "======================================================"
echo "  安装完成！"
echo "======================================================"
echo ""
echo "  1. 用 VS Code 打开项目文件夹: ${PROJECT_PATH}"
echo "  2. 打开 Claude Code 侧边栏，@import 点「允许」"
echo "  3. MCP 面板 ai-ship 应变绿"
echo "  4. 贴图测试识图；说「继续上次」应读到 .ai/focus.md"
echo ""
echo "  主模型: deepseek-v4-pro[1m]  |  看图: Moonshot 旁路"
echo "  不需要 ccSwitch"
echo ""

if [[ "$OPEN_VSCODE" -eq 1 ]] && command_exists code; then
  echo "  正在打开 VS Code ..."
  code "$PROJECT_PATH" 2>/dev/null || true
fi
