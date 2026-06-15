# ai-ship-mcp

**一个 MCP 搞定 AI Ship 全套能力**：会话记忆（ctxshot）+ 贴图识图（vision-bridge）。

对外只装这一个包即可；需要拆分时仍可用独立的 [ctxshot-mcp](https://github.com/G12789/ctxshot-mcp) 与 [vision-bridge-mcp](https://github.com/G12789/vision-bridge-mcp)。

## 安装

```bash
npx ship-skills init
```

`init` 会自动写入 `.mcp.json`（单条 `ai-ship` 服务）。

或手动配置 Claude Code / Cursor：

```json
{
  "mcpServers": {
    "ai-ship": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "ai-ship-mcp@latest"],
      "env": {
        "VISION_BRIDGE_BASE_URL": "https://api.moonshot.cn/v1",
        "VISION_BRIDGE_API_KEY": "${MOONSHOT_API_KEY}",
        "VISION_BRIDGE_MODELS": "kimi-k2.5,kimi-k2.6",
        "VISION_BRIDGE_CACHE": "1"
      }
    }
  }
}
```

## 工具一览（13 个）

| 类别 | 工具 |
|------|------|
| 记忆 / 简报 | `pack_context`, `session_brief`, `context_stats` |
| 贴图识图 | `describe_paste`, `describe_paste_batch`, `sync_chat_attachments`, `describe_image`, `describe_clipboard`, `list_recent_pastes`, `extract_text`, `compare_images`, `vision_status`, `vision_rules` |

## 相关包

| npm | 说明 |
|-----|------|
| `ai-ship-mcp` | **推荐** — 本包，二合一 |
| `ship-skills` | 一键 init（Hook + Skills + 本 MCP 配置） |
| `ctxshot-mcp` | 仅记忆（高级用户拆分用） |
| `vision-bridge-mcp` | 仅看图（高级用户拆分用） |

完整文档：[ai-ship/docs/STACK.md](https://github.com/G12789/ai-ship/blob/master/docs/STACK.md)
