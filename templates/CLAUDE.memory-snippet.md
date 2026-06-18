# {{PROJECT_NAME}}

每次新开对话**按优先级**自动加载（`@import`，重启不丢）：

@.ai/focus.md

@.ai/handoff.md

@.ai/context.md

**focus = 正在做什么（最准）** · handoff = 上次快照 · context = 仓库结构+git

---

## 记忆规则

- **禁止**让用户手调 `session_brief`
- 用户说「继续上次」→ 先读 `focus.md`，再 `handoff.md`
- 关聊前说「更新 focus」→ 把当前任务写入 `.ai/focus.md`（SessionEnd 会同步到 handoff）
- context 每 4 小时 SessionStart 自动刷新；感觉不准时说「刷新 context」

## 自动干活

改代码、只读命令直接做；删库、force push 才确认。
