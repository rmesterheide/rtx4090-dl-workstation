# RTX 4090 Deep Learning Workstation (`4090rtx`)

Setup-Doku und Skripte für die zweite DL-Workstation: RTX 4090, Ubuntu 26.04 LTS,
frisch installiert am 2026-09-12. Schwester-Repo von
[rtx3090-dl-workstation](https://github.com/rmesterheide/rtx3090-dl-workstation);
der From-Scratch-Guide dort ([`docs/SETUP.md`](docs/SETUP.md), hier als Kopie)
wurde auf dieser Maschine zum ersten Mal wirklich von Null durchgefahren.

**Was tatsächlich auf der Box läuft, inklusive aller Abweichungen vom Guide und
der Remote-Desktop-Einrichtung (Sunshine/Moonlight unter Wayland):**
[`docs/CURRENT-STATE.md`](docs/CURRENT-STATE.md).

## Erster Lauf: LLM-Benchmark (tok/s)

Bevor der DL-Stack kommt, bekommt die Box ihre Vergleichszahl: Ollama in derselben
Version wie auf der 3090, die drei Modelle, dann `~/hermes-bench/llm-bench.sh` aus
`rmesterheide/hermes-on-rtx3090`. Voraussetzungen auf einem frischen System und
Automatisierung: [`docs/SETUP.md` Abschnitt 0](docs/SETUP.md#0-llm-benchmark-first-toks--requirements-on-a-fresh-system),
[`scripts-4090/10-ollama-llm-bench.sh`](scripts-4090/10-ollama-llm-bench.sh).

## Layout

- [`docs/SETUP.md`](docs/SETUP.md) — der generische From-Scratch-Guide (Ubuntu 26.04,
  CUDA 13, cuDNN 9, venvs, JupyterLab-Service, Docker)
- [`docs/CURRENT-STATE.md`](docs/CURRENT-STATE.md) — Ist-Zustand von `4090rtx`,
  Abweichungstabelle, Gotchas, offene Punkte
- [`scripts/`](scripts) — die Basis-Skripte des Guides, unverändert (`00` bis `09`, `run-all.sh`)
- [`scripts-4090/`](scripts-4090) — was auf dieser Box anders laufen musste:
  - `06b-tfgpu-py313.sh` — TensorFlow-venv auf uv-verwaltetem Python 3.13 plus
    `sitecustomize.py`, das die pip-CUDA-12-Libs vor dem System-CUDA-13 lädt
  - `09-docker-apt.sh` — Docker aus dem Ubuntu-Archiv statt `get.docker.com | sudo sh`,
    läuft komplett mit dem eng gescopten sudoers
  - `10-ollama-llm-bench.sh` — Ollama (User-Service, versionsgleich zur 3090) + Modelle + Benchmark-Vorbereitung
- [`environments/`](environments) — pip-Requirements pro venv
- [`systemd/jupyterlab.service`](systemd/jupyterlab.service) — JupyterLab als User-Service

## Kurzfassung der Abweichungen

| Thema | Guide | 4090rtx |
|---|---|---|
| CUDA-Repo | `ubuntu2604` | `ubuntu2404` (2604 führt nur 13.3+, Treiber 595 kann max. 13.2) |
| CUDA-Toolkit | 13.0 | 13.2 (passt zu Treiber-Ceiling und PyTorch-`cu132`-Wheels) |
| Python für TF | System-3.14 | uv-Python 3.13 (TF 2.21 hat keine cp314-Wheels) |
| Docker | Docker-Installer | `docker.io` + `docker-compose-v2` per apt |
| Remote-Desktop | Xorg + NvFBC + nvenc (3090) | Wayland + XDG-Portal/PipeWire + Vulkan-Video-Encoder |

Details und die Gründe stehen in `docs/CURRENT-STATE.md`.
