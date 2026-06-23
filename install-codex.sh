#!/usr/bin/env bash
# Codex 一键安装 — macOS / Linux
# Node/Git/VS Code + Codex CLI + DeepSeek 写代码 + Kimi 自动识图（经本地协议代理）
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.sh | bash
#   bash install-codex.sh --skip-system-install
set -euo pipefail

SKIP_SYSTEM_INSTALL=0
DEEPSEEK_KEY=""
KIMI_KEY=""
OUTPUT_DIR=""
PROXY_PORT=8787

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-system-install) SKIP_SYSTEM_INSTALL=1; shift ;;
    --deepseek-key) DEEPSEEK_KEY="${2:-}"; shift 2 ;;
    --kimi-key) KIMI_KEY="${2:-}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help)
      echo "bash install-codex.sh [--skip-system-install] [--output-dir DIR]"
      echo "环境变量: DEEPSEEK_API_KEY / KIMI_API_KEY"
      exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$OUTPUT_DIR" ]] || OUTPUT_DIR="$(pwd)"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
CODEX_DIR="${HOME}/.codex"
CODEX_CONFIG="${CODEX_DIR}/config.toml"
PROXY_CONFIG="${OUTPUT_DIR}/codeproxy.config.json"

step() { echo ""; echo "== [$1] $2"; }
ok() { echo "  ✓ $*"; }
warn() { echo "  ! $*" >&2; }
has() { command -v "$1" >/dev/null 2>&1; }

refresh_path() {
  export PATH="${HOME}/.local/bin:${PATH}"
  if [[ -d "${HOME}/.nvm/versions/node" ]]; then
    local nv; nv="$(ls -1d "${HOME}"/.nvm/versions/node/*/bin 2>/dev/null | tail -1 || true)"
    [[ -n "$nv" ]] && export PATH="${nv}:${PATH}"
  fi
}
node_major() { has node && node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0; }

read_key() {
  local prompt="$1" optional="${2:-0}" v
  if [[ "$optional" == "1" ]]; then
    read -r -s -p "${prompt}（可选，Enter 跳过识图）: " v; echo ""; echo "$v"; return
  fi
  while true; do read -r -s -p "${prompt}（必填）: " v; echo ""; [[ -n "$v" ]] && { echo "$v"; return; }; done
}

echo ""
echo "======================================================"
echo "  Codex 一键安装 (macOS / Linux)"
echo "  DeepSeek 写代码 + Kimi 识图（本地协议代理）"
echo "======================================================"
echo "  配置输出目录: ${OUTPUT_DIR}"

# ── 1. 系统依赖 ──
if [[ "$SKIP_SYSTEM_INSTALL" -eq 0 ]]; then
  step "1/5" "检测并安装系统依赖 (Node / Git / VS Code)"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if ! has brew; then echo "未找到 Homebrew，请先装: https://brew.sh" >&2; exit 1; fi
    if [[ "$(node_major)" -lt 18 ]]; then brew install node@22 && brew link --overwrite --force node@22 2>/dev/null || true; else ok "Node $(node -v) 已够新"; fi
    brew list git &>/dev/null || brew install git
    brew list --cask visual-studio-code &>/dev/null || brew install --cask visual-studio-code || true
  else
    if [[ "$(node_major)" -lt 18 ]]; then
      if has apt-get; then sudo apt-get update && sudo apt-get install -y nodejs npm git || true
      elif has dnf; then sudo dnf install -y nodejs npm git || true
      else warn "请手动装 Node 18+ 和 Git 后加 --skip-system-install 重跑"; fi
    fi
  fi
  refresh_path
  has node || { echo "Node 不可用，请重开终端再试" >&2; exit 1; }
else
  step "1/5" "跳过系统安装"; refresh_path
fi

# ── 2. Codex CLI + 代理 ──
step "2/5" "安装 Codex CLI 和 @codeproxy/cli"
if has codex; then echo "  Codex 已安装 ($(codex --version 2>/dev/null)) → 更新"; fi
npm install -g @openai/codex 2>/dev/null || warn "Codex 安装可能失败，可手动 npm i -g @openai/codex"
npm install -g @codeproxy/cli 2>/dev/null || true
refresh_path
has codex && ok "Codex CLI 就绪：$(codex --version 2>/dev/null)" || warn "Codex 未进 PATH，重开终端验证"

# ── 3. API Key ──
step "3/5" "配置 API Key（DeepSeek 写代码 + Kimi 看图）"
[[ -n "$DEEPSEEK_KEY" ]] || DEEPSEEK_KEY="${DEEPSEEK_API_KEY:-}"
[[ -n "$DEEPSEEK_KEY" ]] || { echo "  获取: https://platform.deepseek.com/"; DEEPSEEK_KEY="$(read_key 'DeepSeek API Key')"; }
[[ -n "$KIMI_KEY" ]] || KIMI_KEY="${KIMI_API_KEY:-}"
[[ -n "$KIMI_KEY" ]] || { echo "  获取: https://platform.moonshot.cn/"; KIMI_KEY="$(read_key 'Kimi Coding API Key' 1)"; }

# ── 4. 写配置 ──
step "4/5" "写入代理配置 + ~/.codex/config.toml"
DEEPSEEK_KEY="$DEEPSEEK_KEY" KIMI_KEY="$KIMI_KEY" PROXY_CONFIG="$PROXY_CONFIG" node <<'NODE'
const fs = require("fs");
const cfg = {
  version: "1.0",
  currentUpstream: "deepseek",
  timeoutMs: 300000,
  upstreams: {
    deepseek: {
      baseUrl: "https://api.deepseek.com/v1",
      apiKey: process.env.DEEPSEEK_KEY,
      model: "deepseek-v4-pro",
      dropImages: true,
      fallback: "kimi",
    },
    kimi: {
      baseUrl: "https://api.kimi.com/coding/v1",
      apiKey: process.env.KIMI_KEY || "",
      model: "kimi-for-coding",
      headers: { "user-agent": "KimiCLI/1.39.0" },
    },
  },
};
fs.writeFileSync(process.env.PROXY_CONFIG, JSON.stringify(cfg, null, 2) + "\n");
NODE
ok "代理配置 → ${PROXY_CONFIG}"
[[ -n "$KIMI_KEY" ]] || warn "未填 Kimi Key：贴图时无法自动识图"

mkdir -p "$CODEX_DIR"
[[ -f "$CODEX_CONFIG" ]] && cp "$CODEX_CONFIG" "${CODEX_CONFIG}.bak-$(date +%Y%m%d-%H%M%S)" && echo "  - 原 config.toml 已备份"
cat > "$CODEX_CONFIG" <<TOML
# Codex 双模型：DeepSeek 主，贴图自动经代理切 Kimi
model_provider = "local"
model = "deepseek-v4-pro"

[model_providers.local]
name = "DeepSeek+Kimi Local Proxy"
base_url = "http://127.0.0.1:${PROXY_PORT}/v1"
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
TOML
ok "Codex 配置 → ${CODEX_CONFIG}"

# ── 5. 启动器 ──
step "5/5" "生成启动器 codex-start.sh"
LAUNCHER="${OUTPUT_DIR}/codex-start.sh"
cat > "$LAUNCHER" <<LSH
#!/usr/bin/env bash
set -euo pipefail
echo "启动本地协议代理 (端口 ${PROXY_PORT})..."
npx --yes @codeproxy/cli --config "${PROXY_CONFIG}" --host 127.0.0.1 --port ${PROXY_PORT} >/tmp/codeproxy.log 2>&1 &
PROXY_PID=\$!
trap "kill \$PROXY_PID 2>/dev/null || true" EXIT
for i in \$(seq 1 15); do
  curl -s http://127.0.0.1:${PROXY_PORT}/v1/models >/dev/null 2>&1 && break
  sleep 1
done
echo "Codex 已连 DeepSeek（贴图自动 Kimi）。快模型: codex -p flash"
codex -p deepseek
LSH
chmod +x "$LAUNCHER"
ok "启动器 → ${LAUNCHER}"

echo ""
echo "======================================================"
echo "  安装完成！"
echo "======================================================"
echo "  运行: bash ${LAUNCHER}"
echo "  自动起代理 → 进 Codex（DeepSeek 写代码 / 贴图自动 Kimi）"
echo ""
