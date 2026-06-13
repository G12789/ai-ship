# 产品对比与上架结论

> 调研日期：2026-06-13  
> 原则：**不如竞品就不上架；上架就要说清楚「和谁比、赢在哪、输在哪」。**

---

## 一、对比矩阵

### 1. 会话上下文（session-start / ctxshot）

| 产品 | Star/体量 | 输出 | Token | 每天能用？ |  verdict |
|---|---|---|---|:---:|---|
| **ctxshot**（我们） | 新发 | 树 + 脚本 + README 摘要 + git diff | 低（~500–3k） | ✅ | **轻量日报场景有位置** |
| [Repomix](https://github.com/yamadashy/repomix) | 大号 | **全文件内容** XML/MD | 很高 | ⚠️ 太重 | **全库分析更强，我们不做对手** |
| [fff.nvim](https://github.com/Ffftdtd5dtff/fff.nvim) | 3.7k | MCP 搜文件 | 按需 | ✅ | **搜文件更强，场景不同** |
| 手动贴 README | — | 不完整 | 中 | ❌ | 费时 |

**ctxshot 结论：✅ 建议上架**

- **赢在哪：** 3 秒、极低 token、专为「每个新会话」设计  
- **输在哪：** 不做全库内容、不做 MCP 搜索  
- **定位：** Repomix 是「体检全扫」，ctxshot 是「每日简报」——**互补，不是更好**

---

### 2. Prompt 回归（prompt-guard / evaldrift）

| 产品 | 国产模型 | 中文 | 快照回归 | verdict |
|---|---|---|---|---|
| **evaldrift**（我们） | ✅ 一等公民 | ✅ | ✅ | **已在 npm，有差异化** |
| [promptfoo](https://github.com/promptfoo/promptfoo) | 需配置 | 弱 | ✅ | 功能更强，配置更重 |
| [deepeval](https://github.com/confident-ai/deepeval) | 支持 | 英文 | ✅ | Python 生态 |

**evaldrift 结论：✅ 已上架，继续维护**

- ai-ship 只是**编排入口**，evaldrift 本身能独立打

---

### 3. Skills 工作流包（@glinks/ai-ship 整体）

| 产品 | 是什么 | 脚本可跑？ | 工作流闭环？ | verdict |
|---|---|:---:|:---:|---|
| **@glinks/ai-ship** | 4 skill + init + CLI | ✅ | ✅ ctx→eval→mcp→check | **见下文** |
| [npx skills](https://github.com/vercel-labs/skills) 22k | 安装器/注册表 | — | — | **我们不做竞品，应兼容** |
| [openskills](https://github.com/numman-ali/openskills) 10k | 通用加载器 | — | — | 不同层 |
| antigravity-awesome-skills | 1200+ markdown skills | 部分 | ❌ 散装 | **广度赢我们，质量参差** |
| [Repomix Explorer skill](https://repomix.com/guide/repomix-explorer-skill) | 单 skill | ✅ | 仅上下文 | 单点强 |
| [cc-agent-harness](https://github.com/KwokJay/cc-agent-harness) | harness 生成 | 部分 | 偏配置 | 2 star，未验证 |

**@glinks/ai-ship 诚实评分：**

| 维度 | 分数 | 说明 |
|---|---:|---|
| 比 npx skills 好用？ | ❌ | 不能替代安装器 |
| 比 Repomix 全库分析好用？ | ❌ | 故意不做这事 |
| 比散装 markdown skills 好用？ | ✅ | **带 pin 版本的可执行 scripts** |
| 比你自己分别 npx 三个 CLI？ | ⚠️ 略好 | **init 一键 + skills 装进 Agent + 叙事统一** |
| 值不值得上架？ | **✅ 有条件上架** | 作为**工作流包**，不是平台级产品 |

---

## 二、最终上架决策

| 包 | 上架？ | 理由 |
|---|---|---|
| **ctxshot** | ✅ **上** | 轻量日报有真实差异化，和 Repomix 不撞车 |
| **evaldrift** | ✅ **已上** | 国产 prompt 回归有位置 |
| **@glinks/ai-ship** | ✅ **上** | 不声称比 Vercel/Repomix 更好；声称**四条工作流开箱即用** |
| 名字 `ai-ship` | ❌ **不上** | npm 被 ulivz 占用 → 用 `@glinks/ai-ship` |

### 什么情况下应该下架/不宣传？

- 若用户反馈 **init 后 ctxshot 经常 404** → 阻塞，必须先修 ctxshot 发布
- 若对比后发现 **init 不比手动装三个 CLI 省时间** → 砍掉 init 只留 skills
- **不要宣传**「比 npx skills 更好」或「比 Repomix 更强」——会被打脸

---

## 三、推荐使用方式（说人话）

```
每天：     npx ctxshot --compact -o .ai/context.md
改 prompt： npx evaldrift run
接 API：   npm create mcp-quickstart@latest ...
提交前：   npx @glinks/ai-ship check

嫌麻烦：   npx @glinks/ai-ship init   # 一次配好
```

---

## 四、我们没做、也不该做的

- Skills 注册表 / 榜单
- 100+ 通用 skills
- 全仓库打包
- 桌面管理器
- 声称替代 Claude Code 内置 skills

---

## 五、一句话对外叙事

> **Repomix 帮你把整库喂给 AI；ctxshot 帮你每天 3 秒开好会话；@glinks/ai-ship 把「会话 → 防退化 → 接 API → 提交检查」收成一条可拆装流水线。**

这话经得起对比，可以上架。
