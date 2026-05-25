#!/usr/bin/env node
/**
 * Upload a video to GitHub's attachment CDN (user-attachments URL).
 * Same flow as drag-and-drop in the README editor.
 */
import { readFileSync } from "node:fs";
import { basename } from "node:path";

const owner = "est4ever";
const repo = "AcouLM";
const filePath = process.argv[2] ?? "docs/media/demo-readme.mp4";
const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;

if (!token) {
  console.error("Set GH_TOKEN or GITHUB_TOKEN (e.g. gh auth token)");
  process.exit(1);
}

const authHeaders = {
  Authorization: `Bearer ${token}`,
  Accept: "application/vnd.github+json",
};

async function main() {
  let repoId = process.env.GITHUB_REPOSITORY_ID;
  if (!repoId) {
    const repoRes = await fetch(`https://api.github.com/repos/${owner}/${repo}`, {
      headers: authHeaders,
    });
    if (!repoRes.ok) {
      throw new Error(`repo lookup failed: ${repoRes.status} ${await repoRes.text()}`);
    }
    const repoData = await repoRes.json();
    repoId = String(repoData.id);
  }

  const referer = `https://github.com/${owner}/${repo}/issues/1`;
  const policyRes = await fetch(
    `https://github.com/${owner}/${repo}/upload/policies/assets`,
    {
      method: "POST",
      headers: {
        Authorization: `token ${token}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-Requested-With": "XMLHttpRequest",
        Origin: "https://github.com",
        Referer: referer,
      },
      body: JSON.stringify({ repository_id: repoId }),
    },
  );
  if (!policyRes.ok) {
    throw new Error(
      `upload policy failed: ${policyRes.status} ${await policyRes.text()}`,
    );
  }
  const policy = await policyRes.json();

  const fileBuffer = readFileSync(filePath);
  const form = new FormData();
  for (const [key, value] of Object.entries(policy.form)) {
    form.append(key, value);
  }
  form.append("file", new Blob([fileBuffer]), basename(filePath));

  const s3Res = await fetch(policy.upload_url, { method: "POST", body: form });
  if (!s3Res.ok) {
    throw new Error(`S3 upload failed: ${s3Res.status} ${await s3Res.text()}`);
  }

  const confirmRes = await fetch(
    `https://github.com/${owner}/${repo}/upload/policies/assets/${policy.token}/confirm`,
    {
      method: "PUT",
      headers: {
        Authorization: `token ${token}`,
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-Requested-With": "XMLHttpRequest",
        Origin: "https://github.com",
        Referer: referer,
      },
      body: JSON.stringify({ name: basename(filePath) }),
    },
  );
  if (!confirmRes.ok) {
    throw new Error(
      `confirm failed: ${confirmRes.status} ${await confirmRes.text()}`,
    );
  }
  const result = await confirmRes.json();
  console.log(result.url);
}

main().catch((err) => {
  console.error(err.cause?.message || err.message || err);
  process.exit(1);
});
