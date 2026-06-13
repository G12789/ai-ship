---
name: vision-bridge
description: >
  Use when the main LLM cannot see images (DeepSeek text, local LLMs). Call vision-bridge-mcp to describe screenshots, UI, TouchDesigner networks, or OCR errors into text.
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: mcp
  homepage: https://github.com/G12789/ai-ship
---

# vision-bridge — 文本模型看图

## 何时使用

- Claude Code / VS Code 主模型是 **DeepSeek 文本版**（无视觉）
- 用户 @ 了截图、设计稿、TouchDesigner 节点图、CI 失败截图
- 需要 OCR 终端/日志图片

## 架构（双模型）

```
主模型 DeepSeek（文本）  ← 读文字
        ↑
vision-bridge-mcp        ← 图片转文字
        ↑
旁路视觉模型（Ollama llava / Qwen-VL / gpt-4o-mini）
```

## MCP 配置

```json
{
  "mcpServers": {
    "vision-bridge": {
      "command": "npx",
      "args": ["-y", "vision-bridge-mcp@latest"],
      "env": {
        "VISION_BRIDGE_BASE_URL": "http://localhost:11434/v1",
        "VISION_BRIDGE_MODEL": "llava"
      }
    }
  }
}
```

## 步骤

1. `ollama pull llava`（或配置云视觉 API）
2. 调用 `describe_image({ path, mode })`
   - `touchdesigner` — 节点网截图
   - `ui` — IDE/设置页
   - `ocr` — 纯文字提取
3. 把返回的 Markdown 当作上下文继续推理

## 工具

- `describe_image` · `extract_text` · `vision_status`

npm: `npx vision-bridge-mcp`
