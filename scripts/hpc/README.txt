AcouLM on a remote supercomputer (Linux + SLURM) — EXPERIMENTAL
=============================================================
CUDA (cuda-llama + GGUF) is IN DEVELOPMENT — not fully supported for all users.

1) git clone https://github.com/est4ever/AcouLM.git && cd AcouLM

2) ./portable_setup.sh
   (same idea as portable_setup.ps1 on Windows — choose OpenVINO path, model path, backend)

3) cp scripts/hpc/local_env.example.sh scripts/hpc/local_env.sh
   Edit OPENVINO_GENAI_DIR and ACOULM_MODEL (model on scratch).

4) source scripts/hpc/setup_env.sh && ./build.sh
   (needs cmake >= 3.18; OpenVINO 2026.1 needs glibc >= 2.34 / GCC 11+)
   Old login nodes (Ubuntu 20.04): conda install -c conda-forge gcc_linux-64=12 gxx_linux-64=12 sysroot_linux-64
   then ./build.sh (uses scripts/hpc/ensure_toolchain.sh automatically)

5) sbatch scripts/hpc/slurm_acoulm.sbatch

6) Laptop tunnel:  ssh -L 8000:<compute-node>:8000 user@cluster
   acoulm chat "Hello"    (after: acoulm setup  — same name as Windows)

One-time:  ./acoulm.sh setup   → adds ~/.local/bin/acoulm to PATH

Notes
-----
- If setupvars.sh errors on "python_version: unbound variable", pull latest and use
  source scripts/hpc/setup_env.sh (or re-run linux_setup.sh). Or verify OpenVINO install:
  bash scripts/hpc/install_openvino_genai.sh
- Ubuntu 20.04 / glibc 2.31: Intel does NOT publish ubuntu20 GenAI 2026.1 archives (URL returns HTML).
  Install ubuntu22 via install_openvino_genai.sh, then run inside Ubuntu 22:
    bash scripts/hpc/run_in_ubuntu22.sh
  Or upgrade OS / use a 22.04+ node. Host-native acoulm start needs glibc >= 2.34.
- Never put conda sysroot libc on LD_LIBRARY_PATH (breaks bash/git).
- Broken shell after bad LD_LIBRARY_PATH:  unset LD_LIBRARY_PATH;  env -i HOME=$HOME PATH=/usr/bin:/bin bash
- Prefer OpenVINO IR folders over GGUF on HPC for faster loads.
- API defaults to 127.0.0.1:8000 (ACOULM_BIND_HOST). Use SSH tunnel; see SECURITY.md.
- NVIDIA CUDA: bash scripts/hpc/configure_cuda_env.sh, source scripts/hpc/local_env.sh, acoulm (GGUF path required).
- Windows scripts (acoulm.ps1, start_app.ps1) are not used on the cluster.
- Keep the backend process alive for instant restarts; use the same node/port via SSH tunnel.
