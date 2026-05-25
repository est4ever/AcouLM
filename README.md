# AcouLM

🌐 **Website:** https://est4ever.github.io/AcouLM/

## What is AcouLM?

AcouLM runs **your own** language model on **your PC** — like a local ChatGPT stack you control. It is not a cloud service: you install it, point it at a model file you already have (or download separately), then chat in a browser or terminal. Nothing goes to AcouLM’s servers.

**How it works (short):** install once → `acoulm setup` registers your model path and tools → `acoulm` starts a small local server plus a web UI → you type in the UI (or CLI); the server loads the model and returns replies on `127.0.0.1` only.

Three parts:

| Part | What it does |
|------|----------------|
| **Backend API** (`http://127.0.0.1:8000/v1`) | Loads the model and runs generation. Uses the built-in OpenVINO engine, or forwards to Ollama / llama.cpp if you configured that. |
| **Control panel** (`http://127.0.0.1:5173`) | Web chat and settings: pick model, CPU/GPU/NPU, which backend is active, registry paths. |
| **Terminal chat** | Same API from PowerShell when you do not want the browser open. |

**Models:** this repo does **not** include weights. You supply OpenVINO IR or a supported GGUF file (see [GETTING_STARTED.md](GETTING_STARTED.md)).

**New here?** Install, drivers, first model: [GETTING_STARTED.md](GETTING_STARTED.md).

## Demo

**Screenshot** — the control panel after `acoulm` is ready: Workspace chat on the left, runtime chips (device, model, backend, routing flags), and the Control tab for registry and system settings.

<p align="center">
  <img src="docs/media/screenshot.jpg" alt="AcouLM control panel: local chat, runtime status, and model/device controls" width="720">
</p>

**Video** (~2 min, with audio) — end-to-end on Windows: setup, `acoulm` starting the stack, the control panel at `127.0.0.1`, and a local chat reply (no cloud).

https://github.com/user-attachments/assets/b8b1e929-edd7-49ae-8435-2d62cc517f63

| Doc | Purpose |
|-----|---------|
| [GETTING_STARTED.md](GETTING_STARTED.md) | Full setup (Windows, Linux, external backends) |
| [SECURITY.md](SECURITY.md) | Localhost bind, API token, SSH tunnels |
| [PUBLISH_CHECKLIST.md](PUBLISH_CHECKLIST.md) | Before sharing the repo publicly |

## Platform support

| Platform | Status |
|----------|--------|
| **Windows 10/11 x64** | **Supported** — primary path (`acoulm`, release zip `acoulm-dist-windows-x64.zip`) |
| **Linux (OpenVINO / SLURM)** | **Under development** — experimental scripts; expect rough edges |
| **Linux + NVIDIA CUDA (GGUF)** | **Under development** — not a polished end-user path yet |

For day-to-day use today, use **Windows**. Linux and CUDA flows are for contributors and custom deployments; the shell and API are the same, only the backend entrypoint changes.

## Windows quick start

**Requirements:** Windows 10/11 x64, **16 GB+ RAM** recommended, and a model you provide (OpenVINO IR or GGUF — not bundled). Needs [Git for Windows](https://git-scm.com/download/win) and **`acoulm-dist-windows-x64.zip`** ([Releases](https://github.com/est4ever/AcouLM/releases)), or build from source.

**What each step does:** `install.ps1` clones the repo; `portable_setup.ps1` unpacks the release zip; `acoulm setup` wires PATH and asks for your model; `acoulm` starts API + UI.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/est4ever/AcouLM/main/install.ps1' -UseBasicParsing)))"
cd $env:USERPROFILE\AcouLM
.\portable_setup.ps1
acoulm setup
acoulm
```

- Control panel: http://127.0.0.1:5173  
- API: http://127.0.0.1:8000/v1  

First `acoulm setup` / `acoulm` may take a while (drivers, model path). If the UI does not load, see [GETTING_STARTED.md](GETTING_STARTED.md).

Shell-only (Ollama, llama.cpp, custom backend): `install.ps1 -ShellOnly` — details in [GETTING_STARTED.md — external backend](GETTING_STARTED.md#windows--external-backend).

## Daily commands

| Command | What it does |
|---------|----------------|
| `acoulm setup` | One-time: fix PATH, home folder, model/registry paths. |
| `acoulm` | Start API + control panel; open http://127.0.0.1:5173 to chat. |
| `acoulm cpu` | Force CPU inference (slower, works on 16 GB RAM or weak graphics). |
| `acoulm stop` | Stop API and UI processes. |
| `acoulm help` | List subcommands. |

## Backends at a glance

| Backend | What it means |
|---------|----------------|
| **Built-in** | AcouLM’s own OpenVINO runner in the zip — uses CPU, GPU, or Intel NPU on your machine. |
| **External** | You run Ollama, llama.cpp, etc.; AcouLM only sends chat to that server (good for NVIDIA CUDA or custom setups). |

## More documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — components and routing
- [API_CONTRACT_V1.md](API_CONTRACT_V1.md) — HTTP API
- [CLI_USAGE.md](CLI_USAGE.md) — CLI reference
- [PUBLISH_GUIDE.md](PUBLISH_GUIDE.md) — releases and distribution

## License

MIT — see [LICENSE](LICENSE).
