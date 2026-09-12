#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

install_and_verify() {
  local env="$1"
  local reqs="environments/${env}.txt"
  echo "=== $env ==="
  source ~/venvs/"$env"/bin/activate
  pip install --upgrade pip -q
  if [ "$env" = "torchgpu" ]; then
    pip install -r "$reqs" --extra-index-url https://download.pytorch.org/whl/cu132 -q
  else
    pip install -r "$reqs" -q
  fi
  deactivate
}

for env in ml cv torchgpu tfgpu ultralytics onnxgpu jaxgpu; do
  install_and_verify "$env"
done

echo
echo "=== Verification ==="

source ~/venvs/torchgpu/bin/activate
python -c "import torch; print('torch', torch.__version__, 'cuda_available=', torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else '')"
deactivate

source ~/venvs/tfgpu/bin/activate
python -c "import tensorflow as tf; print('tensorflow', tf.__version__, tf.config.list_physical_devices('GPU'))"
deactivate

source ~/venvs/jaxgpu/bin/activate
python -c "import jax; print('jax', jax.__version__, jax.devices())"
deactivate
