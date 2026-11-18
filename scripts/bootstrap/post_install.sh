#!/usr/bin/env bash
set -euo pipefail

env_file=${1:-$CONFIG_DIR/.env}
if [[ -f $env_file ]]; then
    source "$env_file"
fi
NVIM_VERSION=${NVIM_VERSION:-0.12.1}
TREE_SITTER_VERSION=${TREE_SITTER_VERSION:-0.22.6}

if command -v nvim >/dev/null; then
    printf 'Keeping Neovim at %s\n' "$(command -v nvim)"
else
    case $(uname -m) in
        x86_64) artifact=nvim-linux-x86_64 ;;
        aarch64) artifact=nvim-linux-arm64 ;;
        *) printf 'Unsupported Neovim architecture.\n' >&2; exit 1 ;;
    esac

    work=$(mktemp -d)
    stage=
    cleanup() {
        rm -rf -- "$work"
        if [[ -n $stage ]]; then
            sudo rm -rf -- "$stage"
        fi
    }
    trap cleanup EXIT
    curl --fail --silent --show-error --location \
        "https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/$artifact.tar.gz" \
        --output "$work/nvim.tar.gz"
    tar -xzf "$work/nvim.tar.gz" -C "$work"
    "$work/$artifact/bin/nvim" --version >/dev/null
    stage=$(sudo mktemp -d /opt/dotfiles-nvim.XXXXXXXX)
    sudo mv -T -- "$work/$artifact" "$stage/nvim"
    sudo chmod 755 -- "$stage"
    sudo ln -sT -- "$stage/nvim/bin/nvim" /usr/local/bin/nvim
    stage=
    printf 'Installed Neovim %s\n' "$NVIM_VERSION"
fi

read -r _ installed_version _ <<< "$(tree-sitter --version 2>/dev/null || true)"
if [[ $installed_version == "$TREE_SITTER_VERSION" ]]; then
    printf 'Tree-sitter CLI %s is already available.\n' "$TREE_SITTER_VERSION"
else
    sudo npm install -g "tree-sitter-cli@$TREE_SITTER_VERSION"
fi
