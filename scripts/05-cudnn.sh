#!/usr/bin/env bash
set -euo pipefail

# Requires the cuda-keyring repo from 04-cuda-toolkit.sh to already be set up.
sudo apt update
sudo apt install -y cudnn9-cuda-13
