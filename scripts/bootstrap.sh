#!/usr/bin/env bash
set -euo pipefail

export SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR="$(dirname -- "$SCRIPTS_DIR")"
export CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
source "$SCRIPTS_DIR/bootstrap/system_prep.sh"

usage() {
    cat <<'HELP'
Usage: scripts/bootstrap.sh [all|prep|auth|submodules|symlinks|post|--help]

  all         Base tools, private configs, Neovim, and optional app groups
  prep        Install base packages
  auth        Verify or set up GitHub SSH access
  submodules  Verify access and check out recorded submodule revisions
  symlinks    Link Bash, Git, and checked-out private/editor configs
  post        Keep or install Neovim and install editor dependencies

With no arguments, open the main menu. Stages require an interactive terminal
and explicit approval. Use arrows or h/j/k/l to navigate, Enter to select,
and q to quit. App groups start unchecked. Full bootstrap always syncs and
applies dotfiles-secrets.
HELP
}

heading() {
    printf '\n------------------------------------------------------------\n %s\n------------------------------------------------------------\n' "$1"
}

screen_heading() {
    printf '\e[H\e[2J'
    heading "$1"
}

# Only the key read uses raw input. Restore terminal settings before running actions.
read_key() {
    local key tail=
    if ! IFS= read -rsn1 key; then
        exit 0
    fi
    if [[ $key == $'\e' ]]; then
        IFS= read -rsn2 -t 0.3 tail || true
        case $tail in
            '[A'|'OA') key=k ;;
            '[B'|'OB') key=j ;;
            '[C'|'OC') key=l ;;
            '[D'|'OD') key=h ;;
        esac
    fi
    KEY=$key
}

menu() {
    local title=$1 cursor=$2
    shift 2
    local -a rows=("$@")
    local index height=0 width=0 start=0 limit line hint redraw=0
    read -r height width < <(stty size) || true
    (( height > 8 )) || height=24
    (( width > 1 )) || width=80
    limit=$(( height - 8 ))
    hint='↑/k ↓/j Move · Enter/l Select · q Quit'
    if [[ $title != 'DOTFILES BOOTSTRAP' ]]; then
        hint+=' · h/b Back'
    fi
    while true; do
        if (( redraw )); then
            printf '\e[%sF\e[J' "$MENU_LINES"
        fi
        if (( cursor < start )); then start=$cursor; fi
        if (( cursor >= start + limit )); then start=$((cursor - limit + 1)); fi
        case $title in
            'DOTFILES BOOTSTRAP'|'BASE SETUP'|'SELECT APPS AND PACKAGES') screen_heading "$title" ;;
            *) heading "$title" ;;
        esac
        for (( index=start; index < ${#rows[@]} && index < start + limit; index++ )); do
            if (( index == cursor )); then
                line="  > ${rows[index]}"
            else
                line="    ${rows[index]}"
            fi
            printf '%.*s\n' "$((width - 1))" "$line"
        done
        printf '\n%.*s\n' "$((width - 1))" "$hint"
        MENU_LINES=$((index - start + 6))
        redraw=1
        read_key
        case $KEY in
            k) cursor=$(( (cursor + ${#rows[@]} - 1) % ${#rows[@]} )) ;;
            j) cursor=$(( (cursor + 1) % ${#rows[@]} )) ;;
            h|b) MENU_INDEX=-1; return ;;
            q) exit 0 ;;
            ''|l) MENU_INDEX=$cursor; return ;;
        esac
    done
}

toggle_menu() {
    local title=$1
    shift
    local -a names=("$@") rows
    local name cursor=0 count=${#names[@]}
    while true; do
        rows=()
        for name in "${names[@]}"; do
            if [[ ${selected[$name]} == 1 ]]; then
                rows+=("[x] ${labels[$name]}")
            else
                rows+=("[ ] ${labels[$name]}")
            fi
        done
        menu "$title" "$cursor" "${rows[@]}" Continue Back Quit
        case $MENU_INDEX in
            -1|$((count + 1))) return 1 ;;
            "$count") return 0 ;;
            $((count + 2))) exit 0 ;;
            *)
                cursor=$MENU_INDEX
                name=${names[cursor]}
                selected[$name]=$((1 - selected[$name]))
                ;;
        esac
    done
}

prompt() {
    local answer
    while true; do
        printf '%s [y/N]  [b] Back  [q] Quit: ' "$1"
        IFS= read -r answer || exit 0
        case ${answer,,} in
            y|yes) REPLY=yes; return ;;
            ''|n|no) REPLY=no; return ;;
            b|h) REPLY=back; return ;;
            q) exit 0 ;;
        esac
    done
}

declare -A selected labels=(
    [base]='Install base packages'
    [shell]='Link Bash and Git configs'
    [editor]='Set up Neovim and link its config'
    [hypr]='Hyprland Desktop (Hyprland, Hyprpaper, Hypridle, Hyprlock, Waybar, Foot)'
    [audio]='PipeWire Audio (PipeWire, WirePlumber, and repository audio overrides)'
)
stages=(all prep auth submodules symlinks post)

show_editor() {
    if command -v nvim >/dev/null; then
        local version
        version=$(nvim --version 2>/dev/null) || version='version unknown'
        printf '  Keep Neovim at %s (%s)\n' "$(command -v nvim)" "${version%%$'\n'*}"
    else
        printf '  Install Neovim if selected\n'
    fi
}

build_plan() {
    packages=()
    modules=()
    configs=()
    errors=()
    needs_auth=0
    if [[ $stage == all ]]; then
        modules+=(dotfiles-secrets)
        configs+=(private)
    fi
    case $stage in
        auth|submodules) modules=(dotfiles-secrets starter.nvim) ;;
        symlinks)
            [[ ! -f $DOTFILES_DIR/dotfiles-secrets/ssh/config && ! -f $DOTFILES_DIR/dotfiles-secrets/.env && ! -f $DOTFILES_DIR/dotfiles-secrets/git/.gitconfig ]] || configs+=(private)
            [[ ! -f $DOTFILES_DIR/starter.nvim/init.lua ]] || configs+=(editor)
            ;;
    esac
    [[ ${selected[shell]} == 0 ]] || configs+=(shell)
    if [[ ${selected[editor]} == 1 && $stage == all ]]; then
        modules+=(starter.nvim)
        configs+=(editor)
    fi
    [[ ${selected[hypr]} == 0 ]] || configs+=(hypr)
    [[ ${selected[audio]} == 0 ]] || configs+=(audio)
    (( ${#modules[@]} == 0 )) || needs_auth=1

    resolve_packages
    if [[ ${selected[editor]} == 1 ]] && ! command -v nvim >/dev/null; then
        case $architecture in
            x86_64|aarch64) ;;
            *) errors+=("No Neovim archive is configured for $architecture.") ;;
        esac
    fi
    if [[ ${selected[shell]} == 1 ]]; then
        [[ -f $DOTFILES_DIR/bash/.bashrc && -f $DOTFILES_DIR/git/.gitconfig ]] ||
            errors+=("The Bash or Git config is missing from the repository.")
    fi
    if [[ ${selected[hypr]} == 1 ]]; then
        [[ -d $DOTFILES_DIR/.config/hypr && -d $DOTFILES_DIR/.config/waybar ]] ||
            errors+=("The Hyprland or Waybar config is missing from the repository.")
    fi
    if [[ ${selected[audio]} == 1 && ! -d $DOTFILES_DIR/.config/pipewire ]]; then
        errors+=("The PipeWire config is missing from the repository.")
    fi
}

preview() {
    screen_heading "REVIEW ${stage^^}"
    printf '  Detected: %s · %s\n' "$platform" "$architecture"
    if (( ${#packages[@]} )); then
        printf '  Packages: %s\n' "${packages[*]}"
        [[ $package_manager != pacman ]] || printf '  Arch refreshes and upgrades the system when installing missing packages.\n'
    fi
    if [[ ${selected[editor]} == 1 ]]; then
        show_editor
        printf '  Install the pinned Tree-sitter CLI if needed.\n'
    fi
    if (( needs_auth )); then
        printf '  Verify repository access for: %s\n' "${modules[*]}"
        [[ $stage == auth ]] || printf '  Sync the submodules to their recorded commits.\n'
        printf '  A GitHub token is requested only if key registration is needed.\n'
    fi
    local group
    for group in "${configs[@]}"; do
        case $group in
            shell) printf '  Link %s\n' "$HOME/.bashrc" "$HOME/.gitconfig" ;;
            editor) printf '  Link %s\n' "$CONFIG_DIR/nvim" ;;
            private) printf '  Link private Git, SSH, and environment configs present in dotfiles-secrets.\n' ;;
            hypr) printf '  Link %s\n' "$CONFIG_DIR/hypr" "$CONFIG_DIR/waybar" ;;
            audio) printf '  Link %s\n' "$CONFIG_DIR/pipewire" ;;
        esac
    done
    for group in hypr waybar pipewire kitty; do
        case "$group:${selected[hypr]}:${selected[audio]}" in
            hypr:1:*|waybar:1:*|pipewire:*:1) continue ;;
        esac
        if [[ -L $CONFIG_DIR/$group && $(readlink -- "$CONFIG_DIR/$group") == "$DOTFILES_DIR/.config/$group" ]]; then
            printf '  Existing repo link outside this plan: %s\n' "$CONFIG_DIR/$group"
        fi
    done
    if (( ${#configs[@]} )); then
        printf '  Existing destinations being replaced will be backed up.\n'
    fi
    if (( ${#errors[@]} )); then
        printf '  Cannot apply: %s\n' "${errors[@]}"
        menu 'PLAN ACTIONS' 0 Back Quit
        [[ $MENU_INDEX != 1 ]] || exit 0
        return 1
    fi
    menu 'PLAN ACTIONS' 0 Back Apply Quit
    [[ $MENU_INDEX != 2 ]] || exit 0
    [[ $MENU_INDEX == 1 ]]
}

apply_plan() {
    screen_heading "APPLYING ${stage^^}"
    install_packages || return
    if (( needs_auth )); then
        bash "$SCRIPTS_DIR/bootstrap/github_auth.sh" "${modules[@]}" || return
        if [[ $stage != auth ]]; then
            bash "$SCRIPTS_DIR/bootstrap/submodules.sh" "${modules[@]}" || return
        fi
    fi
    if [[ $stage == all && ${selected[editor]} == 1 && ! -f $DOTFILES_DIR/starter.nvim/init.lua ]]; then
        printf 'The recorded starter.nvim checkout is missing init.lua.\n' >&2
        return 1
    fi
    if [[ ${selected[editor]} == 1 ]]; then
        local env_file="$CONFIG_DIR/.env"
        if [[ $stage == all ]]; then env_file="$DOTFILES_DIR/dotfiles-secrets/.env"; fi
        bash "$SCRIPTS_DIR/bootstrap/post_install.sh" "$env_file" || return
    fi
    if (( ${#configs[@]} )); then
        bash "$SCRIPTS_DIR/bootstrap/symlinks.sh" "${configs[@]}" || return
    fi
}

configure_stage() {
    local screen=preview previous=main app_selection=0
    selected=([base]=0 [shell]=0 [editor]=0 [hypr]=0 [audio]=0)
    case $stage in
        all) selected[base]=1; selected[shell]=1; selected[editor]=1; screen=defaults ;;
        prep) selected[base]=1 ;;
        post) selected[editor]=1 ;;
        symlinks) selected[shell]=1 ;;
    esac

    while true; do
        case $screen in
            defaults)
                screen_heading 'FULL BOOTSTRAP DEFAULTS'
                local setting mark
                for setting in base shell editor; do
                    mark=' '
                    if [[ ${selected[$setting]} == 1 ]]; then mark=x; fi
                    printf '  [%s] %s\n' "$mark" "${labels[$setting]}"
                done
                show_editor
                printf '  Required: sync dotfiles-secrets and apply private configs.\n'
                prompt 'Customize base setup?'
                case $REPLY in
                    yes) screen=base ;;
                    no) previous=defaults; screen=apps ;;
                    back) return ;;
                esac
                ;;
            base)
                if toggle_menu 'BASE SETUP' base shell editor; then
                    previous=base; screen=apps
                else
                    screen=defaults
                fi
                ;;
            apps)
                screen_heading 'OPTIONAL APPS AND PACKAGES'
                prompt 'Would you like to install and configure commonly used apps/packages?'
                case $REPLY in
                    yes) screen=select_apps ;;
                    no) app_selection=0; screen=preview ;;
                    back) screen=$previous ;;
                esac
                ;;
            select_apps)
                if toggle_menu 'SELECT APPS AND PACKAGES' hypr audio; then
                    app_selection=1; screen=preview
                else
                    screen=apps
                fi
                ;;
            preview)
                # Keep toggle state when backing up, even if the prompt excludes it.
                local hypr=${selected[hypr]} audio=${selected[audio]}
                if (( ! app_selection )); then
                    selected[hypr]=0; selected[audio]=0
                fi
                build_plan
                if preview; then
                    local status=0
                    apply_plan || status=$?
                    if (( status == 130 )); then exit 0; fi
                    if (( status == 125 )); then continue; fi
                    if (( status == 0 )); then
                        menu "${stage^^} COMPLETE" 0 'Main menu' Quit
                    else
                        printf 'Bootstrap stopped with status %s. Review the output before retrying.\n' "$status" >&2
                        menu "${stage^^} FAILED" 0 'Main menu' Quit
                    fi
                    [[ $MENU_INDEX != 1 ]] || exit "$status"
                    return "$status"
                fi
                selected[hypr]=$hypr; selected[audio]=$audio
                if [[ $stage != all ]]; then
                    return
                elif (( app_selection )); then
                    screen=select_apps
                else
                    screen=apps
                fi
                ;;
        esac
    done
}

case ${1:-} in
    --help|-h) if (( $# == 1 )); then usage; exit 0; fi ;;
    ''|all|prep|auth|submodules|symlinks|post) ;;
    *) usage >&2; exit 2 ;;
esac
if (( $# > 1 )); then usage >&2; exit 2; fi
if [[ ! -t 0 || ! -t 1 ]]; then
    usage
    if (( $# )); then exit 2; fi
    exit 0
fi

# The alternate buffer keeps the shell's previous screen and scrollback intact.
trap 'printf "\e[?1049l"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf '\e[?1049h'
detect_platform
if (( $# )); then
    stage=$1
    configure_stage
    exit
fi

while true; do
    menu 'DOTFILES BOOTSTRAP' 0 'All — Run the full bootstrap' 'System prep — Install base packages' \
        'GitHub access — Check access to private repositories' 'Sync submodules — Check out recorded revisions' \
        'Apply configs — Link repository configs' 'Editor setup — Check Neovim and its dependencies' Help Quit
    case $MENU_INDEX in
        -1) continue ;;
        7) exit 0 ;;
        6)
            screen_heading HELP
            usage
            menu 'HELP ACTIONS' 0 Back Quit
            [[ $MENU_INDEX != 1 ]] || exit 0
            ;;
        *)
            stage=${stages[MENU_INDEX]}
            configure_stage || {
                # configure_stage returns a failure only after an attempted apply.
                printf 'Returned to the main menu.\n' >&2
            }
            ;;
    esac
done
