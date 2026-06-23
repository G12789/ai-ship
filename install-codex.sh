#!/usr/bin/env bash
# Codex 一键安装 — macOS / Linux
# Node/Git/VS Code + Codex CLI(终端版) + Codex IDE 插件
# 模型来源装时可选：
#   - 国产：DeepSeek 写代码 + Kimi 自动识图（经本地 @codeproxy/cli 协议代理）
#   - 官方：原生 gpt-5.x（ChatGPT 账号登录，需订阅）
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/G12789/ai-ship/master/install-codex.sh | bash
#   bash install-codex.sh --skip-system-install --source domestic
set -euo pipefail

SKIP_SYSTEM_INSTALL=0
SOURCE=""
NO_EXTENSION=0
DEEPSEEK_KEY=""
KIMI_KEY=""
OUTPUT_DIR=""
PROXY_PORT=8787
CODEX_EXT_ID="openai.chatgpt"

# npm 走国内镜像（未自定义时），保证国内无 VPN 也能装 codex / 代理包
[[ -n "${npm_config_registry:-}" ]] || export npm_config_registry="https://registry.npmmirror.com"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-system-install) SKIP_SYSTEM_INSTALL=1; shift ;;
    --source) SOURCE="${2:-}"; shift 2 ;;
    --no-extension) NO_EXTENSION=1; shift ;;
    --deepseek-key) DEEPSEEK_KEY="${2:-}"; shift 2 ;;
    --kimi-key) KIMI_KEY="${2:-}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help)
      echo "bash install-codex.sh [--skip-system-install] [--source domestic|official] [--no-extension] [--output-dir DIR]"
      echo "环境变量: DEEPSEEK_API_KEY / KIMI_API_KEY"
      exit 0 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$OUTPUT_DIR" ]] || OUTPUT_DIR="$(pwd)"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
CODEX_DIR="${HOME}/.codex"
mkdir -p "$CODEX_DIR"
CODEX_CONFIG="${CODEX_DIR}/config.toml"
CODEX_AUTH="${CODEX_DIR}/auth.json"
# 代理配置与 codex 配置同放 ~/.codex，路径稳定
PROXY_CONFIG="${CODEX_DIR}/codeproxy.config.json"

step() { echo ""; echo "== [$1] $2"; }
ok() { echo "  ✓ $*"; }
INSTALL_WARNINGS=()
warn() { echo "  ! $*" >&2; INSTALL_WARNINGS+=("$*"); }
has() { command -v "$1" >/dev/null 2>&1; }

refresh_path() {
  export PATH="${HOME}/.local/bin:${PATH}"
  if [[ -d "${HOME}/.nvm/versions/node" ]]; then
    local nv; nv="$(ls -1d "${HOME}"/.nvm/versions/node/*/bin 2>/dev/null | tail -1 || true)"
    [[ -n "$nv" ]] && export PATH="${nv}:${PATH}"
  fi
}
node_major() { has node && node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0; }

# npm 全局安装带重试（网络抖动不致命）
npm_install_retry() {
  local pkg="$1" i
  for i in 1 2 3; do
    npm install -g "$pkg" >/dev/null 2>&1 && return 0
    [[ $i -lt 3 ]] && { echo "  $pkg 第 $i 次未成功，重试 ..."; sleep 2; }
  done
  return 1
}

# 交互式读取（兼容 curl|bash：从 /dev/tty 读，否则从 stdin）
read_key() {
  local prompt="$1" optional="${2:-0}" v src=/dev/stdin
  [[ -e /dev/tty ]] && src=/dev/tty
  if [[ "$optional" == "1" ]]; then
    read -r -s -p "${prompt}（可选，Enter 跳过识图）: " v <"$src" || v=""; echo "" >&2; echo "$v"; return
  fi
  while true; do read -r -s -p "${prompt}（必填）: " v <"$src" || v=""; echo "" >&2; [[ -n "$v" ]] && { echo "$v"; return; }; done
}

resolve_source() {
  if [[ -n "$SOURCE" ]]; then echo "$SOURCE"; return; fi
  if [[ -n "$DEEPSEEK_KEY" || -n "${DEEPSEEK_API_KEY:-}" ]]; then echo "domestic"; return; fi
  if [[ -e /dev/tty ]]; then
    {
      echo ""
      echo "  选择模型来源："
      echo "    [1] 国产 DeepSeek 写代码 + Kimi 识图（便宜，国内无 VPN 可用）  ← 默认"
      echo "    [2] 官方原生 gpt-5.x（ChatGPT 账号登录，需订阅 + 通常需梯子）"
    } >&2
    local c=""; read -r -p "  输入 1 或 2（Enter=1）: " c </dev/tty || c=""
    [[ "$c" == "2" ]] && { echo "official"; return; }
  fi
  echo "domestic"
}

# 把 Codex IDE 插件装进检测到的编辑器（VS Code / Cursor / Windsurf）
# 只装进「真正的 VS Code」(code 命令)——与 Claude Code 接入 VS Code 一致，不装 Cursor/Windsurf
install_codex_extension() {
  [[ "$NO_EXTENSION" -eq 1 ]] && { echo "  - 已指定 --no-extension，跳过 VS Code 插件"; return; }
  if ! has code; then
    warn "未找到 VS Code 的 code 命令。请装 VS Code（并在命令面板执行 Shell Command: Install 'code'），再在扩展面板搜「Codex」(OpenAI)"
    return 0
  fi
  if code --list-extensions 2>/dev/null | grep -qix "$CODEX_EXT_ID"; then
    ok "Codex 插件已在 VS Code（已是最新）"; return 0
  fi
  if code --install-extension "$CODEX_EXT_ID" --force >/dev/null 2>&1 \
     && code --list-extensions 2>/dev/null | grep -qix "$CODEX_EXT_ID"; then
    ok "Codex 插件已装入 VS Code（侧边栏可贴图识图）"
  else
    warn "装 Codex 插件未确认，可在 VS Code 扩展面板搜「Codex」(OpenAI) 手动装"
  fi
  return 0
}

# 打开真正的 VS Code（不开 Cursor）
open_vscode() {
  has code && code . >/dev/null 2>&1 || true
}

echo ""
echo "======================================================"
echo "  Codex 一键安装 (macOS / Linux)"
echo "  CLI 终端版 + IDE 插件 + 模型接入"
echo "======================================================"
echo "  配置输出目录: ${OUTPUT_DIR}"

SOURCE="$(resolve_source)"
if [[ "$SOURCE" == "official" ]]; then
  echo "  模型来源：官方原生 gpt-5.x（ChatGPT 登录）"
else
  SOURCE="domestic"
  echo "  模型来源：国产 DeepSeek + Kimi（本地代理）"
fi

# ── 1. 系统依赖 ──
if [[ "$SKIP_SYSTEM_INSTALL" -eq 0 ]]; then
  step "1/6" "检测并安装系统依赖 (Node / Git / VS Code)"
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
  step "1/6" "跳过系统安装"; refresh_path
fi

# ── 2. Codex CLI（国产再装代理）──
step "2/6" "安装 Codex CLI"
if has codex; then echo "  Codex 已安装 ($(codex --version 2>/dev/null)) → 尝试更新"; fi
npm_install_retry "@openai/codex" || warn "Codex 安装未成功（多为网络），可手动 npm i -g @openai/codex"
refresh_path
has codex && ok "Codex CLI 就绪：$(codex --version 2>/dev/null)" || warn "Codex 未进 PATH，重开终端验证"
if [[ "$SOURCE" == "domestic" ]]; then
  echo "  预拉 @codeproxy/cli（国产协议代理）..."
  npm_install_retry "@codeproxy/cli" || warn "@codeproxy/cli 预装未成功，启动器首次会用 npx 自动拉取"
fi

if [[ "$SOURCE" == "official" ]]; then
  # ── 官方原生路径 ──
  step "3/6" "模型来源：官方原生（跳过 API Key / 代理）"
  echo "  - 官方模式用 ChatGPT 账号登录，无需 DeepSeek/Kimi Key"

  step "4/6" "写入 ~/.codex/config.toml（官方）"
  mkdir -p "$CODEX_DIR"
  [[ -f "$CODEX_CONFIG" ]] && cp "$CODEX_CONFIG" "${CODEX_CONFIG}.bak-$(date +%Y%m%d-%H%M%S)" && echo "  - 原 config.toml 已备份"
  cat > "$CODEX_CONFIG" <<'TOML'
# Codex 官方原生模式：用 ChatGPT 账号登录（codex login / 插件里 Sign in with ChatGPT）
model = "gpt-5.1-codex"
model_reasoning_effort = "medium"
TOML
  ok "Codex 配置 → ${CODEX_CONFIG}"

  step "5/6" "安装 Codex IDE 插件"
  install_codex_extension

  step "6/6" "生成启动器 codex-start.sh"
  LAUNCHER="${OUTPUT_DIR}/codex-start.sh"
  cat > "$LAUNCHER" <<'LSH'
#!/usr/bin/env bash
if ! command -v codex >/dev/null 2>&1; then
  echo "[错误] 未找到 codex 命令。请开新终端，或运行: npm i -g @openai/codex"
  exit 1
fi
echo "官方原生模式：首次请先登录 ChatGPT（codex login，或 IDE 插件里 Sign in with ChatGPT）"
codex
LSH
  chmod +x "$LAUNCHER"
  ok "启动器 → ${LAUNCHER}"
else
  # ── 国产路径 ──
  step "3/6" "配置 API Key（DeepSeek 写代码 + Kimi 看图）"
  [[ -n "$DEEPSEEK_KEY" ]] || DEEPSEEK_KEY="${DEEPSEEK_API_KEY:-}"
  [[ -n "$DEEPSEEK_KEY" ]] || { echo "  获取: https://platform.deepseek.com/"; DEEPSEEK_KEY="$(read_key 'DeepSeek API Key')"; }
  [[ -n "$KIMI_KEY" ]] || KIMI_KEY="${KIMI_API_KEY:-}"
  [[ -n "$KIMI_KEY" ]] || { echo "  获取: https://platform.moonshot.cn/"; KIMI_KEY="$(read_key 'Kimi Coding API Key' 1)"; }

  step "4/6" "写入代理配置 + ~/.codex/config.toml"
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
  # codex 0.142+ 废弃 config.toml 内的 [profiles.*]（用 -p 会报错），改为独立文件 ~/.codex/<名>.config.toml
  cat > "$CODEX_CONFIG" <<TOML
# Codex 双模型：DeepSeek 主，贴图自动经代理切 Kimi
# preferred_auth_method=apikey：让 VS Code 的 Codex 插件不弹 ChatGPT 登录
# 默认即 DeepSeek 写代码；快模型 codex -p flash；纯 Kimi codex -p kimi
model_provider = "local"
model = "deepseek-v4-pro"
model_context_window = 1000000
preferred_auth_method = "apikey"

[model_providers.local]
name = "DeepSeek+Kimi Local Proxy"
base_url = "http://127.0.0.1:${PROXY_PORT}/v1"
wire_api = "responses"
requires_openai_auth = false
stream_idle_timeout_ms = 300000
TOML
  cat > "${CODEX_DIR}/flash.config.toml" <<TOML
# DeepSeek 快模型。用 codex -p flash 选择
model_provider = "local"
model = "deepseek-v4-flash"
model_context_window = 1000000
preferred_auth_method = "apikey"

[model_providers.local]
name = "DeepSeek+Kimi Local Proxy"
base_url = "http://127.0.0.1:${PROXY_PORT}/v1"
wire_api = "responses"
requires_openai_auth = false
stream_idle_timeout_ms = 300000
TOML
  cat > "${CODEX_DIR}/kimi.config.toml" <<TOML
# Kimi 识图/长上下文。用 codex -p kimi 选择
model_provider = "local"
model = "kimi-for-coding"
model_context_window = 256000
preferred_auth_method = "apikey"

[model_providers.local]
name = "DeepSeek+Kimi Local Proxy"
base_url = "http://127.0.0.1:${PROXY_PORT}/v1"
wire_api = "responses"
requires_openai_auth = false
stream_idle_timeout_ms = 300000
TOML
  ok "Codex 配置 → ${CODEX_CONFIG}（+ flash/kimi profile 文件）"

  # 插件 apikey 模式需要 auth.json 里存在一个 key（本地代理不校验，占位即可）
  [[ -f "$CODEX_AUTH" ]] && cp "$CODEX_AUTH" "${CODEX_AUTH}.bak-$(date +%Y%m%d-%H%M%S)" && echo "  - 原 auth.json 已备份"
  printf '%s' '{"OPENAI_API_KEY":"sk-local-proxy-placeholder"}' > "$CODEX_AUTH"
  ok "auth.json 占位写入（IDE 插件免登录用）"

  step "5/6" "安装 Codex IDE 插件"
  install_codex_extension

  step "6/6" "生成启动器（终端版 codex-start.sh + IDE 代理版 codex-proxy.sh）"

  # IDE 代理保活：只起代理并常驻，IDE 用 Codex 前先跑它（别关）
  PROXYSH="${OUTPUT_DIR}/codex-proxy.sh"
  cat > "$PROXYSH" <<PSH
#!/usr/bin/env bash
echo "启动本地协议代理 (端口 ${PROXY_PORT})，IDE 用 Codex 期间请保持本窗口开着..."
exec npx --yes @codeproxy/cli --config "${PROXY_CONFIG}" --host 127.0.0.1 --port ${PROXY_PORT}
PSH
  chmod +x "$PROXYSH"
  ok "IDE 代理保活 → ${PROXYSH}"

  LAUNCHER="${OUTPUT_DIR}/codex-start.sh"
  cat > "$LAUNCHER" <<LSH
#!/usr/bin/env bash
if ! command -v codex >/dev/null 2>&1; then
  echo "[错误] 未找到 codex 命令。请开新终端，或运行: npm i -g @openai/codex"
  exit 1
fi
echo "启动本地协议代理 (端口 ${PROXY_PORT})..."
npx --yes @codeproxy/cli --config "${PROXY_CONFIG}" --host 127.0.0.1 --port ${PROXY_PORT} >/tmp/codeproxy.log 2>&1 &
PROXY_PID=\$!
trap "kill \$PROXY_PID 2>/dev/null || true" EXIT
for i in \$(seq 1 30); do
  curl -s http://127.0.0.1:${PROXY_PORT}/v1/models >/dev/null 2>&1 && break
  sleep 1
done
echo "Codex 已连 DeepSeek（贴图自动 Kimi）。快模型: codex -p flash | 纯Kimi: codex -p kimi"
echo "IDE 里用：跑 codex-proxy.sh 让代理常驻，再在 VS Code 侧边栏打开 Codex 贴图"
codex
LSH
  chmod +x "$LAUNCHER"
  ok "终端启动器 → ${LAUNCHER}"
fi

echo ""
if [[ "${#INSTALL_WARNINGS[@]}" -gt 0 ]]; then
  echo "======================================================"
  echo "  安装结束，但有 ${#INSTALL_WARNINGS[@]} 项需注意（多为网络，可重跑或手动处理）："
  echo "======================================================"
  for w in "${INSTALL_WARNINGS[@]}"; do echo "    ! $w"; done
  echo ""
else
  echo "======================================================"
  echo "  安装完成！"
  echo "======================================================"
fi
if [[ "$SOURCE" == "official" ]]; then
  echo "  终端: bash ${LAUNCHER}（或 codex），首次 codex login 登录 ChatGPT"
  echo "  IDE : VS Code 侧边栏打开 Codex → Sign in with ChatGPT"
else
  echo "  终端: bash ${LAUNCHER} → 自动起代理 → 进 Codex（贴图自动 Kimi）"
  echo "  IDE : 先运行 codex-proxy.sh 让代理常驻，再在 VS Code 侧边栏用 Codex 贴图识图"
fi
echo ""

# 国产模式后台拉起代理，并打开真正的 VS Code（不开 Cursor）
if [[ "$NO_EXTENSION" -ne 1 ]] && has code; then
  if [[ "$SOURCE" != "official" ]]; then
    nohup npx --yes @codeproxy/cli --config "${PROXY_CONFIG}" --host 127.0.0.1 --port ${PROXY_PORT} >/tmp/codeproxy.log 2>&1 &
    ok "已在后台启动本地代理（端口 ${PROXY_PORT}）；重启后用 codex-proxy.sh 再起"
  fi
  echo "  正在打开 VS Code，可在侧边栏直接用 Codex ..."
  open_vscode
fi
echo ""
