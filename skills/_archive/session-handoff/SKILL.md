---
name: session-handoff
description: >
  Use when switching between Cursor, Claude Code, VS Code, or models. Packs ctxshot brief, git status, and handoff notes into .ai/handoff.md.
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: workflow
  homepage: https://github.com/G12789/ai-ship
---

# session-handoff — 换 IDE/模型不丢上下文

## 何时使用

- 从 Cursor 换到 Claude Code / VS Code
- 换 DeepSeek ↔ Claude ↔ GPT
- 下班前打包「明天接着干」

## 步骤

```bash
node scripts/handoff.mjs
```

生成 `.ai/handoff.md`：
- ctxshot 项目简报
- 当前分支 + 未提交文件
- 最近 3 条 commit 信息

## 相关

- 依赖 [ctxshot](https://github.com/G12789/ctxshot)
- 配合 vision-bridge 交接截图说明
