#!/usr/bin/env bash
# Fuehrt ~/hermes-bench/llm-bench.sh auf 4090rtx unter fairen Bedingungen aus:
# - Remote-Desktop-Dienste (Sunshine, gnome-remote-desktop/RDP) werden fuer die Dauer gestoppt,
#   weil ihre ~500 MiB VRAM sonst das 64k-Kontext-Modell teilweise in den RAM draengen
#   (gemessen 2026-09-13: 93% GPU / 87 tok/s mit Diensten, 100% GPU / 118 tok/s ohne).
# - OLLAMA_NUM_PARALLEL=1 wie auf der 3090 (steht in der User-Unit).
# - torchgpu-venv vorne im PATH, damit die bf16-TFLOPS-Zeile gefuellt wird.
# Aufruf per SSH (nicht aus Moonlight heraus, der Stream bricht ab): bash ~/rtx4090-dl-workstation/scripts-4090/10b-run-llm-bench.sh
set -uo pipefail
SVCS="app-dev.lizardbyte.app.Sunshine.service gnome-remote-desktop.service"
export PATH="$HOME/venvs/torchgpu/bin:$HOME/ollama/bin:$PATH"
export LC_ALL=C
echo "== stoppe Remote-Desktop-Dienste: $SVCS"
systemctl --user stop $SVCS; sleep 2
echo "== VRAM-Basis: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"
echo "== Ollama: $(ollama --version | awk '{print $NF}'), $(systemctl --user show ollama.service -p Environment --value)"
START=$(date +%s)
"$HOME/hermes-bench/llm-bench.sh" "$@"; RC=$?
echo "== Dauer: $(( ($(date +%s)-START)/60 )) min, exit $RC"
echo "== starte Remote-Desktop-Dienste wieder"
systemctl --user start $SVCS
exit $RC
