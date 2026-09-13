# RTX 4090 Deep Learning Workstation (`4090rtx`)

Setup documentation and scripts for the second deep learning workstation: RTX 4090,
Ubuntu 26.04 LTS, fresh install on 2026-09-12. Sibling repo of
[rtx3090-dl-workstation](https://github.com/rmesterheide/rtx3090-dl-workstation);
the from-scratch guide from there ([`docs/SETUP.md`](docs/SETUP.md), copied here)
was run on a truly fresh machine for the first time on this box.

**What actually runs on the box, including every deviation from the guide and the
remote desktop setup (Sunshine/Moonlight on Wayland):**
[`docs/CURRENT-STATE.md`](docs/CURRENT-STATE.md).

## First run: LLM benchmark (tok/s)

Before the DL stack goes on, the box gets its comparison number: Ollama in the same
version as on the 3090, the three models, then `~/hermes-bench/llm-bench.sh` from
`rmesterheide/hermes-on-rtx3090`. Requirements on a fresh system and the automation:
[`docs/SETUP.md` section 0](docs/SETUP.md#0-llm-benchmark-first-toks--requirements-on-a-fresh-system),
[`scripts-4090/10-ollama-llm-bench.sh`](scripts-4090/10-ollama-llm-bench.sh).

## Layout

- [`docs/SETUP.md`](docs/SETUP.md) — the generic from-scratch guide (Ubuntu 26.04,
  CUDA 13, cuDNN 9, venvs, JupyterLab service, Docker)
- [`docs/CURRENT-STATE.md`](docs/CURRENT-STATE.md) — the actual state of `4090rtx`,
  deviation table, gotchas, open items
- [`scripts/`](scripts) — the guide's base scripts, unchanged (`00` to `09`, `run-all.sh`)
- [`scripts-4090/`](scripts-4090) — what had to be done differently on this box:
  - `04-06-cuda13.2-cudnn-venvs.sh` — CUDA 13.2 from the `ubuntu2404` repo, cuDNN 9, the venvs, as actually run
  - `06b-tfgpu-py313.sh` — TensorFlow venv on a uv-managed Python 3.13 plus a
    `sitecustomize.py` that preloads the pip CUDA 12 libraries ahead of the system CUDA 13
  - `09-docker-apt.sh` — Docker from the Ubuntu archive instead of `get.docker.com | sudo sh`,
    runs entirely within the narrowly scoped sudoers
  - `10-ollama-llm-bench.sh` — Ollama (user service, same version as the 3090) + models + benchmark preparation
  - `10b-run-llm-bench.sh` — benchmark run under headless conditions (graphics stack shut down for the run, otherwise the 64k model partially spills into RAM)
- [`environments/`](environments) — pip requirements per venv
- [`systemd/jupyterlab.service`](systemd/jupyterlab.service) — JupyterLab as a user service

## Deviations in short

| Topic | Guide | 4090rtx |
|---|---|---|
| CUDA repo | `ubuntu2604` | `ubuntu2404` (2604 only carries 13.3+, driver 595 supports up to 13.2) |
| CUDA toolkit | 13.0 | 13.2 (matches the driver ceiling and the PyTorch `cu132` wheels) |
| Python for TF | system 3.14 | uv Python 3.13 (TF 2.21 has no cp314 wheels) |
| Docker | Docker installer script | `docker.io` + `docker-compose-v2` via apt |
| Remote desktop | Xorg + NvFBC + nvenc (3090) | Wayland + XDG portal/PipeWire + Vulkan Video encoders |

Details and the reasons are in `docs/CURRENT-STATE.md`.
