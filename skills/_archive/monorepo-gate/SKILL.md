---
name: monorepo-gate
description: >
  Use in monorepos. When package A changes, lists which packages need rebuild/test.
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: quality
  homepage: https://github.com/G12789/ai-ship
---

# monorepo-gate — 改包影响面

## 步骤

1. 识别 workspace 根
2. 看变更路径属于哪个 package
3. 建议 `npm run test -w pkg` 顺序
