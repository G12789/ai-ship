# Contributing to @glinks/ai-ship

## 本地开发

```bash
git clone https://github.com/G12789/ai-ship
cd ai-ship && npm install
npm run build
npm run test:smoke
```

有本地 ctxshot / evaldrift 时跑全链路：

```bash
npm run test:e2e
```

## 改 skill 后

1. 更新 `skills/<name>/SKILL.md` 与 `scripts/*.mjs`
2. `npm run test:smoke`
3. 在临时目录手动 `node dist/cli.js install -f` 验证

## 发版

1. 先确保 `ctxshot@x` / `evaldrift@x` 已在 npm
2. 更新 `src/deps.ts` 中的版本 pin
3. bump `package.json` version
4. `npm publish --access public`

## Issue 回复

目标 24h 内回复。
