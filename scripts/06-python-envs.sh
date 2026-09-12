#!/usr/bin/env bash
set -euo pipefail

ENVS=(ml cv torchgpu tfgpu ultralytics onnxgpu jaxgpu)

mkdir -p ~/venvs
for env in "${ENVS[@]}"; do
  if [ ! -d ~/venvs/"$env" ]; then
    python3 -m venv ~/venvs/"$env"
    echo "Created venv: ~/venvs/$env"
  else
    echo "Already exists: ~/venvs/$env"
  fi
done
