#!/usr/bin/env bash
set -e

# Function for time and running scripts
run_stage() {
    local stage_name="$1"
    local script_path="$2"
    
    echo "Starting: $stage_name..."
    local start_time=$(date +%s)
    
    bash "$script_path"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "Finished: $stage_name (Took: ${duration}s)"
    echo "----------------------------------------"
}

# Find the directory the script is located in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
export DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
export SCRIPTS_DIR="$SCRIPT_DIR"

# Cache Sudo Credentials
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "=== Homelab Environment Bootstrap ==="
echo "Detected dotfiles root at: $DOTFILES_DIR"

# Prompt for Github Token if no provided
if [ -z "$GITHUB_TOKEN" ]; then
	echo -n "Enter your Github Personal Access Token (PAT): "
	read -rs GITHUB_TOKEN
	echo ""
fi
export GITHUB_TOKEN

STAGE="${1:-all}"
case "$STAGE" in
    prep) run_stage "System Prep" "$SCRIPTS_DIR/bootstrap/system_prep.sh" ;;
    auth) run_stage "GitHub Auth" "$SCRIPTS_DIR/bootstrap/github_auth.sh" ;;
    submodules) run_stage "Submodules" "$SCRIPTS_DIR/bootstrap/submodules.sh" ;;
    symlinks) run_stage "Symlinks" "$SCRIPTS_DIR/bootstrap/symlinks.sh" ;;
    post) run_stage "Post Install" "$SCRIPTS_DIR/bootstrap/post_install.sh" ;;
    all)
        run_stage "System Prep" "$SCRIPTS_DIR/bootstrap/system_prep.sh"
        run_stage "GitHub Auth" "$SCRIPTS_DIR/bootstrap/github_auth.sh"
        run_stage "Submodules" "$SCRIPTS_DIR/bootstrap/submodules.sh"
        run_stage "Symlinks" "$SCRIPTS_DIR/bootstrap/symlinks.sh"
        run_stage "Post Install" "$SCRIPTS_DIR/bootstrap/post_install.sh"

        echo "=== Environment Successfully Initialized ==="
        echo "Run 'source ~/.bashrc' nerd..."
        ;;
    *)
        echo "Error: Unknown stage '$STAGE'."
        echo "Valid stages: prep, auth, submodules, symlinks, post, all"
        exit 1
        ;;
esac

echo "=== Operation Complete ==="
