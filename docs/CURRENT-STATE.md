# 4090rtx — setup log (as of 2026-09-13)

Second DL workstation, set up following the from-scratch guide from
`rmesterheide/rtx3090-dl-workstation` (`docs/SETUP.md`). First real fresh-install
run of that guide; the 3090 box had been pre-provisioned.

## Hardware / OS

| | |
|---|---|
| Host / IP | `4090rtx`, 192.168.0.21, user `rmesterheide` (SSH key from the Mac) |
| CPU / RAM | i9-13900K, 62 GB |
| GPU | RTX 4090 (AD102), 24 GB, driver `nvidia-driver-595-open` 595.91.07 (from the Ubuntu installer), CUDA ceiling 13.2 |
| OS | Ubuntu 26.04.1 LTS (resolute), kernel 7.0.0-31 |
| Disk | Samsung 980 PRO 1 TB NVMe |
| Network | `eno2` 2.5 GbE (the 3090 box is on 10G) |
| Terminal | Ptyxis (26.04 default), copy/paste rebound to `<ctrl>c`/`<ctrl>v` (`org.gnome.Ptyxis.Shortcuts`) |

## LLM benchmark (Ollama, hermes-bench)

Step 0 of the guide ([SETUP.md](SETUP.md#0-llm-benchmark-first-toks--requirements-on-a-fresh-system)),
prepared 2026-09-13 with [`scripts-4090/10-ollama-llm-bench.sh`](../scripts-4090/10-ollama-llm-bench.sh):

| | 3090 (`ubnt2080rm`) | 4090rtx |
|---|---|---|
| Ollama | 0.34.0, system service as user `ollama`, `/usr/local/bin` | **0.34.0**, `~/ollama/bin`, **`systemd --user` unit** `ollama.service` (no root needed), CUDA lib `cuda_v13`, driver 13.2 |
| `OLLAMA_NUM_PARALLEL` | not set (=1, the concurrency test ran queued) | **1** in the unit (4 pushes the 64k model into RAM, see below) |
| Models | qwen3.6:27b, qwen3.6:35b, gemma4:31b, qwen3.6-27b-64k | the same; `qwen3.6-27b-64k` via `ollama create` from `~/hermes-bench/Modelfile.qwen3.6-27b-64k` (`FROM qwen3.6:27b`, `num_ctx 65536`) |
| Script | `~/hermes-bench/llm-bench.sh` (without `LC_ALL=C` → CPU/RAM fields empty) | `~/hermes-bench/llm-bench.sh`, repo version with `LC_ALL=C` |
| PyTorch for the TFLOPS line | not available | prepend `PATH=$HOME/venvs/torchgpu/bin:$PATH` |

**VRAM finding (2026-09-13):** the desktop on this box costs ~970 MiB of VRAM
(gnome-remote-desktop 392, Sunshine 104, GNOME/Xwayland/apps the rest). That is enough to keep
`qwen3.6-27b-64k` (18 GB incl. the 64k KV cache) from fitting: 93 % GPU / 7 % RAM.
Measured (num_predict 64, temperature 0):

| Condition | Offload | Generation |
|---|---|---|
| `OLLAMA_NUM_PARALLEL=4` (KV cache ×4) | 93 % GPU | 37 tok/s |
| `NUM_PARALLEL=1`, desktop services running | 93 % GPU | 87 tok/s |
| `NUM_PARALLEL=1`, only the RDP daemon stopped | 93 % GPU | 96 tok/s |
| `NUM_PARALLEL=1`, RDP daemon + Sunshine stopped | **100 % GPU** | **118 tok/s** |

**Headless measurement condition (since the morning of 2026-09-13):** `10b-run-llm-bench.sh`
unloads all models and shuts the graphics stack down completely via `systemctl isolate
multi-user.target` (GDM, GNOME/Wayland, Sunshine). The `systemd --user` manager with Ollama survives
thanks to linger. Baseline afterwards: **33 MiB VRAM, 0 processes**, the 64k model 100 % on GPU,
116 tok/s in the smoke test. After the run `isolate graphical.target`; autologin and Sunshine come
back on their own. Unplugging the monitor gains nothing (the compositor keeps running) and would
leave Sunshine with nothing to capture. The 3090 idles at **826 MiB** VRAM (Xorg,
gnome-remote-desktop 258, Sunshine 262) — for a fair comparison use the same wrapper there
(`~/hermes-bench/run-headless.sh`, kept in the hermes repo as `bench/run-headless.sh`).

Consequences: `gnome-remote-desktop.service` (RDP, 392 MiB, redundant next to Sunshine) disabled
permanently on 2026-09-13 (`systemctl --user disable --now`, port 3389 closed; idle VRAM baseline now
~380 MiB), `OLLAMA_NUM_PARALLEL=1` in the unit (as on the 3090), and the benchmark runs over SSH
with the graphics stack down — wrapper [`scripts-4090/10b-run-llm-bench.sh`](../scripts-4090/10b-run-llm-bench.sh).
The script's concurrency section is therefore equally (un)informative on both boxes.

**Result 2026-09-13, headless on both boxes** (raw data and analysis in the hermes repo, `docs/benchmarks.md`):

| Model | Generation tok/s (3090 → 4090) | Prompt eval 16k tok/s | TTFT 16k (s) | tok/Wh |
|---|---|---|---|---|
| qwen3.6-27b-64k | 67 → 93 (1.4×) | 1318 → 2623 (2.0×) | 9.6 → 4.8 | 696 → 1024 |
| qwen3.6:35b (MoE) | 135 → 202 (1.5×) | 3446 → 6878 (2.0×) | 3.7 → 1.8 | 2171 → 4838 |
| gemma4:31b | 27 → 37 (1.4×) | 1087 → 2258 (2.1×) | 11.6 → 5.6 | 285 → 441 |

Raw bf16 matmul (torch 2.14+cu132): 171.8 TFLOPS. Generation scales 1.4–1.5× (bandwidth bound),
prompt processing 2.0× (compute bound). **Correction to the first comparison:** the 1.8× reported
initially came from the 3090 having all three models partially in RAM under its 826 MiB desktop load
(+31 to +65 % once headless). The old runs are kept alongside as `*-desktop-run.md`.

Run: `bash ~/rtx4090-dl-workstation/scripts-4090/10b-run-llm-bench.sh` (about 10 min, over SSH),
result in `~/hermes-bench/results/4090rtx-RTX-4090-<date>.md`, then into the
`hermes-on-rtx3090` repo (`bench/results/`, 4090 column in `docs/benchmarks.md`).
Note from the 3090 analysis: gemma4:31b is at the VRAM limit on both cards with its 256k default
context — repeat both sides with a smaller `num_ctx` for a fair comparison.

## Hermes Agent + nvtop (2026-09-13)

As on the 3090 ([walkthrough in the hermes repo](https://github.com/rmesterheide/hermes-on-rtx3090)),
but set up non-interactively:

| | 3090 | 4090rtx |
|---|---|---|
| Hermes | v0.21.2 (2026.9.11), installer with wizard | **v0.21.2**, `install.sh --skip-setup --non-interactive`, config copied from the 3090 afterwards |
| Config | `~/.hermes/config.yaml`: provider `custom`, `http://localhost:11434/v1`, model `qwen3.6-27b-64k:latest`, terminal backend `local` | identical (copy), installer default kept as `config.yaml.installer-default` |
| Secrets | `~/.hermes/.env` with `HA_URL`/`HA_TOKEN` | copy, deduplicated (placeholder `HA_URL` removed), `chmod 600` |
| Skill | `~/.hermes/skills/home-assistant` | copy, `hermes skills list` → enabled |
| nvtop | 3.0.2 (apt) | 3.2.0 (apt) |
| Extras | — | ripgrep (installer hint), xz-utils |

Verified (one-shot `hermes chat -q`, Ollama model on the GPU):
- "nvidia-smi + df -h" question: 3 tool calls, correct answer, **13 s**.
- "How many and which lights are on?": HA API test `{"message":"API running."}`, 10 tool calls, list of lights incl. group detection, **17 s**.

Note: with Sunshine running the 64k model loads only 93 % onto the GPU (see the VRAM finding
above); fine for the agent, stop Sunshine for measurements.

## Deviations from the guide

| Step | Guide | 4090rtx | Reason |
|---|---|---|---|
| 02 Git/GitHub | interactive | git+gh via apt, identity + ed25519 key set; `gh auth login` done via device flow, key uploaded from the Mac's gh | the login cannot be automated |
| 03 Driver | `ubuntu-drivers install` | skipped | the installer already brought 595-open |
| 04 CUDA | `cuda-toolkit-13-0`, repo `ubuntu2604` if available | `cuda-toolkit-13-2` from repo **`ubuntu2404`** | the `ubuntu2604` repo only carries 13.3/13.4, both above the driver ceiling 13.2. 13.2 matches the driver and the PyTorch `cu132` wheels exactly |
| 05 cuDNN | `cudnn9-cuda-13` | same (9.26.0.51) | – |
| 06 venvs | `python3 -m venv` (3.14) | `tfgpu` on a uv-managed **Python 3.13** (`scripts-4090/06b-tfgpu-py313.sh`), the rest on 3.14 | TensorFlow 2.21 has no cp314 wheels; 26.04 ships only 3.14 via apt |
| 07 Frameworks | `tensorflow[and-cuda]` | same, plus a `sitecustomize.py` in the tfgpu venv that preloads the pip `nvidia-*-cu12` libs | otherwise TF found the system cuDNN (CUDA 13 build) first via ldconfig → no GPU. Torch 2.14+cu132 and JAX 0.11 saw the GPU directly |
| 09 Docker | `get.docker.com \| sudo sh` | `docker.io` + `docker-compose-v2` from the Ubuntu archive (`scripts-4090/09-docker-apt.sh`) | runs entirely within the scoped sudoers, no third-party script as root |

## Sudoers

`/etc/sudoers.d/rmesterheide-claude` (created by the user), NOPASSWD for:
`apt-get apt dpkg systemctl loginctl ethtool gpg tee usermod nvidia-ctk`.
Reboot via `sudo systemctl reboot`.

## Gotchas

- `gh auth login` (gh 2.46 on 26.04) does not know `--skip-ssh-key` yet; the survey prompts can be
  driven remotely via `script -q -f -c ... log` and piped escape sequences (`\033[B` = arrow down,
  `\r` = Enter), the one-time code then shows up in the log.
- `pkill -f <pattern>` over SSH kills the SSH shell itself when the pattern appears in its own
  command line. Filter processes with `ps` + `awk` instead.
- After switching the repo 2604 → 2404, `cuda-ubuntu2604-x86_64.list` was left behind (NO_PUBKEY
  warning). Without `rm` in the sudoers it was emptied via `sudo tee ... </dev/null`.
- SSH on 26.04 is socket-activated (`ssh.socket` enabled, `ssh.service` disabled). `systemctl
  enable ssh` therefore reports an error, but is not needed.

## Verified (2026-09-12)

- torch 2.14.0+cu132: `cuda_available=True`, RTX 4090
- tensorflow 2.21.0 (Py 3.13): GPU:0 visible, matmul on the GPU
- jax 0.11.1: `CudaDevice(id=0)`
- Docker: `nvidia/cuda:13.2.0-base` container sees the 4090
- JupyterLab user service active on 127.0.0.1:8888, linger on, 7 kernels registered

## Remote desktop: Sunshine + Moonlight (2026-09-12)

Same goal as on the 3090, but the implementation differs because Ubuntu 26.04 only ships a
**Wayland** GNOME session (no Xorg session anymore) and a monitor (Samsung 4K on DP-3) is attached:

| Topic | 3090 (`ubnt2080rm`) | 4090rtx |
|---|---|---|
| Session | Xorg, headless with a modeline hack | Wayland, real monitor, no headless part needed |
| Capture | NvFBC | **XDG portal / PipeWire** (KMS returns an empty monitor list on nvidia-drm, wlgrab is wlroots-only) |
| Encoder | h264_nvenc (Sunshine pinned to v2025.924, driver 570) | **h264/hevc/av1_vulkan** (Vulkan Video, hardware). Sunshine 2026.906 needs NVENC API 13.1 = driver ≥ 610, the box has 595 → the nvenc probe fails, Vulkan takes over |
| Package | ubuntu-24.04 .deb | native `ubuntu26.04` .deb, `sudo apt-get install ./deb` |
| Unit | `sunshine.service` | `app-dev.lizardbyte.app.Sunshine.service` (user, graphical-session.target) |

**The blocker that cost time:** GNOME refuses every remote desktop portal session while the screen is
locked. Symptom in the Sunshine log: `RemoteDesktop CreateSession failed with response code: 2`, in
the portal log: `Session creation inhibited`. Sunshine then hangs in the encoder probe and opens no
ports. Hence: `lock-enabled=false`, `idle-delay=0` (gsettings) and GDM autologin, otherwise the
stream freezes after every idle period.

Done by the user (sudo/security): GDM autologin, ufw rules (LAN only, TCP 47984/47989/47990/48010,
UDP 47998-48010), unlocking. Verified: ports reachable from the Mac, web UI on https://192.168.0.21:47990.

**Session resolution:** host desktop switched from 3840x2160 (scale 1.33) to **1920x1080@60, scale 1**,
as on the 3090, so Moonlight gets a 1:1 image. There is no xrandr on Wayland; over SSH it works
through Mutter's DBus API (`org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig`, method 2 =
persistent, connector `DP-3`, mode ID `1920x1080@60.000`). Careful: zsh on the Mac globs `[0]` in SSH
command strings — send scripts via `ssh host 'bash -s' < script.sh`.

**Web UI from the Mac:** Sunshine's CSRF protection only allows `localhost`. Access via
`https://192.168.0.21:47990` otherwise ends in "Internal error" when creating the credentials (log:
`CSRF protection blocked request from origin`). Fix in `~/.config/sunshine/sunshine.conf`:
`csrf_allowed_origins = https://192.168.0.21:47990,...`

If Vulkan encoding does not convince in the stream: pin Sunshine to a release before the NVENC 13.1
jump (technique as on the 3090: unpack the `.deb`, run the binary standalone, read the log) or wait
for driver ≥ 610.

## Done / open

- [x] gh login on the box (device flow, 2026-09-12), the box's SSH key on GitHub as `4090rtx` (uploaded from the Mac's gh), `git_protocol ssh`
- [x] `~/rtx4090-dl-workstation` is a real clone now. Cleanup candidates in the home directory: `~/rtx4090-dl-workstation.rsync-copy`, `~/rtx3090-dl-workstation.rsync-copy` (both old copies), `~/setup-0*.sh`, `~/setup-0*.log`, `~/ollama-pull.log`
- [x] Own repo: [rmesterheide/rtx4090-dl-workstation](https://github.com/rmesterheide/rtx4090-dl-workstation) (created 2026-09-12, public since 2026-09-13)
- [x] Web UI credentials set, Moonlight paired from the Mac, stream running (HEVC/Vulkan, 1080p)
- [x] Reboot test 2026-09-12 23:31: autologin into the Wayland session (not locked), Sunshine 1080p + encoders, JupyterLab, Docker, all ports — came up without intervention
- [ ] Agent-turn benchmark (Hermes one-shot tasks, metrics from `~/.hermes/state.db`) — proposed, not built yet
