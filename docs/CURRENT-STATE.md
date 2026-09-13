# 4090rtx — Setup-Protokoll (Stand 2026-09-12)

Zweite DL-Workstation, aufgesetzt nach dem From-Scratch-Guide aus
`rmesterheide/rtx3090-dl-workstation` (`docs/SETUP.md`). Erste echte
Fresh-Install-Anwendung des Guides; die 3090-Box war vorprovisioniert.

## Hardware / OS

| | |
|---|---|
| Host / IP | `4090rtx`, 192.168.0.21, User `rmesterheide` (SSH-Key vom Mac) |
| CPU / RAM | i9-13900K, 62 GB |
| GPU | RTX 4090 (AD102), 24 GB, Treiber `nvidia-driver-595-open` 595.91.07 (vom Ubuntu-Installer), CUDA-Ceiling 13.2 |
| OS | Ubuntu 26.04.1 LTS (resolute), Kernel 7.0.0-31 |
| Disk | Samsung 980 PRO 1 TB NVMe |
| Netz | `eno2` 2.5 GbE (3090-Box hängt an 10G) |
| Terminal | Ptyxis (26.04-Standard), Copy/Paste auf `<ctrl>c`/`<ctrl>v` umgebogen (`org.gnome.Ptyxis.Shortcuts`) |

## LLM-Benchmark (Ollama, hermes-bench)

Schritt 0 des Guides ([SETUP.md](SETUP.md#0-llm-benchmark-first-toks--requirements-on-a-fresh-system)),
vorbereitet 2026-09-13 mit [`scripts-4090/10-ollama-llm-bench.sh`](../scripts-4090/10-ollama-llm-bench.sh):

| | 3090 (`ubnt2080rm`) | 4090rtx |
|---|---|---|
| Ollama | 0.34.0, System-Service als User `ollama`, `/usr/local/bin` | **0.34.0**, `~/ollama/bin`, **`systemd --user`-Unit** `ollama.service` (kein root nötig), CUDA-Lib `cuda_v13`, Treiber 13.2 |
| `OLLAMA_NUM_PARALLEL` | nicht gesetzt (=1, Concurrency-Test lief mit Queue) | **1** in der Unit (4 drängt das 64k-Modell in den RAM, s.u.) |
| Modelle | qwen3.6:27b, qwen3.6:35b, gemma4:31b, qwen3.6-27b-64k | dieselben, `qwen3.6-27b-64k` per `ollama create` aus `~/hermes-bench/Modelfile.qwen3.6-27b-64k` (`FROM qwen3.6:27b`, `num_ctx 65536`) |
| Skript | `~/hermes-bench/llm-bench.sh` (ohne `LC_ALL=C` → CPU/RAM-Felder leer) | `~/hermes-bench/llm-bench.sh`, Fassung aus dem Repo mit `LC_ALL=C` |
| PyTorch für die TFLOPS-Zeile | nicht verfügbar | `PATH=$HOME/venvs/torchgpu/bin:$PATH` voranstellen |

**VRAM-Befund (2026-09-13):** Der Desktop kostet auf dieser Box ~970 MiB VRAM
(gnome-remote-desktop 392, Sunshine 104, GNOME/Xwayland/Apps der Rest); die 3090 ist headless.
Damit passt `qwen3.6-27b-64k` (18 GB inkl. 64k-KV-Cache) nicht mehr ganz: 93 % GPU / 7 % RAM.
Gemessen (num_predict 64, temperature 0):

| Bedingung | Offload | Generation |
|---|---|---|
| `OLLAMA_NUM_PARALLEL=4` (KV-Cache ×4) | 93 % GPU | 37 tok/s |
| `NUM_PARALLEL=1`, Desktop-Dienste an | 93 % GPU | 87 tok/s |
| `NUM_PARALLEL=1`, nur RDP-Daemon aus | 93 % GPU | 96 tok/s |
| `NUM_PARALLEL=1`, RDP-Daemon + Sunshine aus | **100 % GPU** | **118 tok/s** |

Konsequenz: `gnome-remote-desktop.service` (RDP, 392 MiB, neben Sunshine überflüssig) am 2026-09-13
dauerhaft deaktiviert (`systemctl --user disable --now`, Port 3389 zu; VRAM-Basis im Leerlauf jetzt ~380 MiB),
`OLLAMA_NUM_PARALLEL=1` in der Unit (wie 3090), und der Benchmark läuft per SSH
mit gestoppten Remote-Desktop-Diensten — Wrapper [`scripts-4090/10b-run-llm-bench.sh`](../scripts-4090/10b-run-llm-bench.sh).
Der Concurrency-Teil des Skripts ist damit auf beiden Boxen gleich (nicht) aussagekräftig.

**Ergebnis 2026-09-13** (voller Lauf, Rohdaten und Vergleich im hermes-Repo `docs/benchmarks.md`):

| Modell | Generation tok/s (3090 → 4090) | Prompt eval 16k tok/s | TTFT 16k (s) | tok/Wh |
|---|---|---|---|---|
| qwen3.6-27b-64k | 51.3 → 93.3 (1.8×) | 1165 → 2623 (2.3×) | 10.8 → 4.8 | 561 → 1021 |
| qwen3.6:35b (MoE) | 93.0 → 164.4 (1.8×) | 2484 → 5960 (2.4×) | 5.1 → 2.1 | 1924 → 4552 |
| gemma4:31b | 16.6 → 31.8 (1.9×) | 898 → 2046 (2.3×) | 14.1 → 6.2 | 247 → 548 |

Raw bf16 matmul (torch 2.14+cu132): 171.7 TFLOPS. Generation skaliert flach mit 1.8× (bandbreitenbegrenzt),
Prompt-Verarbeitung mit 2.3–2.4× (rechenbegrenzt, Tensor Cores).

Lauf: `bash ~/rtx4090-dl-workstation/scripts-4090/10b-run-llm-bench.sh` (ca. 10 min, per SSH),
Ergebnis nach `~/hermes-bench/results/4090rtx-RTX-4090-<datum>.md`, dann ins
`hermes-on-rtx3090`-Repo (`bench/results/`, 4090-Spalte in `docs/benchmarks.md`).
Hinweis aus der 3090-Auswertung: gemma4:31b lief dort vermutlich teilweise im RAM
(256k Default-Kontext) — für einen fairen Vergleich beide Seiten mit kleinerem `num_ctx` wiederholen.

## Hermes Agent + nvtop (2026-09-13)

Wie auf der 3090 ([Walkthrough im hermes-Repo](https://github.com/rmesterheide/hermes-on-rtx3090)),
nur nicht-interaktiv aufgesetzt:

| | 3090 | 4090rtx |
|---|---|---|
| Hermes | v0.21.2 (2026.9.11), Installer mit Wizard | **v0.21.2**, `install.sh --skip-setup --non-interactive`, Config danach von der 3090 kopiert |
| Config | `~/.hermes/config.yaml`: provider `custom`, `http://localhost:11434/v1`, Modell `qwen3.6-27b-64k:latest`, Terminal-Backend `local` | identisch (Kopie), Installer-Default gesichert als `config.yaml.installer-default` |
| Secrets | `~/.hermes/.env` mit `HA_URL`/`HA_TOKEN` | Kopie, dedupliziert (Platzhalter-`HA_URL` entfernt), `chmod 600` |
| Skill | `~/.hermes/skills/home-assistant` | Kopie, `hermes skills list` → enabled |
| nvtop | 3.0.2 (apt) | 3.2.0 (apt) |
| Extras | — | ripgrep (Installer-Hinweis), xz-utils |

Verifiziert (one-shot `hermes chat -q`, Ollama-Modell auf der GPU):
- „nvidia-smi + df -h“-Frage: 3 Tool-Calls, korrekte Antwort, **13 s**.
- „How many and which lights are on?“: HA-API-Test `{"message":"API running."}`, 10 Tool-Calls, Lampenliste inkl. Gruppen-Erkennung, **17 s**.

Hinweis: Mit laufendem Sunshine lädt das 64k-Modell nur zu 93 % auf die GPU (siehe VRAM-Befund
oben); für den Agenten reicht das, für Messungen Sunshine stoppen.

## Abweichungen vom Guide

| Schritt | Guide | 4090rtx | Grund |
|---|---|---|---|
| 02 Git/GitHub | interaktiv | git+gh per apt, Identität + ed25519-Key gesetzt; `gh auth login` + `gh ssh-key add` noch offen (User) | Login ist nicht automatisierbar |
| 03 Treiber | `ubuntu-drivers install` | übersprungen | Installer hat 595-open schon mitgebracht |
| 04 CUDA | `cuda-toolkit-13-0`, Repo `ubuntu2604` falls vorhanden | `cuda-toolkit-13-2` aus Repo **`ubuntu2404`** | `ubuntu2604`-Repo führt nur 13.3/13.4, beide über dem Treiber-Ceiling 13.2. 13.2 passt exakt zu Treiber und PyTorch-`cu132`-Wheels |
| 05 cuDNN | `cudnn9-cuda-13` | gleich (9.26.0.51) | – |
| 06 venvs | `python3 -m venv` (3.14) | `tfgpu` mit uv-verwaltetem **Python 3.13** (`scripts-4090/06b-tfgpu-py313.sh`), Rest 3.14 | TensorFlow 2.21 hat keine cp314-Wheels; 26.04 liefert apt-seitig nur 3.14 |
| 07 Frameworks | `tensorflow[and-cuda]` | gleich, plus `sitecustomize.py` im tfgpu-venv, das die pip-`nvidia-*-cu12`-Libs vorlädt | TF fand sonst das System-cuDNN (CUDA-13-Build) über ldconfig zuerst → keine GPU. Torch 2.14+cu132 und JAX 0.11 sahen die GPU direkt |
| 09 Docker | `get.docker.com \| sudo sh` | `docker.io` + `docker-compose-v2` aus Ubuntu-Archiv (`scripts-4090/09-docker-apt.sh`) | läuft komplett mit gescoptem sudoers, kein Fremdskript als root |

## Sudoers

`/etc/sudoers.d/rmesterheide-claude` (vom User angelegt), NOPASSWD für:
`apt-get apt dpkg systemctl loginctl ethtool gpg tee usermod nvidia-ctk`.
Reboot via `sudo systemctl reboot`.

## Gotchas

- `gh auth login` (gh 2.46 auf 26.04) kennt `--skip-ssh-key` noch nicht; die Survey-Prompts
  lassen sich per `script -q -f -c ... log` und gepipeten Escape-Sequenzen (`\033[B` = Pfeil runter,
  `\r` = Enter) fernsteuern, der Einmal-Code steht dann im Log.

- `pkill -f <muster>` über SSH killt die eigene SSH-Shell, wenn das Muster
  in deren Kommandozeile vorkommt. Prozesse per `ps`+`awk` filtern.
- Nach dem Repo-Wechsel 2604→2404 blieb `cuda-ubuntu2604-x86_64.list`
  liegen (NO_PUBKEY-Warnung). Ohne `rm` im Sudoers: per `sudo tee ... </dev/null`
  geleert.
- SSH auf 26.04 ist socket-aktiviert (`ssh.socket` enabled, `ssh.service`
  disabled). `systemctl enable ssh` meldet daher einen Fehler, ist aber
  nicht nötig.

## Verifiziert (2026-09-12)

- torch 2.14.0+cu132: `cuda_available=True`, RTX 4090
- tensorflow 2.21.0 (Py 3.13): GPU:0 sichtbar, matmul auf GPU
- jax 0.11.1: `CudaDevice(id=0)`
- Docker: `nvidia/cuda:13.2.0-base` Container sieht die 4090
- JupyterLab user-service aktiv auf 127.0.0.1:8888, Linger an, 7 Kernels registriert

## Remote-Desktop: Sunshine + Moonlight (2026-09-12)

Ziel wie auf der 3090, aber die Umsetzung weicht ab, weil Ubuntu 26.04 nur
noch eine **Wayland**-GNOME-Session hat (keine Xorg-Session mehr) und hier
ein Monitor (Samsung 4K an DP-3) angeschlossen ist:

| Thema | 3090 (`ubnt2080rm`) | 4090rtx |
|---|---|---|
| Session | Xorg, headless mit Modeline-Hack | Wayland, echter Monitor, kein Headless-Teil nötig |
| Capture | NvFBC | **XDG-Portal / PipeWire** (KMS liefert auf nvidia-drm eine leere Monitorliste, wlgrab nur für wlroots) |
| Encoder | h264_nvenc (Sunshine gepinnt auf v2025.924, Treiber 570) | **h264/hevc/av1_vulkan** (Vulkan Video, Hardware). Sunshine 2026.906 braucht NVENC-API 13.1 = Treiber ≥ 610, Box hat 595 → nvenc-Probe scheitert, Vulkan greift |
| Paket | ubuntu-24.04 .deb | natives `ubuntu26.04` .deb, `sudo apt-get install ./deb` |
| Unit | `sunshine.service` | `app-dev.lizardbyte.app.Sunshine.service` (user, graphical-session.target) |

**Blocker, der Zeit gekostet hat:** GNOME verweigert jede Remote-Desktop-Portal-Sitzung,
solange der Bildschirm gesperrt ist. Symptom im Sunshine-Log: `RemoteDesktop CreateSession
failed with response code: 2`, im Portal-Log: `Session creation inhibited`. Sunshine hängt
dann in der Encoder-Probe und öffnet keine Ports. Deshalb: `lock-enabled=false`,
`idle-delay=0` (gsettings) und GDM-Autologin, sonst friert der Stream nach jedem Leerlauf ein.

Vom User selbst gemacht (sudo/Sicherheit): GDM-Autologin, ufw-Regeln (LAN-only, TCP
47984/47989/47990/48010, UDP 47998-48010), Entsperren. Verifiziert: Ports vom Mac
erreichbar, Web-UI auf https://192.168.0.21:47990.

**Session-Auflösung:** Host-Desktop von 3840x2160 (Scale 1,33) auf **1920x1080@60,
Scale 1** umgestellt, wie auf der 3090, damit Moonlight 1:1 bekommt. Unter Wayland
gibt es kein xrandr; per SSH geht es über Mutters DBus-API
(`org.gnome.Mutter.DisplayConfig.ApplyMonitorsConfig`, Methode 2 = persistent,
Connector `DP-3`, Mode-ID `1920x1080@60.000`). Vorsicht: Zsh auf dem Mac globbt
`[0]` in SSH-Befehlen — Skripte per `ssh host 'bash -s' < script.sh` schicken.

**Web-UI vom Mac:** Sunshines CSRF-Schutz erlaubt nur `localhost`. Zugriff über
`https://192.168.0.21:47990` endet sonst in "Internal error" beim Anlegen der
Zugangsdaten (Log: `CSRF protection blocked request from origin`). Fix in
`~/.config/sunshine/sunshine.conf`: `csrf_allowed_origins = https://192.168.0.21:47990,...`

Wenn Vulkan-Encoding im Stream nicht überzeugt: Sunshine auf eine Release vor dem
NVENC-13.1-Sprung pinnen (Technik wie auf der 3090: `.deb` entpacken, Binary standalone
starten, Log lesen) oder auf Treiber ≥ 610 warten.

## Offen

- [x] gh-Login auf der Box (Device-Flow, 2026-09-12 23:5x), Box-SSH-Key als `4090rtx` bei GitHub (vom Mac-gh hochgeladen), `git_protocol ssh`
- [x] `~/rtx4090-dl-workstation` ist jetzt ein echter Clone. Aufräumkandidaten im Home: `~/rtx4090-dl-workstation.rsync-copy`, `~/rtx3090-dl-workstation` (beides alte Kopien), `~/setup-0*.sh`, `~/setup-0*.log`
- [x] Eigenes Repo: [rmesterheide/rtx4090-dl-workstation](https://github.com/rmesterheide/rtx4090-dl-workstation) (privat, 2026-09-12)
- [x] Web-UI-Zugangsdaten gesetzt, Moonlight vom Mac gepairt, Stream läuft (HEVC/Vulkan, 1080p)
- [x] Reboot-Test 2026-09-12 23:31: Autologin in Wayland-Session (nicht gesperrt), Sunshine 1080p + Encoder, JupyterLab, Docker, alle Ports — ohne Eingriff hochgekommen
