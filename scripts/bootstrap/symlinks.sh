#!/usr/bin/env bash
set -e
echo "-> Stage 4: Symlinking Configurations"

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
link_file "$DOTFILES_DIR/bash/.bashrc" "$HOME/.bashrc"
link_file "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"

# 2. .config files
# link_file "$DOTFILES_DIR/tmux" "$CONFIG_DIR/tmux"
# link_file "$DOTFILES_DIR/.config/i3" "$CONFIG_DIR/i3"
link_file "$DOTFILES_DIR/.config/hypr" "$CONFIG_DIR/hypr"
link_file "$DOTFILES_DIR/.config/kitty" "$CONFIG_DIR/kitty"
link_file "$DOTFILES_DIR/.config/pipewire" "$CONFIG_DIR/pipewire"

# 3. Secrets
mkdir -p "$HOME/.ssh"
if [ -f "$DOTFILES_DIR/dotfiles-secrets/ssh/config" ]; then
    link_file "$DOTFILES_DIR/dotfiles-secrets/ssh/config" "$HOME/.ssh/config"
fi

# 4. Neovim Submodule
link_file "$DOTFILES_DIR/starter.nvim" "$CONFIG_DIR/nvim"
