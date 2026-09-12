#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d ~/venvs/jupyterhub ]; then
  python3 -m venv ~/venvs/jupyterhub
fi

source ~/venvs/jupyterhub/bin/activate
pip install --upgrade pip -q
pip install jupyterlab jupyterlab-nvdashboard -q
deactivate

for env in ml cv torchgpu tfgpu ultralytics onnxgpu jaxgpu; do
  ~/venvs/"$env"/bin/pip install ipykernel -q
  ~/venvs/"$env"/bin/python -m ipykernel install --user \
    --name "$env" --display-name "Python ($env)"
done

mkdir -p ~/.config/systemd/user
cp "$(dirname "$0")/../systemd/jupyterlab.service" ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now jupyterlab.service
loginctl enable-linger "$USER"

echo
echo "JupyterLab service started, listening on 127.0.0.1:8888."
echo "Get the access token/URL with:"
echo "  ~/venvs/jupyterhub/bin/jupyter server list"
echo "Reach it from another machine via SSH tunnel (see docs/SETUP.md section 10)."
