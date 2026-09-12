#!/usr/bin/env bash
# Schritt 0/10 des Guides: Ollama + LLM-Benchmark (tok/s) auf einem frischen System.
# Laeuft komplett ohne root (User-Service), braucht nur den NVIDIA-Treiber + jq/zstd via apt.
# Benchmark-Skript: bench/llm-bench.sh aus rmesterheide/hermes-on-rtx3090 (identisch auf 3090 und 4090).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
OLLAMA_VERSION="${OLLAMA_VERSION:-v0.34.0}"     # gleiche Version wie auf der Vergleichsmaschine!
BENCH_DIR="$HOME/hermes-bench"

echo "== 1/5 apt: jq zstd"
sudo -n apt-get install -y -qq jq zstd >/dev/null

echo "== 2/5 Ollama $OLLAMA_VERSION nach ~/ollama (User-Level)"
mkdir -p ~/ollama ~/.local/bin ~/.config/systemd/user
if [ ! -x ~/ollama/bin/ollama ]; then
  curl -fsSL "https://github.com/ollama/ollama/releases/download/$OLLAMA_VERSION/ollama-linux-amd64.tar.zst" | tar --zstd -xf - -C ~/ollama
fi
ln -sf ~/ollama/bin/ollama ~/.local/bin/ollama
cat > ~/.config/systemd/user/ollama.service <<'UNIT'
[Unit]
Description=Ollama (user service)
After=network-online.target

[Service]
ExecStart=%h/ollama/bin/ollama serve
Environment=OLLAMA_NUM_PARALLEL=4
Environment=OLLAMA_HOST=127.0.0.1:11434
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now ollama.service
loginctl enable-linger "$USER" >/dev/null 2>&1 || true
sleep 4; ~/ollama/bin/ollama --version

echo "== 3/5 Modelle (ca. 58 GB)"
for m in qwen3.6:27b qwen3.6:35b gemma4:31b; do ~/ollama/bin/ollama pull "$m"; done

echo "== 4/5 Benchmark-Skript + Modelfile nach $BENCH_DIR"
mkdir -p "$BENCH_DIR/results"
if [ ! -f "$BENCH_DIR/llm-bench.sh" ]; then
  echo "   -> bench/llm-bench.sh, bench/README.md und ollama/Modelfile aus rmesterheide/hermes-on-rtx3090 nach $BENCH_DIR kopieren"
  echo "      (privates Repo; z.B. per gh repo clone oder rsync von der anderen Box)"
fi
if [ -f "$BENCH_DIR/Modelfile.qwen3.6-27b-64k" ]; then
  ~/ollama/bin/ollama create qwen3.6-27b-64k -f "$BENCH_DIR/Modelfile.qwen3.6-27b-64k"
fi

echo "== 5/5 Lauf (ca. 10 min):"
echo "   PATH=\$HOME/venvs/torchgpu/bin:\$PATH $BENCH_DIR/llm-bench.sh    # torch-venv vorne, damit die bf16-TFLOPS-Zeile nicht leer bleibt"
echo "   Ergebnis: $BENCH_DIR/results/<host>-<gpu>-<datum>.md  -> ins hermes-on-rtx3090-Repo unter bench/results/ und docs/benchmarks.md"
