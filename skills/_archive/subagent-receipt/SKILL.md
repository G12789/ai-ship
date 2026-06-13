---
name: subagent-receipt
description: >
  Use after a background/subagent task completes. Structures what changed, what was tested, and open risks.
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: workflow
  homepage: https://github.com/G12789/ai-ship
---

# subagent-receipt — 子 Agent 交接收据

## 输出模板

```markdown
## Subagent receipt
- Task:
- Files changed:
- Commands run:
- Tests:
- Risks / not done:
```

写入 `.ai/subagent-receipt.md` 供主会话读取。
