# ship-skills（ai-ship）

[![npm](https://img.shields.io/npm/v/ship-skills?color=cb3837&logo=npm)](https://www.npmjs.com/package/ship-skills)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-7c3aed)](https://agentskills.io)

> npm 包名 **`ship-skills`**，CLI 命令 **`ai-ship`**。  
> 可拆装的 Agent Skills 工作流包 — 每个模块是 `SKILL.md` + 真实 CLI。

```bash
npx ship-skills init
npx ai-ship ctx -o .ai/context.md
npx ai-ship check
```

> 注：`ai-ship` 在 npm 已被占用；`@glinks/ai-ship` scoped 发布异常，故用 `ship-skills`。

---

## 四个模块

| Skill | CLI | 频率 |
|---|---|---|
| session-start | ctxshot | 每天 |
| prompt-guard | evaldrift | 改 prompt |
| api-bridge | mcp-quickstart | 接 API |
| ship-check | ctxshot + evaldrift | 提交前 |

---

## 和竞品怎么选？

| 需求 | 用谁 |
|---|---|
| 发现海量 skills | `npx skills`（Vercel） |
| 全库打包 | Repomix |
| **日常四步工作流** | **ship-skills（本包）** |
| 只要简报 / 只要测 prompt | 单独 `ctxshot` / `evaldrift` |

完整对比：[PRODUCT_COMPARISON.md](./PRODUCT_COMPARISON.md)

---

## 上架结论（诚实）

- ✅ **ctxshot** — 上架（轻量日报，和 Repomix 互补）
- ✅ **evaldrift** — 已上架（国产 prompt 回归）
- ✅ **ship-skills** — 上架（工作流包，不声称比 Vercel/Repomix 更强）

---

## License

MIT
