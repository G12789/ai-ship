import { spawnSync } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const range = process.argv[2] || "HEAD~1...HEAD";
const stat = spawnSync("git", ["diff", "--stat", range], { cwd: root, encoding: "utf8" });
const names = spawnSync("git", ["diff", "--name-only", range], { cwd: root, encoding: "utf8" });
mkdirSync(join(root, ".ai"), { recursive: true });
const out = join(root, ".ai", "pr-brief.md");
const md = `# PR diff brief (${range})\n\n## Files\n${names.stdout}\n## Stat\n\`\`\`\n${stat.stdout}\`\`\``;
writeFileSync(out, md, "utf8");
console.log("Wrote", out);
