#!/usr/bin/env bash
set -euo pipefail

cd "$DOTFILES_DIR"
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-$(git config --get core.sshCommand || printf ssh)}"
GIT_SSH_COMMAND+=' -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new'
export GIT_TERMINAL_PROMPT=0
printf 'Syncing recorded revisions for %s...\n' "$*"
git -c url.git@github.com:.insteadOf=https://github.com/ \
    -c url.git@gitlab.com:.insteadOf=https://gitlab.com/ \
    submodule update --init --recursive -- "$@"

for module in "$@"; do
    if [[ $module == dotfiles-secrets && -d $DOTFILES_DIR/dotfiles-secrets/ssh ]]; then
        find "$DOTFILES_DIR/dotfiles-secrets/ssh" -type f ! -name '*.pub' -exec chmod 600 -- {} +
        if [[ -f $DOTFILES_DIR/dotfiles-secrets/.env ]]; then
            chmod 600 -- "$DOTFILES_DIR/dotfiles-secrets/.env"
        fi
    fi
done
