#!/usr/bin/env node
/**
 * Upload demo-readme.mp4 via GitHub web UI, update README, push.
 * Opens a visible browser; sign in to GitHub if prompted.
 */
import { chromium } from "playwright";
import { readFileSync, writeFileSync } from "node:fs";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const owner = "est4ever";
const repo = "AcouLM";
const issue = 24;
const videoPath = path.join(repoRoot, "docs/media/demo-readme.mp4");
const profileDir = path.join(repoRoot, ".github-upload-profile");

const issueUrl = `https://github.com/${owner}/${repo}/issues/${issue}`;

async function isLoggedIn(page) {
  const login = await page.locator('meta[name="user-login"]').getAttribute("content").catch(() => null);
  if (login) return true;
  return page.locator('[data-login], [aria-label="View profile and more"]').first().isVisible().catch(() => false);
}

async function ensureLogin(page) {
  await page.goto("https://github.com/", { waitUntil: "domcontentloaded", timeout: 120000 });
  if (await isLoggedIn(page)) return;
  console.log("Sign in to GitHub in the browser window (waiting up to 10 minutes)…");
  await page.goto("https://github.com/login", { waitUntil: "domcontentloaded", timeout: 120000 });
  for (let i = 0; i < 120; i++) {
    if (await isLoggedIn(page)) return;
    await page.waitForTimeout(5000);
  }
  throw new Error("GitHub login timed out.");
}

async function extractAssetUrl(page) {
  const html = await page.content();
  const match =
    html.match(/https:\/\/github\.com\/user-attachments\/assets\/[a-f0-9-]+/i) ||
    html.match(/https:\/\/user-images\.githubusercontent\.com\/[^"'\\s<>]+/i);
  return match?.[0] ?? null;
}

async function main() {
  const context = await chromium.launchPersistentContext(profileDir, {
    headless: false,
    viewport: { width: 1400, height: 900 },
  });
  const page = context.pages()[0] ?? (await context.newPage());

  await ensureLogin(page);
  console.log("Logged in. Opening issue…");
  await page.goto(issueUrl, { waitUntil: "domcontentloaded", timeout: 120000 });

  const comment = page.locator("#new_comment_field, textarea.js-comment-field").first();
  await comment.waitFor({ state: "visible", timeout: 60000 });
  await comment.click();

  let fileInput = page.locator('file-attachment input[type="file"], input[type="file"]').first();
  if ((await fileInput.count()) === 0) {
    const attach = page.getByRole("button", { name: /attach files/i }).first();
    if (await attach.isVisible().catch(() => false)) await attach.click();
    fileInput = page.locator('input[type="file"]').first();
  }
  await fileInput.waitFor({ state: "attached", timeout: 30000 });
  await fileInput.setInputFiles(videoPath);
  console.log("Uploaded; waiting for CDN URL…");

  let assetUrl = null;
  for (let i = 0; i < 90; i++) {
    await page.waitForTimeout(2000);
    assetUrl = await extractAssetUrl(page);
    if (assetUrl) break;
  }
  if (!assetUrl) throw new Error("No user-attachments URL appeared after upload.");

  console.log("Asset URL:", assetUrl);
  const readmePath = path.join(repoRoot, "README.md");
  let readme = readFileSync(readmePath, "utf8");
  const demoBlock = `**Video** — end-to-end on Windows: setup, \`acoulm\` starting the stack, the control panel at \`127.0.0.1\`, and a local chat reply (no cloud). Plays inline below (with controls).

${assetUrl}
`;
  readme = readme.replace(/\*\*Video\*\*[\s\S]*?(?=\n\| Doc \|)/, demoBlock);
  writeFileSync(readmePath, readme);

  await context.close();

  execSync("git add README.md", { cwd: repoRoot, stdio: "inherit" });
  execSync('git commit -m "README: inline demo video (GitHub CDN)"', { cwd: repoRoot, stdio: "inherit" });
  execSync("git push", { cwd: repoRoot, stdio: "inherit" });
  console.log("Done — README pushed with inline video.");
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
