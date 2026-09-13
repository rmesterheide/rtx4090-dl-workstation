#!/usr/bin/env bash
# Fuehrt ~/hermes-bench/llm-bench.sh unter "headless"-Bedingungen aus, damit die Zahlen
# mit einer Box ohne Desktop vergleichbar sind:
#   - alle geladenen Ollama-Modelle entladen
#   - Grafikstack komplett runter (systemctl isolate multi-user.target): kein GDM, kein
#     GNOME/Wayland, kein Sunshine -> 0 MiB VRAM ausser Ollama. Der systemd --user-Manager
#     (Ollama als User-Service) ueberlebt dank loginctl enable-linger.
#   - danach graphical.target zurueck: GDM-Autologin und Sunshine kommen von selbst wieder.
#   - OLLAMA_NUM_PARALLEL=1 (User-Unit), torchgpu-venv im PATH fuer die bf16-TFLOPS-Zeile.
# Aufruf per SSH (nicht aus Moonlight, der Stream bricht ab):
#   bash ~/rtx4090-dl-workstation/scripts-4090/10b-run-llm-bench.sh [modelle...]
# Hintergrund: Desktop+Sunshine belegen sonst 0.4-1 GB VRAM, das 64k-Modell rutscht dann
# auf 93 % GPU (gemessen 2026-09-13: 87 vs 118 tok/s). Die 3090 hat im Leerlauf 826 MiB
# (Xorg, xrdp/gnome-remote-desktop, Sunshine) -> dort denselben Wrapper nutzen.
set -uo pipefail
export PATH="$HOME/venvs/torchgpu/bin:$HOME/ollama/bin:$HOME/.local/bin:$PATH"
export LC_ALL=C
OLLAMA_URL=${OLLAMA_HOST:-http://127.0.0.1:11434}

restore() {
  echo "== Grafikstack wieder hochfahren (graphical.target)"
  sudo -n systemctl isolate graphical.target
  sleep 8
  echo "   seat0-Session: $(loginctl list-sessions --no-legend | awk '$4=="seat0"{print $1}' | head -1 || echo keine)"
  echo "   sunshine: $(systemctl --user is-active app-dev.lizardbyte.app.Sunshine.service 2>&1)"
}
trap restore EXIT

echo "== Modelle entladen"
for m in $(curl -s "$OLLAMA_URL/api/ps" | jq -r '.models[].name'); do
  curl -s "$OLLAMA_URL/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null; echo "   $m"
done; sleep 2
echo "== Grafikstack runter (multi-user.target)"
sudo -n systemctl isolate multi-user.target; sleep 6
echo "   gdm: $(systemctl is-active gdm), seat0-Sessions: $(loginctl list-sessions --no-legend | awk '$4=="seat0"' | wc -l), ollama: $(systemctl --user is-active ollama.service 2>&1)"
echo "== VRAM-Basis: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
echo "== Ollama: $(ollama --version | awk '{print $NF}'), $(systemctl --user show ollama.service -p Environment --value)"
START=$(date +%s)
"$HOME/hermes-bench/llm-bench.sh" "$@"; RC=$?
echo "== Dauer: $(( ($(date +%s)-START)/60 )) min, exit $RC"
exit $RC
