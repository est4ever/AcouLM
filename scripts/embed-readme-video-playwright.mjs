#!/usr/bin/env node
/**
 * Upload demo-readme.mp4 via GitHub's web editor (same as drag-and-drop)
 * and print the generated user-attachments URL.
 */
import { chromium } from "playwright";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const owner = "est4ever";
const repo = "AcouLM";
const branch = "main";
const videoPath = path.join(repoRoot, "docs/media/demo-readme.mp4");
const profileDir = path.join(repoRoot, ".github-upload-profile");

const editUrl = `https://github.com/${owner}/${repo}/edit/${branch}/README.md`;

async function main() {
  const context = await chromium.launchPersistentContext(profileDir, {
    channel: "msedge",
    headless: false,
    viewport: { width: 1400, height: 900 },
  });
  const page = context.pages()[0] ?? (await context.newPage());

  console.log("Opening README editor…");
  await page.goto(editUrl, { waitUntil: "domcontentloaded", timeout: 120000 });

  if (page.url().includes("/login")) {
    console.log("Log in to GitHub in the browser window. Waiting up to 3 minutes…");
    await page.waitForURL((url) => !url.href.includes("/login"), { timeout: 180000 });
    await page.goto(editUrl, { waitUntil: "domcontentloaded", timeout: 120000 });
  }

  await page.waitForSelector('textarea[name="wiki[body]"], #codemirror-textarea, .CodeMirror', {
    timeout: 120000,
  });

  const before = await page
    .locator('textarea[name="wiki[body]"], #codemirror-textarea')
    .first()
    .inputValue()
    .catch(() => "");

  const fileInput = page.locator('input[type="file"]').first();
  await fileInput.setInputFiles(videoPath);

  console.log("Uploaded file; waiting for GitHub to insert CDN URL…");
  await page.waitForFunction(
    (prev) => {
      const el =
        document.querySelector('textarea[name="wiki[body]"]') ||
        document.querySelector("#codemirror-textarea");
      const val = el?.value ?? "";
      return val !== prev && /user-attachments|user-images\.githubusercontent/.test(val);
    },
    before,
    { timeout: 120000 },
  );

  const body = await page
    .locator('textarea[name="wiki[body]"], #codemirror-textarea')
    .first()
    .inputValue();
  const match =
    body.match(/https:\/\/github\.com\/user-attachments\/assets\/[a-f0-9-]+/i) ||
    body.match(/https:\/\/user-images\.githubusercontent\.com\/[^\s)]+/i);
  if (!match) {
    throw new Error("Upload succeeded but no CDN URL found in editor.");
  }
  const assetUrl = match[0];
  console.log(assetUrl);

  const readmePath = path.join(repoRoot, "README.md");
  let readme = readFileSync(readmePath, "utf8");
  const demoBlock = `**Video** — end-to-end on Windows: setup, \`acoulm\` starting the stack, the control panel at \`127.0.0.1\`, and a local chat reply (no cloud). Plays inline below (with controls).

${assetUrl}
`;
  readme = readme.replace(
    /\*\*Video\*\*[\s\S]*?(?=\n\| Doc \|)/,
    demoBlock,
  );
  writeFileSync(readmePath, readme);

  console.log("Updated README.md locally with embed URL.");
  await context.close();
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
