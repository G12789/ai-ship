---
name: pr-diff-brief
description: >
  Use before reviewing or continuing a PR. Summarizes git diff into a compact markdown brief (~500 tokens).
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: workflow
  homepage: https://github.com/G12789/ai-ship
---

# pr-diff-brief — PR 变更简报

## 步骤

```bash
node scripts/pr-brief.mjs
# 或指定范围
node scripts/pr-brief.mjs main...HEAD
```

输出 `.ai/pr-brief.md`：文件列表、stat、关键 hunks 摘要。
