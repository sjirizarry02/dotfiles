#!/usr/bin/env bash
set -e
echo "-> Stage 3: Syncing Submodules"

cd "$HOME/repos/dotfiles"

# Switches main repo to SSH
git remote set-url origin git@github.com:sjirizarry02/dotfiles.git

# Initialize and update submodules
GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" git submodule update --init --recursive

# Secure the vault files now that they have been downloaded
echo "Securing permissions on secrets vault..."
if [ -d "$DOTFILES_DIR/dotfiles-secrets/ssh" ]; then
    # Secure the SSH config file
    chmod 600 "$DOTFILES_DIR/dotfiles-secrets/ssh/config" 2>/dev/null || true
    find "$DOTFILES_DIR/dotfiles-secrets/ssh" -type f ! -name "*.pub" ! -name "config" -exec chmod 600 {} \; 2>/dev/null || true
fi
