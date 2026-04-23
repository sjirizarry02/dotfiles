#!/usr/bin/env bash
set -e
echo "-> Stage 4: Symlinking Configurations"

DOTFILES="$HOME/repos/dotfiles"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/backups/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$CONFIG_DIR"
mkdir -p "$BACKUP_DIR"

# Helper function to backup and link
link_file() {
    local src=$1
    local dest=$2

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "$BACKUP_DIR/$(basename "$dest").bak"
        echo "Backed up $dest"
    fi
    ln -sfn "$src" "$dest"
}

# 1. System dot files
link_file "$DOTFILES/bash/.bashrc" "$HOME/.bashrc"
link_file "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"

# 2. .config files
# link_file "$DOTFILES/tmux" "$CONFIG_DIR/tmux"
# link_file "$DOTFILES/.config/i3" "$CONFIG_DIR/i3"
link_file "$DOTFILES/.config/hypr" "$CONFIG_DIR/hypr"

# 3. Secrets
mkdir -p "$HOME/.ssh"
if [ -f "$DOTFILES/dotfiles-secrets/ssh/config" ]; then
    link_file "$DOTFILES/dotfiles-secrets/ssh/config" "$HOME/.ssh/config"
fi

# 4. Neovim Submodule
link_file "$DOTFILES/starter.nvim" "$CONFIG_DIR/nvim"
