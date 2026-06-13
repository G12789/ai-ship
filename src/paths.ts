export type AgentId =
  | "universal"
  | "claude"
  | "cursor"
  | "codex"
  | "copilot"
  | "gemini";

export interface AgentTarget {
  id: AgentId;
  label: string;
  dirs: (opts: { global: boolean }) => string[];
}

/** Relative paths from project root (or ~ for global). */
export const AGENTS: AgentTarget[] = [
  {
    id: "universal",
    label: "通用 (.agents/skills)",
    dirs: ({ global }) => [global ? "~/.agents/skills" : ".agents/skills"],
  },
  {
    id: "claude",
    label: "Claude Code",
    dirs: ({ global }) => [global ? "~/.claude/skills" : ".claude/skills"],
  },
  {
    id: "cursor",
    label: "Cursor",
    dirs: ({ global }) => [
      global ? "~/.cursor/skills" : ".cursor/skills",
      global ? "~/.agents/skills" : ".agents/skills",
    ],
  },
  {
    id: "codex",
    label: "OpenAI Codex",
    dirs: ({ global }) => [global ? "~/.codex/skills" : ".agents/skills"],
  },
  {
    id: "copilot",
    label: "GitHub Copilot",
    dirs: ({ global }) => [global ? "~/.github/skills" : ".github/skills"],
  },
  {
    id: "gemini",
    label: "Gemini CLI",
    dirs: ({ global }) => [
      global ? "~/.gemini/skills" : ".gemini/skills",
      global ? "~/.agents/skills" : ".agents/skills",
    ],
  },
];

export const DEFAULT_AGENTS: AgentId[] = ["universal", "claude", "cursor"];

export function resolveAgent(id: string): AgentId | null {
  const found = AGENTS.find((a) => a.id === id);
  return found ? found.id : null;
}

export function expandHome(path: string, home: string): string {
  if (path.startsWith("~/")) {
    return home + path.slice(1);
  }
  return path;
}
