#!/usr/bin/env bash
# 4090rtx deviation: TensorFlow has no cp314 wheels (as of 2026-09) and
# Ubuntu 26.04 only ships Python 3.14. The tfgpu venv therefore gets a
# uv-managed Python 3.13 (no sudo, no changes to the system Python).
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
if [ -d ~/venvs/tfgpu ] && ! ~/venvs/tfgpu/bin/python --version 2>/dev/null | grep -q "3.13"; then
  echo "tfgpu venv is $(~/venvs/tfgpu/bin/python --version) -> recreating with 3.13"
  rm -rf ~/venvs/tfgpu
fi
[ -d ~/venvs/tfgpu ] || uv venv --python 3.13 --seed ~/venvs/tfgpu
~/venvs/tfgpu/bin/python --version

# TensorFlow (tensorflow[and-cuda]) pulls nvidia-*-cu12 wheels. The system-wide
# cuDNN for CUDA 13 is in ldconfig and gets found first -> "Cannot dlopen some
# GPU libraries", no GPU. Fix: preload the pip libs at interpreter start.
SP=$(~/venvs/tfgpu/bin/python -c 'import sysconfig;print(sysconfig.get_paths()["purelib"])')
cat > "$SP/sitecustomize.py" <<'PY'
# tfgpu venv: load the pip CUDA 12 libs (nvidia-*-cu12) ahead of the system CUDA 13 libs.
import ctypes, glob, os
_base = os.path.join(os.path.dirname(__file__), "nvidia")
for _name in ("cuda_runtime", "cublas", "cufft", "curand", "cusolver", "cusparse", "nvjitlink", "cudnn"):
    for _lib in sorted(glob.glob(os.path.join(_base, _name, "lib", "lib*.so*"))):
        try:
            ctypes.CDLL(_lib, mode=ctypes.RTLD_GLOBAL)
        except OSError:
            pass
PY
echo "sitecustomize.py -> $SP (takes effect after 07-frameworks.sh, once the nvidia wheels are installed)"
