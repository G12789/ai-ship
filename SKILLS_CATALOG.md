# AI Ship Skills 目录 v0.2.0（收敛版）

## 默认安装（5 个）

| Skill | 类别 | 说明 |
|---|---|---|
| `session-start` | workflow | 每天新会话 → ctxshot 打包 `.ai/context.md` |
| `vision-auto` | mcp | 文本模型贴图 → 自动调 vision-bridge-mcp |
| `prompt-guard` | quality | 改 prompt 后 → evaldrift 回归 |
| `api-bridge` | mcp | REST API → mcp-quickstart 脚手架 |
| `ship-check` | workflow | 提交前 ctx + eval 检查 |

## MCP 配套

| MCP | npm | 说明 |
|---|---|---|
| ctxshot-mcp | `npx ctxshot-mcp@latest` | 每日项目简报 |
| vision-bridge-mcp | `npx vision-bridge-mcp@latest` | DeepSeek 文本看图（需旁路视觉 API） |

## 归档（`skills/_archive/`，默认不安装）

ableton-m4l · blender-bpy · ci-log-triage · env-diff · ffmpeg-reel · glsl-live-fix · homeassistant-yaml · monorepo-gate · osc-midi-probe · pr-diff-brief · processing-port · qgis-pyqgis · rules-drift · session-handoff · subagent-receipt · terminal-replay · touchdesigner-dat · vision-bridge（已被 vision-auto 替代）· wrangler-coach

安装：`npx ai-ship install -s session-start,vision-auto`
