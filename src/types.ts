import type { AgentId } from "./paths.js";

export const SKILL_NAMES = [
  "session-start",
  "vision-auto",
  "prompt-guard",
  "api-bridge",
  "ship-check",
] as const;

export type SkillName = (typeof SKILL_NAMES)[number];

export interface SkillMeta {
  name: SkillName;
  title: string;
  cli: string;
  frequency: string;
}

export const SKILL_META: Record<SkillName, SkillMeta> = {
  "session-start": {
    name: "session-start",
    title: "会话起手",
    cli: "ctxshot",
    frequency: "每天 / 每个新 AI 会话",
  },
  "vision-auto": {
    name: "vision-auto",
    title: "自动看图",
    cli: "vision-bridge-mcp",
    frequency: "贴截图 / DeepSeek 文本模型时",
  },
  "prompt-guard": {
    name: "prompt-guard",
    title: "Prompt 防退化",
    cli: "evaldrift",
    frequency: "改 prompt / 模板时",
  },
  "api-bridge": {
    name: "api-bridge",
    title: "API → MCP",
    cli: "mcp-quickstart",
    frequency: "接 REST API 时",
  },
  "ship-check": {
    name: "ship-check",
    title: "发货检查",
    cli: "ctxshot + evaldrift",
    frequency: "提交 / PR 前",
  },
};

export interface InstallOptions {
  cwd: string;
  agents: AgentId[];
  skills: SkillName[];
  global: boolean;
  force: boolean;
  agentsMd: boolean;
}
