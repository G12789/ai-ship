# ship-skills（ai-ship）

[![CI](https://github.com/G12789/ai-ship/actions/workflows/ci.yml/badge.svg)](https://github.com/G12789/ai-ship/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/ship-skills?color=cb3837&logo=npm)](https://www.npmjs.com/package/ship-skills)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-7c3aed)](https://agentskills.io)

> npm 包名 **`ship-skills`**，CLI 命令 **`ai-ship`**。  
> 可拆装的 Agent Skills 工作流包 — 每个模块是 `SKILL.md` + 可执行 scripts。

```bash
npx ship-skills init          # 一键：5 个 Skill + CLAUDE.md + evaldrift + 首份上下文
npx ai-ship ctx -o .ai/context.md
npx ai-ship check
```

> `ai-ship` 在 npm 已被占用，故发布名为 `ship-skills`。

---

## 解决什么问题

| 场景 | 笨办法 | ship-skills |
|---|---|---|
| 每天新 AI 会话 | 反复解释项目 | `session-start` → ctxshot 简报 |
| DeepSeek 文本贴图 | 说看不到图 | `vision-auto` + vision-bridge-mcp |
| 改 prompt 怕退化 | 靠感觉 | `prompt-guard` → evaldrift |
| 接 REST API | 从零写 MCP | `api-bridge` → mcp-quickstart |
| 提交前检查 | 漏测 | `ship-check` → ctx + eval |

---

## 五个核心 Skill（v0.2 收敛版）

| Skill | CLI / MCP | 频率 |
|---|---|---|
| **session-start** | ctxshot | 每天 / 每个新会话 |
| **vision-auto** | vision-bridge-mcp | 贴截图 / DeepSeek 文本模型 |
| **prompt-guard** | evaldrift | 改 prompt / 模板时 |
| **api-bridge** | mcp-quickstart | 接 REST API 时 |
| **ship-check** | ctxshot + evaldrift | 提交 / PR 前 |

> 19 个 niche Skill（blender、TD、ffmpeg 等）已移至 `skills/_archive/`，默认不安装，仅作参考。

---

## 30 秒接入

### 项目内一键配置

```bash
cd your-project
npx ship-skills init
```

`init` 会自动：

1. 安装 5 个 Skill 到 `.agents/skills` 等目录
2. 生成 `AGENTS.md`
3. 创建 / 追加 `CLAUDE.md`（含 **vision-auto 看图硬规则**）
4. `.gitignore` 追加 `.ai/`
5. 初始化 evaldrift（若无配置）
6. 生成首份 `.ai/context.md`

跳过 evaldrift：`npx ship-skills init --skip-eval`

### 配套 MCP（推荐一起装）

**看图（DeepSeek 文本必装）：**

```json
{
  "mcpServers": {
    "vision-bridge": {
      "command": "npx",
      "args": ["-y", "vision-bridge-mcp@latest"],
      "env": {
        "VISION_BRIDGE_BASE_URL": "https://dashscope.aliyuncs.com/compatible-mode/v1",
        "VISION_BRIDGE_API_KEY": "sk-你的密钥",
        "VISION_BRIDGE_MODELS": "qwen-vl-max,qwen2.5-vl-72b-instruct"
      }
    }
  }
}
```

完整说明：[vision-bridge-mcp README](https://github.com/G12789/vision-bridge-mcp)

**每日简报：**

```json
"ctxshot": {
  "command": "npx",
  "args": ["-y", "ctxshot-mcp@latest"]
}
```

### 只装部分 Skill

```bash
npx ai-ship install -s vision-auto,session-start
npx ai-ship install -g -a cursor,claude    # 装到用户全局目录
npx ai-ship list                           # 列出内置 skill
```

---

## CLI 命令

| 命令 | 说明 |
|---|---|
| `ai-ship init` | 一键配置（推荐首次） |
| `ai-ship install` | 安装 Skill 到 Agent 目录 |
| `ai-ship ctx` | 打包项目上下文 → ctxshot |
| `ai-ship eval` | prompt 回归 → evaldrift |
| `ai-ship mcp <name>` | 生成 MCP Server → mcp-quickstart |
| `ai-ship check` | 提交前：刷新上下文 + eval |
| `ai-ship list` | 列出内置 skills |
| `ai-ship doctor` | 校验 bundle 完整性 |

### ctx 常用选项

```bash
npx ai-ship ctx --compact --diff -o .ai/context.md
```

---

## 典型一天工作流

```
早上开新会话
  → Agent 读 session-start Skill
  → 调 ctxshot-mcp session_brief 或 ai-ship ctx
  → @.ai/context.md

开发中贴报错截图
  → vision-auto 触发
  → 调 vision-bridge describe_image(mode: ui)
  → 根据描述修 bug

改完 system prompt
  → prompt-guard → npx evaldrift run

提交前
  → npx ai-ship check
```

---

## AI Ship Kit 四件套

| 包 | npm | 角色 |
|---|---|---|
| ctxshot-mcp | `npx ctxshot-mcp` | 每日项目简报 |
| vision-bridge-mcp | `npx vision-bridge-mcp` | 文本模型看图 |
| evaldrift | `npx evaldrift` | Prompt 回归 |
| ship-skills | `npx ship-skills` | 工作流 Skill 包（本仓库） |

---

## 和竞品怎么选？

| 需求 | 用谁 |
|---|---|
| 发现海量 skills | `npx skills`（Vercel） |
| 全库打包 | Repomix |
| **日常五步法 + DeepSeek 看图** | **ship-skills + vision-bridge-mcp** |
| 只要简报 / 只要测 prompt | 单独 `ctxshot` / `evaldrift` |
| TouchDesigner 控网 | [td-mcp](https://github.com/Pantani/tdmcp)（不自研） |

完整对比：[PRODUCT_COMPARISON.md](./PRODUCT_COMPARISON.md)

---

## 常见问题

### `init` 后 Agent 仍说看不到图？

1. MCP 里是否装了 `vision-bridge` 且为绿色
2. `CLAUDE.md` 是否有 vision 规则（`init` 应已写入）
3. `VISION_BRIDGE_API_KEY` 是否填对

### `ai-ship` 和 `ship-skills` 什么关系？

同一个包。`npm install ship-skills` 后命令行用 `ai-ship`。

### 旧版 23 个 Skill 去哪了？

`skills/_archive/`。需要时可手动复制，不再默认安装。

---

## License

MIT
