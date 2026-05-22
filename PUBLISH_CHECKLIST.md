# Publish checklist (maintainer)

Use this before announcing AcouLM publicly. End users should follow [GETTING_STARTED.md](GETTING_STARTED.md).

**Positioning:** announce **Windows** as supported. Mention **Linux** and **CUDA** only as experimental / in development unless you have re-tested them on a clean machine.

## GitHub / CI

- [ ] Repository variable **`OPENVINO_GENAI_ARCHIVE_URL`** set (Windows CI build + release workflow)
- [ ] Optional: **`ACOULM_SMOKE_MODEL`** for CI smoke tests
- [ ] `main` branch green on [Actions](https://github.com/est4ever/AcouLM/actions)
- [ ] Create a **GitHub Release** with asset **`acoulm-dist-windows-x64.zip`** (see [README — Release Asset](README.md#release-asset-for-installer))
  - Without this, default `install.ps1` (no `-ShellOnly`) **fails** for Windows users
- [ ] Tag release `v*` (e.g. `v1.0.1`) to trigger `.github/workflows/release.yml`

## Documentation

- [ ] [GETTING_STARTED.md](GETTING_STARTED.md) paths match what you ship
- [ ] README install examples use an **existing** release tag or `latest`
- [ ] [SECURITY.md](SECURITY.md) linked from README
- [ ] HPC doc: `scripts/hpc/README.txt` matches bind defaults (`127.0.0.1`)

## Secrets / repo hygiene

- [ ] No `registry/*.json` committed (only `*.example.json`)
- [ ] No `scripts/hpc/local_env.sh` committed
- [ ] `.gitignore` covers `.env`, `.acoulm/`, models, tokens
- [ ] Cursor attribution off in `~/.cursor/cli-config.json` for future commits

## Smoke test (your machine)

**Windows**

```powershell
.\preflight_check.ps1
acoulm setup
acoulm
# Browser: http://127.0.0.1:5173 — health OK, chat works
```

**Linux / cluster (if you support it)**

```bash
source scripts/hpc/local_env.sh
acoulm
curl -s http://127.0.0.1:8000/v1/health
```

## Optional before announce

- [ ] Marketing site deployed: https://est4ever.github.io/AcouLM/
- [ ] GitHub Support ticket for stale `cursoragent` contributor UI (cosmetic; API is clean)

## After publish

- Monitor Issues for “install.ps1 download failed” → usually missing Release zip
- Point users to **GETTING_STARTED.md** first
