#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y git gh

read -rp "Git user.name: " GIT_NAME
read -rp "Git user.email: " GIT_EMAIL
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

if [ ! -f ~/.ssh/id_ed25519 ]; then
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519
fi

echo
echo "Now log in to GitHub (interactive, opens a device-code flow):"
echo "  gh auth login --git-protocol ssh --web"
echo "Then register this machine's key:"
echo "  gh ssh-key add ~/.ssh/id_ed25519.pub --title \"\$(hostname)\""
