#!/usr/bin/env bash
set -e
echo "-> Stage 1: System Preparation & Packages"

if [ -f /etc/debian_version ]; then
    echo "Detected Debian/Ubuntu..."
    sudo apt update
    sudo apt install -y curl jq
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    if grep -q 'ID=debian' /etc/os-release; then
        echo "deb http://deb.debian.org/debian bookworm-backports main" | sudo tee /etc/apt/sources.list.d/backports.list
    fi
    sudo apt update
    sudo apt install -y make gcc g++ ripgrep fd-find unzip git xclip nodejs python3-full python3-pip dnsutils procps tmux htop wget tar

elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
    echo "Detected RHEL/Fedora..."
    sudo dnf update -y
    sudo dnf install -y curl jq
    curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo -E bash -
    sudo dnf install -y make gcc gcc-c++ ripgrep fd-find unzip git xclip nodejs python3 python3-pip bind-utils procps-ng tmux htop wget tar

elif [ -f /etc/arch-release ]; then
    echo "Detected Arch Linux..."
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm make gcc ripgrep fd unzip git xclip curl jq nodejs npm python python-pip bind procps-ng tmux htop wget tar
fi
