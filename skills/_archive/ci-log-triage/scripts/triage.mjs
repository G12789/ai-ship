import { readFileSync } from "node:fs";

const file = process.argv[2] || "ci-failure.log";
const log = readFileSync(file, "utf8");
const rules = [
  [/TS\d{4}|error TS/, "TypeScript 编译错误 — 先 npm run build 本地复现"],
  [/eslint|ESLint/, "Lint — 跑 npm run lint -- --fix"],
  [/npm ERR!|lockfile|package-lock/, "依赖/lockfile — rm -rf node_modules && npm ci"],
  [/snapshot|Snapshot/, "测试快照 — 审查是否预期变更"],
  [/Cannot find module/, "模块解析 — 检查 exports/types 路径"],
  [/Process completed with exit code/, "通用失败 — 往上找第一个 error"],
];
console.log("# CI triage\n");
let hit = false;
for (const [re, hint] of rules) {
  if (re.test(log)) {
    console.log(`- **${hint}**`);
    hit = true;
  }
}
if (!hit) console.log("- 未匹配常见模式，建议把第一段 error stack 贴给 Agent");
