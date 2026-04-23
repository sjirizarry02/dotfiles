#!/usr/bin/env bash
set -e
echo "-> Stage 5: Post-Installation Scripts"

# Neovim  Installation
if ! command -v nvim >/dev/null 2>&1; then
    echo "Installing Neovim (Latest)..."
    curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz -o /tmp/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf /tmp/nvim-linux-x86_64.tar.gz
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    rm -rf /tmp/nvim-linux-x86_64.tar.gz
else
    echo "Neovim already installed, skipping."
fi

# NPM Packages
if command -v npm >/dev/null 2>&1; then
    echo "Installing Tree-Sitter via NPM..."
    sudo npm install -g tree-sitter-cli@0.22.6
fi
