# RTX 3090 Deep Learning Workstation — Setup Guide

Target hardware: single NVIDIA GeForce RTX 3090 (24 GB VRAM, Ampere).
Target OS: **Ubuntu 26.04 LTS "Resolute Raccoon"** (released 2026-04-23).

This guide is a reorganized, 2026-updated version of a well-known 2022-era
Ubuntu 22.04 deep learning setup guide. Structural credit to the
[original gist](https://gist.github.com/amir-saniyan/b3d8e06145a8569c0d0e030af6d60bea);
versions, package managers, and several steps (JupyterLab as a service, GPU
dashboard, SSH-tunnel-only remote access) have been updated or added.
See [Changes vs. the 2022 guide](#changes-vs-the-2022-guide) at the end.

Every step below has a corresponding script in [`scripts/`](../scripts) so the
whole setup can be re-run non-interactively on a fresh machine.

## Table of contents

1. [Base system](#1-base-system)
2. [Development tools](#2-development-tools)
3. [Git & GitHub](#3-git--github)
4. [NVIDIA driver](#4-nvidia-driver)
5. [CUDA Toolkit](#5-cuda-toolkit)
6. [cuDNN](#6-cudnn)
7. [Python environments](#7-python-environments)
8. [Frameworks & verification](#8-frameworks--verification)
9. [JupyterLab as a systemd service](#9-jupyterlab-as-a-systemd-service)
10. [Remote access (SSH tunnel, no open ports)](#10-remote-access-ssh-tunnel-no-open-ports)
11. [Docker + NVIDIA Container Toolkit](#11-docker--nvidia-container-toolkit)
12. [Editors](#12-editors)
13. [Changes vs. the 2022 guide](#changes-vs-the-2022-guide)

---

## 1. Base system

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt autoremove -y && sudo apt autoclean -y
sudo reboot
```

Script: [`scripts/00-system.sh`](../scripts/00-system.sh)

## 2. Development tools

```bash
sudo apt install -y build-essential pkg-config cmake ninja-build \
  python3 python3-venv python3-pip python3-dev curl wget unzip
```

Script: [`scripts/01-dev-tools.sh`](../scripts/01-dev-tools.sh)

## 3. Git & GitHub

```bash
sudo apt install -y git gh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519
gh auth login --git-protocol ssh --web
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)"
```

Script: [`scripts/02-git-github.sh`](../scripts/02-git-github.sh) (installs
tools and generates the key; the `gh auth login` / device-code step stays
interactive on purpose — it is your GitHub login, not something to automate).

## 4. NVIDIA driver

Ampere consumer cards (RTX 3090) don't need a specific pinned driver version —
use the distro's driver-selection tool, which picks the current recommended
branch for your GPU:

```bash
sudo apt install -y ubuntu-drivers-common
sudo ubuntu-drivers install     # picks the recommended driver automatically
sudo reboot
nvidia-smi                      # verify after reboot
```

If you need a specific driver branch (e.g. to match a pinned CUDA version),
list options first with `ubuntu-drivers devices` and install explicitly,
e.g. `sudo apt install -y nvidia-driver-580` (580 was the current
long-lived production branch as of mid-2026 — check
[NVIDIA's driver page](https://www.nvidia.com/en-us/drivers/) for what's
current when you run this).

Script: [`scripts/03-nvidia-driver.sh`](../scripts/03-nvidia-driver.sh)

## 5. CUDA Toolkit

Installed from NVIDIA's apt repository (not the `.run` installer — cleaner
upgrades, no driver conflicts since we already installed the driver above):

```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2604/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update
sudo apt install -y cuda-toolkit-13-0
```

> **Match the toolkit to the driver, don't just grab the newest.** The CUDA
> toolkit version you install must be ≤ the max CUDA version your installed
> driver supports (shown in the top-right of `nvidia-smi`'s header). On a
> fresh install via `ubuntu-drivers install` in step 4, the driver is new
> enough for CUDA 13.0. On an **existing** machine with an older driver
> already installed (see [`CURRENT-STATE.md`](CURRENT-STATE.md) for a real
> example: driver 570.x → max CUDA 12.8), installing `cuda-toolkit-13-0`
> would just fail to run — install the matching `cuda-toolkit-12-X` instead,
> or upgrade the driver first if you actually need 13.x features.

Add to `~/.bashrc`:

```bash
export PATH=/usr/local/cuda/bin${PATH:+:${PATH}}
export LD_LIBRARY_PATH=/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
```

Verify: `nvcc --version` and `nvidia-smi`.

> Note: if `ubuntu2604` isn't published yet in NVIDIA's repo list at the time
> you run this, use the `ubuntu2404` repo — it works fine as a CUDA-only apt
> source on 26.04 (only the driver .deb is OS-version-sensitive, not the
> toolkit). Check https://developer.nvidia.com/cuda-downloads for the current
> path.

Script: [`scripts/04-cuda-toolkit.sh`](../scripts/04-cuda-toolkit.sh)

## 6. cuDNN

```bash
sudo apt install -y cudnn9-cuda-13
```

(cuDNN 9's apt packages are versioned by CUDA major version, no more manual
`.deb` download from behind a login wall.)

Script: [`scripts/05-cudnn.sh`](../scripts/05-cudnn.sh)

## 7. Python environments

One venv per purpose, matching the original guide's layout:

```bash
mkdir -p ~/venvs
for env in ml cv torchgpu tfgpu ultralytics onnxgpu jaxgpu; do
  python3 -m venv ~/venvs/"$env"
done
```

Script: [`scripts/06-python-envs.sh`](../scripts/06-python-envs.sh)

## 8. Frameworks & verification

Current wheel index as of this guide: PyTorch ships CUDA 13.2 wheels tagged
`cu132` (check https://download.pytorch.org/whl/torch/ for the current list).

**PyTorch** (`~/venvs/torchgpu`):

```bash
source ~/venvs/torchgpu/bin/activate
pip install --upgrade pip
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu132
python -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

**TensorFlow** (`~/venvs/tfgpu`):

```bash
source ~/venvs/tfgpu/bin/activate
pip install --upgrade pip
pip install tensorflow[and-cuda] tensorboard keras
python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"
```

**Ultralytics YOLO** (`~/venvs/ultralytics`): `pip install ultralytics`

**ONNX Runtime GPU** (`~/venvs/onnxgpu`): `pip install onnxruntime-gpu`

**JAX** (`~/venvs/jaxgpu`): `pip install --upgrade "jax[cuda13]"`

Per-environment requirements files live in
[`environments/`](../environments); install with
`pip install -r environments/<name>.txt` after activating.

Script: [`scripts/07-frameworks.sh`](../scripts/07-frameworks.sh) installs
all of the above end-to-end and runs the verification snippets.

## 9. JupyterLab as a systemd service

Rather than running `jupyter lab` in a terminal you have to keep open, run it
as a systemd user service with one Jupyter **kernel per venv**, so you pick
the framework from the Jupyter kernel dropdown instead of juggling shells.
Includes [`jupyterlab-nvdashboard`](https://github.com/rapidsai/jupyterlab-nvdashboard)
for live GPU utilization/VRAM/temperature graphs inside the notebook UI.

```bash
# in a "hub" venv used only to run the Lab server itself
python3 -m venv ~/venvs/jupyterhub
source ~/venvs/jupyterhub/bin/activate
pip install jupyterlab jupyterlab-nvdashboard

# register each framework venv as a selectable kernel
for env in ml cv torchgpu tfgpu ultralytics onnxgpu jaxgpu; do
  ~/venvs/"$env"/bin/pip install ipykernel
  ~/venvs/"$env"/bin/python -m ipykernel install --user \
    --name "$env" --display-name "Python ($env)"
done
```

Service unit: [`systemd/jupyterlab.service`](../systemd/jupyterlab.service)

```bash
mkdir -p ~/.config/systemd/user
cp systemd/jupyterlab.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now jupyterlab.service
loginctl enable-linger "$USER"   # keep it running after SSH logout
```

JupyterLab listens on `127.0.0.1:8888` only — not exposed on the LAN. See the
next section for how to reach it.

Script: [`scripts/08-jupyterlab.sh`](../scripts/08-jupyterlab.sh)

## 10. Remote access (SSH tunnel, no open ports)

Don't open port 8888 on the router/firewall. Instead, tunnel it over SSH from
the client machine (your Mac):

```bash
ssh -N -L 8888:127.0.0.1:8888 you@ubuntu-server.local
```

Then open `http://127.0.0.1:8888` in the browser on the Mac. Token/password
for the Lab session is in `~/.config/systemd/user/jupyterlab.service` or via
`jupyter server list` on the server.

For convenience, add a `Host` alias to `~/.ssh/config` on the Mac:

```
Host dlserver
  HostName ubuntu-server.local
  User you
  LocalForward 8888 127.0.0.1:8888
```

Then just `ssh dlserver` opens the tunnel.

## 11. Docker + NVIDIA Container Toolkit

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# verify
docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi
```

Script: [`scripts/09-docker.sh`](../scripts/09-docker.sh)

## 12. Editors

- **VS Code** on the Mac + the *Remote - SSH* extension, connecting to the
  same `dlserver` host alias from section 10 — edit/debug directly on the
  GPU box, no local Python needed.
- **PyCharm Professional** supports a remote Python interpreter over SSH the
  same way; point it at `~/venvs/<env>/bin/python` on the server.

---

## Changes vs. the 2022 guide

| Area | 2022 guide | This guide (2026) |
|---|---|---|
| OS | Ubuntu 22.04 | Ubuntu 26.04 LTS |
| Driver install | Manual `nvidia-driver-535` pin | `ubuntu-drivers install` (auto-selects current branch) |
| CUDA install | `.run` installer, manual `--override` | apt via `cuda-keyring`, CUDA 13.x |
| cuDNN install | Manual `.deb` download behind NVIDIA login | `apt install cudnn9-cuda-13` |
| PyTorch | `pip install torch` (CPU-index default) | Explicit `cu132` wheel index |
| Notebook access | Not covered | JupyterLab as a systemd **service**, one kernel per venv |
| GPU monitoring | `nvidia-smi` in a terminal | `jupyterlab-nvdashboard` live in-notebook |
| Remote access | Not covered | SSH tunnel only, no open ports |
| Containers | Docker + toolkit, brief | Same, updated package repo syntax |
