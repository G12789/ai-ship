import { readFileSync } from "node:fs";

let inputRaw = "";
try {
  inputRaw = readFileSync(0, "utf8");
} catch {
  process.exit(0);
}
if (!inputRaw) process.exit(0);

const lower = inputRaw.toLowerCase();
const hasImage =
  /unsupported image|image\.png|image_url|\.png|\.jpg|\.jpeg|\.webp/.test(
    lower,
  );
if (!hasImage) process.exit(0);

process.stdout.write(`
## Vision auto-hint (UserPromptSubmit)
User sent image(s). DeepSeek cannot see pixels.
REQUIRED now:
1. sync_chat_attachments (multi-paste from IDE)
2. describe_paste_batch if 2+ images else describe_paste
3. Show image preview markdown from tool result to user
`);
