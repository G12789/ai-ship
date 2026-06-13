#!/usr/bin/env node
/**
 * Move thin / niche skills to skills/_archive/ (convergence per AGENT_EVOLUTION_PLAN_v2).
 * Run from ai-ship root: node scripts/archive-thin-skills.mjs
 */
import { existsSync, mkdirSync, readdirSync, renameSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
const skillsRoot = join(root, "skills");
const archiveRoot = join(skillsRoot, "_archive");

const KEEP = new Set([
  "session-start",
  "vision-auto",
  "prompt-guard",
  "api-bridge",
  "ship-check",
  "_archive",
]);

mkdirSync(archiveRoot, { recursive: true });

let moved = 0;
for (const name of readdirSync(skillsRoot)) {
  if (KEEP.has(name)) continue;
  const src = join(skillsRoot, name);
  const dest = join(archiveRoot, name);
  if (!existsSync(join(src, "SKILL.md"))) continue;
  if (existsSync(dest)) {
    console.log(`skip (exists): ${name}`);
    continue;
  }
  renameSync(src, dest);
  console.log(`archived: ${name}`);
  moved++;
}

console.log(`\nDone. Archived ${moved} skills → skills/_archive/`);
