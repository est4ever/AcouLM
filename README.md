# Loomis

Loomis is a local AI control plane for Windows:
- browser app shell (`app_shell/`)
- terminal client (`npu_cli.ps1`)
- pluggable backends (`registry/backends_registry.json`)

You can run Loomis with the built-in OpenVINO backend (`npu_wrapper`) or an external backend that supports the same API.

## New Computer Setup

### Default install (recommended)

1. Install [Git for Windows](https://git-scm.com/download/win)
2. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/est4ever/Loomis/main/install.ps1' -UseBasicParsing)))"
```

3. Then:

```powershell
cd $env:USERPROFILE\Loomis
.\portable_setup.ps1
```

### Shell-only install (external backend users)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/est4ever/Loomis/main/install.ps1' -UseBasicParsing))) -ShellOnly"
```

Then configure `registry\backends_registry.json` (`type: "external"`, valid `entrypoint`) and run `.\start_app.ps1`.

### If scripts are blocked

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## Daily Use

Start stack:

```powershell
.\start_app.ps1
```

- App shell: `http://localhost:5173`
- API base (default): `http://localhost:8000/v1`

Chat from terminal:

```powershell
.\npu_cli.ps1
```

One-shot chat:

```powershell
.\npu_cli.ps1 -Command chat -Arguments "hello"
```

Useful runtime controls:

```powershell
.\npu_cli.ps1 -Command status
.\npu_cli.ps1 -Command switch -Arguments "GPU"
.\npu_cli.ps1 -Command policy -Arguments "PERFORMANCE"
.\npu_cli.ps1 -Command load -Arguments "NPU"
.\npu_cli.ps1 -Command metrics -Arguments "last"
```

## Release Asset (for installer)

`install.ps1` expects this exact GitHub Release asset name:
- `loomis-dist-windows-x64.zip`

The zip must contain the contents of `dist\` at zip root.

Create/update from repo root:

```powershell
Compress-Archive -Path (Join-Path $PWD 'dist\*') -DestinationPath loomis-dist-windows-x64.zip -Force
```

## Persistence and Registries

Local runtime state is stored in:
- `registry/models_registry.json`
- `registry/backends_registry.json`

On fresh clone, either run `.\portable_setup.ps1` or copy:
- `registry/models_registry.example.json` -> `registry/models_registry.json`
- `registry/backends_registry.example.json` -> `registry/backends_registry.json`

These machine-specific `registry/*.json` files are intentionally not tracked in git.

## Built-in vs External Backend

- `builtin`: usually `dist/npu_wrapper.exe`; `run.ps1` prepares OpenVINO env.
- `external`: your own executable/script; must provide Loomis API endpoints used by app shell and CLI.

## Model Notes

- This repository does not ship model weights.
- Built-in backend requires OpenVINO IR model folders (contain `.xml` + weights).
- GGUF entries may be tracked in registry, but are not directly runnable by `npu_wrapper` until converted/exported to IR.

## Troubleshooting

- **Model/backend seems to disappear after restart**
  - Launch via `.\start_app.ps1` / `.\run.ps1` so registry paths stay consistent.

- **CLI cannot connect**
  - Wait a few seconds (backend may be restarting), then retry.
  - Start stack again with `.\start_app.ps1`.
  - Check backend terminal output for bad entrypoint/path/runtime failures.

- **Built-in backend fails to start**
  - Confirm `dist/npu_wrapper.exe` exists.
  - Confirm OpenVINO runtime is available (bundled DLLs or valid `OPENVINO_GENAI_DIR`).
  - Rebuild with `.\build.ps1` if needed.

- **Model load failure**
  - Confirm selected model path exists and contains OpenVINO IR `.xml`.
  - Re-import/select model in app shell or update `registry/models_registry.json`.

## Developer Docs

- `ARCHITECTURE.md`
- `API_CONTRACT_V1.md`
- `CLI_USAGE.md`
- `PUBLISH_GUIDE.md`

## Repo vs Release Contents

- **Repository:** source, scripts, docs, `app_shell`, `registry/*.example.json`
- **Releases:** optional runtime bundle zip (`loomis-dist-windows-x64.zip`)
- **Do not commit:** machine-specific `registry/*.json`, model files, build outputs

## License

MIT. See `LICENSE`.
