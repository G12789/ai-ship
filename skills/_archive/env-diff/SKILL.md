---
name: env-diff
description: >
  Use when works on my machine but fails in CI/teammate. Compares .env.example vs process.env keys mentioned in code.
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: devops
  homepage: https://github.com/G12789/ai-ship
---

# env-diff — 环境变量对齐

## 步骤

1. 读 `.env.example`
2. grep `process.env` / `os.environ`
3. 列出缺失键（不读真实 .env 秘密）
