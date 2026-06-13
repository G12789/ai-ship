---
name: rules-drift
description: >
  Use when AGENTS.md or .cursorrules exist but the codebase may not follow them. Compares stated rules vs manifest/scripts.
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: quality
  homepage: https://github.com/G12789/ai-ship
---

# rules-drift — 规则与代码漂移检测

## 检查项

- `AGENTS.md` / `CLAUDE.md` 是否存在且被引用
- package.json scripts 是否与文档一致
- .gitignore 是否遗漏 .ai/

## 步骤

阅读规则文件 → glob 关键目录 → 列出漂移点（不自动改代码）。
