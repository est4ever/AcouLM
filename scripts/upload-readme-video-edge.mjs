#!/usr/bin/env node
/**
 * Upload demo video using GitHub session cookies from Microsoft Edge.
 */
import { readFileSync, copyFileSync, unlinkSync, existsSync } from "node:fs";
import { basename, join } from "node:path";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const __dirname = fileURLToPath(new URL(".", import.meta.url));
const repoRoot = join(__dirname, "..");
const owner = "est4ever";
const repo = "AcouLM";
const filePath = join(repoRoot, "docs/media/demo-readme.mp4");

const edgeCookies = join(
  process.env.LOCALAPPDATA ?? "",
  "Microsoft/Edge/User Data/Default/Network/Cookies",
);

function extractCookieHeader() {
  if (!existsSync(edgeCookies)) {
    throw new Error(`Edge cookies not found at ${edgeCookies}`);
  }
  const tmpDb = join(tmpdir(), `gh-cookies-${Date.now()}.db`);
  copyFileSync(edgeCookies, tmpDb);
  const py = `
import sqlite3, json, sys
conn = sqlite3.connect(sys.argv[1])
rows = conn.execute(
  "SELECT name, value FROM cookies WHERE host_key LIKE '%github.com%'"
).fetchall()
conn.close()
print(json.dumps(rows))
`;
  const r = spawnSync("python", ["-c", py, tmpDb], { encoding: "utf8" });
  try {
    unlinkSync(tmpDb);
  } catch {
    /* ignore */
  }
  if (r.status !== 0) {
    throw new Error(`Cookie read failed: ${r.stderr || r.stdout}`);
  }
  const rows = JSON.parse(r.stdout.trim());
  const map = Object.fromEntries(rows);
  for (const name of ["user_session", "logged_in", "_gh_sess"]) {
    if (!map[name]) {
      throw new Error(
        `Missing GitHub cookie '${name}'. Log in to github.com in Edge first.`,
      );
    }
  }
  const parts = rows.map(([n, v]) => `${n}=${v}`);
  return parts.join("; ");
}

async function main() {
  const cookie = extractCookieHeader();
  const repoRes = await fetch(`https://api.github.com/repos/${owner}/${repo}`, {
    headers: { Cookie: cookie, Accept: "application/vnd.github+json" },
  });
  if (!repoRes.ok) {
    throw new Error(`repo lookup: ${repoRes.status}`);
  }
  const { id: repoId } = await repoRes.json();
  const referer = `https://github.com/${owner}/${repo}/issues/24`;

  const policyRes = await fetch(
    `https://github.com/${owner}/${repo}/upload/policies/assets`,
    {
      method: "POST",
      headers: {
        Cookie: cookie,
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-Requested-With": "XMLHttpRequest",
        Origin: "https://github.com",
        Referer: referer,
      },
      body: JSON.stringify({ repository_id: String(repoId) }),
    },
  );
  if (!policyRes.ok) {
    const t = await policyRes.text();
    throw new Error(`upload policy: ${policyRes.status} ${t.slice(0, 200)}`);
  }
  const policy = await policyRes.json();

  const fileBuffer = readFileSync(filePath);
  const form = new FormData();
  for (const [key, value] of Object.entries(policy.form)) {
    form.append(key, value);
  }
  form.append("file", new Blob([fileBuffer], { type: "video/mp4" }), basename(filePath));

  const s3Res = await fetch(policy.upload_url, { method: "POST", body: form });
  if (!s3Res.ok) {
    throw new Error(`S3 upload: ${s3Res.status}`);
  }

  const confirmRes = await fetch(
    `https://github.com/${owner}/${repo}/upload/policies/assets/${policy.token}/confirm`,
    {
      method: "PUT",
      headers: {
        Cookie: cookie,
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
    throw new Error(`confirm: ${confirmRes.status} ${await confirmRes.text()}`);
  }
  const { url } = await confirmRes.json();
  console.log(url);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
