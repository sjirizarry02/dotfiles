#!/usr/bin/env bash
set -e

# Find the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

export DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
export SCRIPTS_DIR="$SCRIPT_DIR"

echo "=== Homelab Environment Bootstrap ==="
echo "Detected dotfiles root at: $DOTFILES_DIR"

# Prompt for Github Token if no provided
if [ -z "$GITHUB_TOKEN" ]; then
	echo -n "Enter your Github Personal Access Token (PAT): "
	read -rs GITHUB_TOKEN
	echo ""
fi
export GITHUB_TOKEN

# Cache Sudo Credentials
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Execute Modules
bash "$SCRIPTS_DIR/bootstrap/system_prep.sh"
bash "$SCRIPTS_DIR/bootstrap/github_auth.sh"
bash "$SCRIPTS_DIR/bootstrap/submodules.sh"
bash "$SCRIPTS_DIR/bootstrap/symlinks.sh"
bash "$SCRIPTS_DIR/bootstrap/post_install.sh"

echo "=== Environment Successfully Initialized"
echo "Run 'source ~/.bashrc' nerd..."
