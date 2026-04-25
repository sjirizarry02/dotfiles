#!/usr/bin/env bash
set -e
echo "-> Stage 2: GitHub Authentication"

KEY_PATH="$HOME/.ssh/id_ed25519"
KEY_TITLE="$(hostname)-$(date +%Y%m%d)-homelab-bootstrap"

if [ -f "$KEY_PATH" ]; then
    echo "SSH key already exists. Skipping generation."
else
    echo "Generating new SSH key for $(hostname)..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    ssh-keygen -t ed25519 -C "$KEY_TITLE" -f "$KEY_PATH" -N "" -q

    echo "Registering SSH key with GitHub..."
    PUB_KEY=$(cat "${KEY_PATH}.pub")

    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -L -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      https://api.github.com/user/keys \
      -d "{\"title\":\"$KEY_TITLE\",\"key\":\"$PUB_KEY\"}")

    if [ "$HTTP_RESPONSE" -ne 201 ]; then
        echo "Failed to upload SSH key. Check PAT permissions. HTTP Status: $HTTP_RESPONSE"
        exit 1
    fi
    echo "SSH Key successfully added to GitHub."
fi
