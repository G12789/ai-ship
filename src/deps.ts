/** Pinned tool versions — bump on release. */
export const TOOL_VERSIONS = {
  ctxshot: "0.2.0",
  evaldrift: "0.1.0",
  mcpQuickstart: "0.6.0",
} as const;

export function npxArgs(
  pkg: keyof typeof TOOL_VERSIONS | "ctxshot" | "evaldrift",
  extra: string[],
): string[] {
  const version =
    pkg === "ctxshot"
      ? TOOL_VERSIONS.ctxshot
      : pkg === "evaldrift"
        ? TOOL_VERSIONS.evaldrift
        : TOOL_VERSIONS.mcpQuickstart;
  const name = pkg === "mcpQuickstart" ? "create-mcp-quickstart" : pkg;
  return ["--yes", `${name}@${version}`, ...extra];
}

/** Override for local e2e: absolute path to cli.js */
export function ctxshotArgs(extra: string[]): string[] {
  const local = process.env.AI_SHIP_CTXSHOT_BIN;
  if (local) return [local, ...extra];
  return npxArgs("ctxshot", extra);
}

export function evaldriftArgs(extra: string[]): string[] {
  const local = process.env.AI_SHIP_EVALDRIFT_BIN;
  if (local) return [local, ...extra];
  return npxArgs("evaldrift", extra);
}
