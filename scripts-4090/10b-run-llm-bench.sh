#!/usr/bin/env bash
# Runs ~/hermes-bench/llm-bench.sh under "headless" conditions so the numbers are
# comparable with a box that has no desktop:
#   - unload all loaded Ollama models
#   - shut the graphics stack down completely (systemctl isolate multi-user.target): no GDM,
#     no GNOME/Wayland, no Sunshine -> 0 MiB VRAM apart from Ollama. The systemd --user manager
#     (Ollama as a user service) survives thanks to loginctl enable-linger.
#   - afterwards back to graphical.target: GDM autologin and Sunshine return on their own.
#   - OLLAMA_NUM_PARALLEL=1 (user unit), torchgpu venv on PATH for the bf16 TFLOPS line.
# Run over SSH (not from inside Moonlight, the stream drops):
#   bash ~/rtx4090-dl-workstation/scripts-4090/10b-run-llm-bench.sh [models...]
# Background: desktop + Sunshine otherwise hold 0.4-1 GB of VRAM and the 64k model slips to
# 93 % GPU (measured 2026-09-13: 87 vs 118 tok/s). The 3090 idles at 826 MiB (Xorg,
# gnome-remote-desktop, Sunshine) -> use the same wrapper there (hermes repo bench/run-headless.sh).
set -uo pipefail
export PATH="$HOME/venvs/torchgpu/bin:$HOME/ollama/bin:$HOME/.local/bin:$PATH"
export LC_ALL=C
OLLAMA_URL=${OLLAMA_HOST:-http://127.0.0.1:11434}

restore() {
  echo "== bringing the graphics stack back (graphical.target)"
  sudo -n systemctl isolate graphical.target
  sleep 8
  echo "   seat0 session: $(loginctl list-sessions --no-legend | awk '$4=="seat0"{print $1}' | head -1 || echo none)"
  echo "   sunshine: $(systemctl --user is-active app-dev.lizardbyte.app.Sunshine.service 2>&1)"
}
trap restore EXIT

echo "== unloading models"
for m in $(curl -s "$OLLAMA_URL/api/ps" | jq -r '.models[].name'); do
  curl -s "$OLLAMA_URL/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null; echo "   $m"
done; sleep 2
echo "== graphics stack down (multi-user.target)"
sudo -n systemctl isolate multi-user.target; sleep 6
echo "   gdm: $(systemctl is-active gdm), seat0 sessions: $(loginctl list-sessions --no-legend | awk '$4=="seat0"' | wc -l), ollama: $(systemctl --user is-active ollama.service 2>&1)"
echo "== VRAM baseline: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
echo "== Ollama: $(ollama --version | awk '{print $NF}'), $(systemctl --user show ollama.service -p Environment --value)"
START=$(date +%s)
"$HOME/hermes-bench/llm-bench.sh" "$@"; RC=$?
echo "== duration: $(( ($(date +%s)-START)/60 )) min, exit $RC"
exit $RC
