#!/usr/bin/env bash

detect_platform() {
    local ID= ID_LIKE= PRETTY_NAME=
    if [[ -r /etc/os-release ]]; then
        source /etc/os-release
    fi
    platform=${PRETTY_NAME:-unknown}
    architecture=$(uname -m)
    package_manager=
    case " $ID $ID_LIKE " in
        *' debian '*|*' ubuntu '*) package_manager=apt ;;
        *' fedora '*|*' rhel '*|*' centos '*) package_manager=dnf ;;
        *' arch '*) package_manager=pacman ;;
    esac
}

package_installed() {
    case $package_manager in
        apt) [[ $(dpkg-query -W -f='${Status}' -- "$1" 2>/dev/null) == 'install ok installed' ]] ;;
        dnf) rpm -q -- "$1" >/dev/null 2>&1 ;;
        pacman) pacman -Q -- "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

package_available() {
    case $package_manager in
        apt) apt-cache show -- "$1" >/dev/null 2>&1 ;;
        dnf) [[ -n $(dnf -q repoquery --available --queryformat '%{name}' "$1") ]] ;;
        pacman) pacman -Si -- "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

resolve_packages() {
    local -a requested=() base=() editor=() audio=() optional=()
    local package
    declare -A queued=()
    case $package_manager in
        apt)
            base=(make gcc g++ ripgrep fd-find unzip git openssh-client curl jq python3 python3-pip dnsutils procps tmux htop wget tar)
            editor=(make gcc g++ ripgrep fd-find unzip git curl tar nodejs npm)
            audio=(pipewire pipewire-pulse wireplumber)
            ;;
        dnf)
            base=(make gcc gcc-c++ ripgrep fd-find unzip git openssh-clients curl jq python3 python3-pip bind-utils procps-ng tmux htop wget tar)
            editor=(make gcc gcc-c++ ripgrep fd-find unzip git curl tar nodejs npm)
            audio=(pipewire pipewire-pulseaudio wireplumber)
            ;;
        pacman)
            base=(make gcc ripgrep fd unzip git openssh curl jq python python-pip bind procps-ng tmux htop wget tar)
            editor=(make gcc ripgrep fd unzip git curl tar nodejs npm)
            audio=(pipewire pipewire-pulse wireplumber)
            ;;
    esac
    if [[ ${selected[base]}${selected[editor]}${selected[hypr]}${selected[audio]} == 0000 ]]; then
        return
    fi
    if [[ -z $package_manager ]] || ! command -v "$package_manager" >/dev/null; then
        errors+=("Package setup is unsupported on $platform.")
        return
    fi
    [[ ${selected[base]} == 0 ]] || requested+=("${base[@]}")
    [[ ${selected[editor]} == 0 ]] || requested+=("${editor[@]}")
    [[ ${selected[hypr]} == 0 ]] || optional+=(hyprland hyprpaper hypridle hyprlock waybar foot wofi mako wl-clipboard cliphist grim slurp brightnessctl playerctl wireplumber)
    [[ ${selected[audio]} == 0 ]] || optional+=("${audio[@]}")
    for package in "${optional[@]}"; do
        if ! package_installed "$package" && ! package_available "$package"; then
            errors+=("$package is unavailable in the current package metadata for $platform.")
        fi
    done
    for package in "${requested[@]}" "${optional[@]}"; do
        if [[ -z ${queued[$package]+x} ]] && ! package_installed "$package"; then
            packages+=("$package")
            queued[$package]=1
        fi
    done
}

install_packages() {
    if (( ${#packages[@]} == 0 )); then
        return
    fi
    case $package_manager in
        apt)
            sudo apt-get update || return
            sudo apt-get install -y -- "${packages[@]}"
            ;;
        dnf) sudo dnf install -y -- "${packages[@]}" ;;
        pacman) sudo pacman -Syu --needed --noconfirm -- "${packages[@]}" ;;
    esac
}
