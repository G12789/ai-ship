---
name: touchdesigner-dat
description: >
  Use for TouchDesigner projects. Generates Python DAT scripts, GLSL hints, operator wiring notes. Pair with vision-bridge for network screenshots.
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: creative-coding
  homepage: https://github.com/G12789/ai-ship
---

# touchdesigner-dat — TD Python DAT 生成

## 何时使用

- 「有没有 Codex 接入 TouchDesigner 的 skill？」
- 写 OSC/MIDI/CHOP 逻辑
- 看不懂节点网（先 `describe_image` mode=touchdesigner）

## 步骤

1. 描述需求（例：「OSC 接收 /tuio/2Dcur 驱动 Instancing」）
2. 生成 Python DAT 代码 → 粘贴到 Text DAT
3. 给出接线说明（哪个 OP 连哪个）

## 模板

见 `templates/osc-receiver.py`、`audio-chop-drive.py`

## 限制

- 不能直接编辑 .toe 二进制
- 复杂图建议 TD 内跑导出脚本
