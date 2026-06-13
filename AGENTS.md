# AGENTS.md — ai-ship

## 结构

```
src/
  cli.ts        # 入口
  install.ts    # skills 安装到 Agent 目录
  commands.ts   # ctx / eval / mcp / check
  paths.ts      # 各 Agent 的 skills 路径
skills/         # 4 个标准 Agent Skills（含 scripts/）
templates/      # AGENTS.md.tpl
```

## 验证改动

```bash
npm run build
npm run test:smoke
node dist/cli.js doctor
```

## 约定

- Skills 遵循 agentskills.io 规范（SKILL.md + YAML frontmatter）
- scripts/ 用 `.mjs`，Windows 可跑
- CLI 薄封装：实际逻辑在 ctxshot / evaldrift / mcp-quickstart（npx 调用）
- 不重复实现底层工具
