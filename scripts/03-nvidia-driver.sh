#!/usr/bin/env bash
set -euo pipefail

sudo apt install -y ubuntu-drivers-common

echo "Detected devices and recommended drivers:"
ubuntu-drivers devices

sudo ubuntu-drivers install

echo
echo "Driver installed. Reboot required:"
echo "  sudo reboot"
echo "After reboot, verify with: nvidia-smi"
