#!/usr/bin/env bash
# 4090rtx-Abweichung: TensorFlow hat (Stand 2026-09) keine cp314-Wheels,
# Ubuntu 26.04 liefert nur Python 3.14. Das tfgpu-venv bekommt daher ein
# uv-verwaltetes Python 3.13 (kein sudo, kein Eingriff ins System-Python).
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
if [ -d ~/venvs/tfgpu ] && ! ~/venvs/tfgpu/bin/python --version 2>/dev/null | grep -q "3.13"; then
  echo "tfgpu venv ist $(~/venvs/tfgpu/bin/python --version) -> neu anlegen mit 3.13"
  rm -rf ~/venvs/tfgpu
fi
[ -d ~/venvs/tfgpu ] || uv venv --python 3.13 --seed ~/venvs/tfgpu
~/venvs/tfgpu/bin/python --version

# TensorFlow (tensorflow[and-cuda]) zieht nvidia-*-cu12-Wheels. Systemweit liegt
# cuDNN fuer CUDA 13 in ldconfig und wird sonst zuerst gefunden -> "Cannot dlopen
# some GPU libraries", keine GPU. Loesung: pip-Libs beim Interpreter-Start vorladen.
SP=$(~/venvs/tfgpu/bin/python -c 'import sysconfig;print(sysconfig.get_paths()["purelib"])')
cat > "$SP/sitecustomize.py" <<'PY'
# tfgpu venv: pip-CUDA-12-Libs (nvidia-*-cu12) vor den System-CUDA-13-Libs laden.
import ctypes, glob, os
_base = os.path.join(os.path.dirname(__file__), "nvidia")
for _name in ("cuda_runtime", "cublas", "cufft", "curand", "cusolver", "cusparse", "nvjitlink", "cudnn"):
    for _lib in sorted(glob.glob(os.path.join(_base, _name, "lib", "lib*.so*"))):
        try:
            ctypes.CDLL(_lib, mode=ctypes.RTLD_GLOBAL)
        except OSError:
            pass
PY
echo "sitecustomize.py -> $SP (greift nach 07-frameworks.sh, sobald die nvidia-Wheels da sind)"
