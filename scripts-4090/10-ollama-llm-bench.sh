#!/usr/bin/env bash
# Step 0/10 of the guide: Ollama + LLM benchmark (tok/s) on a fresh system.
# Runs entirely without root (user service); needs only the NVIDIA driver + jq/zstd via apt.
# Benchmark script: bench/llm-bench.sh from rmesterheide/hermes-on-rtx3090 (identical on 3090 and 4090).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
OLLAMA_VERSION="${OLLAMA_VERSION:-v0.34.0}"     # same version as on the machine you compare against!
BENCH_DIR="$HOME/hermes-bench"

echo "== 1/5 apt: jq zstd"
sudo -n apt-get install -y -qq jq zstd >/dev/null

echo "== 2/5 Ollama $OLLAMA_VERSION into ~/ollama (user level)"
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
Environment=OLLAMA_NUM_PARALLEL=1
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

echo "== 3/5 models (about 58 GB)"
for m in qwen3.6:27b qwen3.6:35b gemma4:31b; do ~/ollama/bin/ollama pull "$m"; done

echo "== 4/5 benchmark script + Modelfile into $BENCH_DIR"
mkdir -p "$BENCH_DIR/results"
if [ ! -f "$BENCH_DIR/llm-bench.sh" ]; then
  echo "   -> copy bench/llm-bench.sh, bench/README.md and ollama/Modelfile from rmesterheide/hermes-on-rtx3090 into $BENCH_DIR"
  echo "      (e.g. gh repo clone, or rsync from the other box)"
fi
if [ -f "$BENCH_DIR/Modelfile.qwen3.6-27b-64k" ]; then
  ~/ollama/bin/ollama create qwen3.6-27b-64k -f "$BENCH_DIR/Modelfile.qwen3.6-27b-64k"
fi

echo "== 5/5 run (about 10 min):"
echo "   bash $(dirname "$0")/10b-run-llm-bench.sh    # shuts the graphics stack down (VRAM!), torch venv on PATH, brings it back afterwards"
echo "   result: $BENCH_DIR/results/<host>-<gpu>-<date>.md  -> into the hermes-on-rtx3090 repo under bench/results/ and docs/benchmarks.md"
