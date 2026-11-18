#!/usr/bin/env bash
set -euo pipefail

cd "$DOTFILES_DIR"
key="$HOME/.ssh/id_ed25519"
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-$(git config --get core.sshCommand || printf ssh)}"
GIT_SSH_COMMAND+=' -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new'
export GIT_TERMINAL_PROMPT=0
git submodule init -- "$@"

check_access() {
    local module url output
    for module in "$@"; do
        url=$(git config --local --get "submodule.$module.url") || return 2
        # Use SSH for HTTPS clones of either supported host.
        case $url in
            https://github.com/*) url="git@github.com:${url#https://github.com/}" ;;
            https://gitlab.com/*) url="git@gitlab.com:${url#https://gitlab.com/}" ;;
        esac
        if output=$(git ls-remote "$url" HEAD 2>&1); then
            continue
        fi
        printf '%s\n' "$output" >&2
        if [[ ( $url == git@github.com:* || $url == ssh://git@github.com/* ) && $output == *'Permission denied (publickey)'* ]]; then
            return 1
        fi
        return 2
    done
}

printf 'Checking SSH access to %s...\n' "$*"
if check_access "$@"; then
    exit 0
else
    status=$?
    if (( status != 1 )); then
        printf 'Resolve the repository access error and retry.\n' >&2
        exit "$status"
    fi
fi

token=${GITHUB_TOKEN:-}
if [[ -z $token ]]; then
    cat <<'HELP'
GitHub SSH authentication failed. To register the local public key, create a
short-lived token in GitHub Settings > Developer settings > Personal access tokens.

  Fine-grained (recommended): https://github.com/settings/personal-access-tokens/new?keys=write
    Choose your personal account as Resource owner and Public repositories
    for repository access. Under Account permissions, set Git SSH keys to
    Read and write. Leave other permissions at their defaults.

  Tokens (classic): https://github.com/settings/tokens/new?scopes=write:public_key
    Select write:public_key under admin:public_key. This includes read access.
    Leave other scopes unchecked, including repo.

Paste the generated token below. Input is hidden.
HELP
    printf 'GitHub PAT for SSH key registration [b Back, q Quit]: '
    IFS= read -rs token || exit 1
    printf '\n'
    case $token in
        b) exit 125 ;;
        q) exit 130 ;;
        '') exit 1 ;;
    esac
fi
if [[ ! $token =~ ^[[:alnum:]_]+$ ]]; then
    printf 'Invalid GitHub token format.\n' >&2
    exit 1
fi

for command in curl jq ssh-keygen; do
    if ! command -v "$command" >/dev/null; then
        printf 'SSH key registration requires %s. Run system prep and retry.\n' "$command" >&2
        exit 1
    fi
done

title="dotfiles-bootstrap-$(date +%Y%m%d)"
if [[ ! -f $key ]]; then
    install -d -m 700 -- "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$title" -f "$key" -N '' -q
fi
if [[ ! -f $key.pub ]]; then
    ssh-keygen -y -f "$key" > "$key.pub"
fi

# Keep the token out of command-line arguments and compare the key on reruns.
api=https://api.github.com/user/keys
github_api() {
    printf 'Authorization: Bearer %s\n' "$token" |
        curl --silent --show-error --fail-with-body --header @- \
            --header 'Accept: application/vnd.github+json' "$@"
}
public_key=$(cut -d ' ' -f1,2 -- "$key.pub")
page=1
while true; do
    response=$(github_api "$api?per_page=100&page=$page")
    if jq -e --arg key "$public_key" 'any(.[]; (.key | split(" ") | .[0:2] | join(" ")) == $key)' <<< "$response" >/dev/null; then
        break
    fi
    if [[ $(jq 'length' <<< "$response") -lt 100 ]]; then
        payload=$(jq -n --arg title "$title" --arg key "$public_key" '{title:$title,key:$key}')
        github_api --header 'Content-Type: application/json' --data "$payload" "$api" >/dev/null
        break
    fi
    page=$((page + 1))
done
unset token GITHUB_TOKEN
check_access "$@"
