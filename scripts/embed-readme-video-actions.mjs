#!/usr/bin/env node
/**
 * On GitHub Actions: upload demo-readme.mp4 via upload/policies API, patch README.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { basename } from "node:path";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const owner = process.env.GITHUB_REPOSITORY_OWNER;
const repo = process.env.GITHUB_REPOSITORY?.split("/")[1] ?? "AcouLM";
const token = process.env.GITHUB_TOKEN;
const filePath = path.join(repoRoot, "docs/media/demo-readme.mp4");

if (!token || !owner) {
  console.error("GITHUB_TOKEN and GITHUB_REPOSITORY_OWNER required");
  process.exit(1);
}

async function main() {
  const repoRes = await fetch(`https://api.github.com/repos/${owner}/${repo}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });
  if (!repoRes.ok) throw new Error(`repo: ${repoRes.status} ${await repoRes.text()}`);
  const { id: repoId } = await repoRes.json();
  const referer = `https://github.com/${owner}/${repo}/issues/24`;

  const policyRes = await fetch(
    `https://github.com/${owner}/${repo}/upload/policies/assets`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-Requested-With": "XMLHttpRequest",
        Origin: "https://github.com",
        Referer: referer,
      },
      body: JSON.stringify({ repository_id: String(repoId) }),
    },
  );
  const policyText = await policyRes.text();
  if (!policyRes.ok) {
    throw new Error(`upload policy ${policyRes.status}: ${policyText.slice(0, 300)}`);
  }
  const policy = JSON.parse(policyText);

  const fileBuffer = readFileSync(filePath);
  const form = new FormData();
  for (const [key, value] of Object.entries(policy.form)) {
    form.append(key, value);
  }
  form.append("file", new Blob([fileBuffer], { type: "video/mp4" }), basename(filePath));

  const s3Res = await fetch(policy.upload_url, { method: "POST", body: form });
  if (!s3Res.ok) throw new Error(`S3: ${s3Res.status} ${await s3Res.text()}`);

  const confirmRes = await fetch(
    `https://github.com/${owner}/${repo}/upload/policies/assets/${policy.token}/confirm`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-Requested-With": "XMLHttpRequest",
        Origin: "https://github.com",
        Referer: referer,
      },
      body: JSON.stringify({ name: basename(filePath) }),
    },
  );
  const confirmText = await confirmRes.text();
  if (!confirmRes.ok) {
    throw new Error(`confirm ${confirmRes.status}: ${confirmText.slice(0, 300)}`);
  }
  const { url: assetUrl } = JSON.parse(confirmText);
  console.log("Asset URL:", assetUrl);

  const readmePath = path.join(repoRoot, "README.md");
  let readme = readFileSync(readmePath, "utf8");
  const demoBlock = `**Video** — end-to-end on Windows: setup, \`acoulm\` starting the stack, the control panel at \`127.0.0.1\`, and a local chat reply (no cloud). Plays inline below (with controls).

${assetUrl}
`;
  readme = readme.replace(/\*\*Video\*\*[\s\S]*?(?=\n\| Doc \|)/, demoBlock);
  writeFileSync(readmePath, readme);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
