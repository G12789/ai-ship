---
name: ci-log-triage
description: >
  Use when GitHub Actions or CI failed. Parses log excerpts, suggests fix order, pairs with ctxshot project context.
compatibility: Node.js 18+ where scripts are used. MCP skills need npx.
metadata:
  author: glinks
  version: "0.2.0"
  category: devops
  homepage: https://github.com/G12789/ai-ship
---

# ci-log-triage — CI 失败日志分拣

## 何时使用

- CI 红了，日志几百行
- 不确定先修 lockfile 还是先修 types

## 步骤

1. 复制失败 job 日志到 `ci-failure.log`
2. `node scripts/triage.mjs ci-failure.log`
3. 输出：错误分类 + 建议修复顺序
4. 结合 `@.ai/context.md` 让 Agent 改代码

## 识别模式

- TypeScript / ESLint / test snapshot / npm ci / lockfile
