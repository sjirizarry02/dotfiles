#!/usr/bin/env bash
set -euo pipefail

sources=()
destinations=()
add_link() {
    sources+=("$1")
    destinations+=("$2")
}

for group in "$@"; do
    case $group in
        shell)
            add_link "$DOTFILES_DIR/bash/.bashrc" "$HOME/.bashrc"
            add_link "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
            ;;
        private)
            private="$DOTFILES_DIR/dotfiles-secrets"
            if [[ -f $private/git/.gitconfig ]]; then
                chmod 600 -- "$private/git/.gitconfig"
                add_link "$private/git/.gitconfig" "$HOME/.gitconfig-private"
            fi
            if [[ -f $private/ssh/config ]]; then
                chmod 600 -- "$private/ssh/config"
                add_link "$private/ssh/config" "$HOME/.ssh/config"
            fi
            if [[ -f $private/.env ]]; then
                chmod 600 -- "$private/.env"
                add_link "$private/.env" "$CONFIG_DIR/.env"
            fi
            ;;
        editor) add_link "$DOTFILES_DIR/starter.nvim" "$CONFIG_DIR/nvim" ;;
        hypr)
            add_link "$DOTFILES_DIR/.config/hypr" "$CONFIG_DIR/hypr"
            add_link "$DOTFILES_DIR/.config/waybar" "$CONFIG_DIR/waybar"
            ;;
        audio) add_link "$DOTFILES_DIR/.config/pipewire" "$CONFIG_DIR/pipewire" ;;
    esac
done

for src in "${sources[@]}"; do
    if [[ ! -e $src ]]; then
        printf 'Missing config source: %s\n' "$src" >&2
        exit 1
    fi
done

backup_dir=
for i in "${!sources[@]}"; do
    src=${sources[i]} dest=${destinations[i]}
    if [[ -L $dest && $(readlink -- "$dest") == "$src" ]]; then
        printf 'Already linked %s\n' "$dest"
        continue
    fi

    if [[ ${dest%/*} == "$HOME/.ssh" ]]; then
        install -d -m 700 -- "$HOME/.ssh"
    else
        mkdir -p -- "${dest%/*}"
    fi
    backup=
    if [[ -e $dest || -L $dest ]]; then
        if [[ -z $backup_dir ]]; then
            mkdir -p -- "$HOME/backups"
            backup_dir=$(mktemp -d "$HOME/backups/$(date +%Y%m%d_%H%M%S).XXXXXXXX")
        fi
        backup="$backup_dir/${dest##*/}.bak"
        mv -T -- "$dest" "$backup"
        printf 'Backed up %s to %s\n' "$dest" "$backup"
    fi
    if ! ln -sT -- "$src" "$dest"; then
        if [[ -n $backup && ! -e $dest && ! -L $dest ]]; then
            mv -T -- "$backup" "$dest"
        fi
        exit 1
    fi
    printf 'Linked %s -> %s\n' "$dest" "$src"
done
