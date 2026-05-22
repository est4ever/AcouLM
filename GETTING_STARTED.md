# Getting started with AcouLM

AcouLM is a **shell** (UI + CLI + API). Inference comes from a **backend** you register — built-in OpenVINO on Windows, or any **external** server that speaks the same HTTP API. Your users may have Intel-only laptops, AMD + NVIDIA desktops, or a CUDA cluster; the shell stays the same.

| Platform | Maturity |
|----------|----------|
| **Windows** | Supported — recommended for new users |
| **Linux (OpenVINO / SLURM)** | Experimental |
| **Linux (NVIDIA CUDA / GGUF)** | In development — not fully supported yet |

Pick **one** path below. All paths assume you bring **your own model weights** (not included in the repo).

| You are… | Start here |
|----------|------------|
| **Windows — bundled reference backend (OpenVINO)** | [Windows — built-in backend](#windows--built-in-backend-openvino) |
| **Windows — shell only (Ollama, llama.cpp, custom — any hardware)** | [Windows — external backend](#windows--external-backend) |
| **Linux desktop or dev (experimental)** | [Linux](#linux-desktop--dev-experimental) |
| **Linux cluster — NVIDIA CUDA (in development)** | [Linux cluster (CUDA)](#linux-cluster--cuda-gguf-in-development) |
| **Just browsing the repo** | Clone → copy `registry/*.example.json` → read [README.md](README.md) |

**Security (all paths):** API defaults to `127.0.0.1` only. See [SECURITY.md](SECURITY.md).

---

## Before you run anything

1. **Clone:** `git clone https://github.com/est4ever/AcouLM.git && cd AcouLM`
2. **Registries:** run the setup wizard **or** copy templates:
   - `registry/models_registry.example.json` → `registry/models_registry.json`
   - `registry/backends_registry.example.json` → `registry/backends_registry.json`
   - Linux cluster: also `registry/backends_registry.linux.example.json` if you use CUDA
3. **Models:** download or point to local **OpenVINO IR**, **GGUF** (Q4_K_M recommended), or your backend’s format
4. **Never commit:** `registry/*.json` (except `*.example.json`), `scripts/hpc/local_env.sh`, `models/`, tokens

---

## Windows — built-in backend (OpenVINO)

**Backend note:** This path ships the **reference** OpenVINO runtime (`npu_wrapper`). It is one backend, not the product boundary — use [external backend](#windows--external-backend) if your users run CUDA-only stacks. OpenVINO discovers **CPU / GPU / NPU** at runtime; vendors vary by machine. `acoulm` picks a sensible default device from host hardware (discrete GPU → GPU; integrated-only + GGUF may default to CPU for faster first compile). Override with `acoulm gpu`, `acoulm cpu`, or `$env:ACOULM_DEVICE`.

### Option 1 — GitHub Release zip (easiest for end users)

**Requires** a published release asset: `acoulm-dist-windows-x64.zip` on [GitHub Releases](https://github.com/est4ever/AcouLM/releases).

```powershell
# Git for Windows required
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/est4ever/AcouLM/main/install.ps1' -UseBasicParsing)))"
cd $env:USERPROFILE\AcouLM
.\portable_setup.ps1
acoulm setup
acoulm
```

### Option 2 — Shell + build from source (no release yet)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/est4ever/AcouLM/main/install.ps1' -UseBasicParsing))) -ShellOnly"
cd $env:USERPROFILE\AcouLM
# Install OpenVINO GenAI (see README / build.ps1), then:
.\build.ps1
.\portable_setup.ps1
acoulm setup
acoulm
```

### Verify

```powershell
.\preflight_check.ps1
Invoke-RestMethod http://127.0.0.1:8000/v1/health
```

Open control panel: http://127.0.0.1:5173

---

## Windows — external backend

Use when you run **llama.cpp**, another server, or a custom executable that speaks the AcouLM API.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/est4ever/AcouLM/main/install.ps1' -UseBasicParsing))) -ShellOnly"
cd $env:USERPROFILE\AcouLM
.\portable_setup.ps1
```

Edit `registry\backends_registry.json`:

- `"type": "external"`
- `"entrypoint"`: path to your backend script or binary

Then:

```powershell
acoulm setup
acoulm
```

---

## Linux desktop / dev (experimental)

> Scripts and packaging are still evolving. Prefer Windows for a stable first experience.

```bash
git clone https://github.com/est4ever/AcouLM.git && cd AcouLM
./portable_setup.sh          # interactive — OpenVINO path, model, backend
source scripts/hpc/setup_env.sh
./build.sh
./acoulm.sh setup
source ~/.bashrc
acoulm                       # API + panel + terminal chat (localhost)
```

Optional env file (recommended on clusters):

```bash
cp scripts/hpc/local_env.example.sh scripts/hpc/local_env.sh
# edit ACOULM_MODEL, devices, etc.
```

---

## Linux cluster — CUDA (GGUF) (in development)

> **CUDA path is not complete.** It works on some setups (llama.cpp + GGUF + `acoulm_cuda_proxy.py`) but requires manual env (`local_env.sh`), correct `.gguf` paths, and cluster-specific tuning. Treat as contributor/HPC preview, not end-user ready.

For **NVIDIA** nodes (e.g. RTX 3090), use the **cuda-llama** backend and a **`.gguf`** file (not an HF folder).

```bash
git clone https://github.com/est4ever/AcouLM.git && cd AcouLM
./portable_setup.sh
bash scripts/hpc/configure_cuda_env.sh   # finds GGUF, writes local_env.sh
source scripts/hpc/local_env.sh
./acoulm.sh setup
acoulm
```

From your laptop (SSH tunnel — do **not** expose 8000 to the LAN):

```bash
ssh -L 8000:127.0.0.1:8000 -L 5173:127.0.0.1:5173 user@cluster
```

Verify on the node:

```bash
curl -s http://127.0.0.1:8000/v1/health
```

Details: [scripts/hpc/README.txt](scripts/hpc/README.txt)

---

## Daily use (all platforms)

| Action | Windows | Linux |
|--------|---------|-------|
| Start everything | `acoulm` | `acoulm` |
| One-time PATH setup | `acoulm setup` | `acoulm setup` |
| Control panel | http://127.0.0.1:5173 | same (via tunnel on cluster) |
| API | http://127.0.0.1:8000/v1 | same |
| Terminal chat | `/status`, `/exit` (leading `/`) | same |

---

## Common failures

| Symptom | Fix |
|---------|-----|
| **`portable_setup.ps1` is not recognized** (PowerShell) | You must use `.\` from the repo folder: `.\portable_setup.ps1` — or run `portable_setup.cmd` (no `.\` needed) |
| `install.ps1` download failed | No GitHub Release yet — use `-ShellOnly` and `.\build.ps1`, or publish `acoulm-dist-windows-x64.zip` |
| Panel shows Model/Backend error | API not up or wrong model path; on Linux use one port: tunnel **5173** (panel proxies API) |
| `[cuda] No .gguf found` | Set `ACOULM_MODEL` to a **`.gguf` file** in `local_env.sh`, not an HF folder |
| GGUF `gguf_tensor_to_f16 failed` | Use **Q4_K_M** / **Q8_0**, not IQ quants |
| Out of RAM on 16 GB PC | `acoulm cpu` or single device; avoid multi-device without `ACOULM_ALLOW_MULTI_DEVICE=1` |
| Scripts blocked (Windows) | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |

---

## More documentation

- [README.md](README.md) — full reference
- [SECURITY.md](SECURITY.md) — bind address, API token, SSH tunnels
- [CLI_USAGE.md](CLI_USAGE.md) — `npu_cli` / API commands
- [API_CONTRACT_V1.md](API_CONTRACT_V1.md) — HTTP API
- [PUBLISH_CHECKLIST.md](PUBLISH_CHECKLIST.md) — **maintainers:** before going public
