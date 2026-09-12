#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y \
  build-essential pkg-config cmake ninja-build \
  python3 python3-venv python3-pip python3-dev \
  curl wget unzip
