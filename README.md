# Dotfiles bootstrap

Clone the main repository, then run `./scripts/bootstrap.sh` as your regular
user. The main menu shows the full bootstrap and individual stages. Use
`--help` to see the direct stage commands.

Use the arrow keys or `h/j/k/l` to navigate and Enter to select or toggle.
Every screen has a way to go back or quit. Review the plan and choose
**Apply** to make changes.

- **All** selects base tools, Bash and Git configs, and Neovim by default.
  It always checks GitHub access, checks out the recorded `dotfiles-secrets`
  commit, and applies the private configs present in that checkout. A GitHub
  PAT is only prompted for when public-key registration is needed.
- **Optional apps** start unchecked. Hyprland Desktop includes Waybar, Foot,
  and the tools used by the repo's desktop config. PipeWire Audio is a
  separate group. Availability depends on the enabled distro repositories.
- Existing Neovim binaries on PATH are kept. The upstream archive install
  supports x86-64 and ARM64. Replaced configs are backed up under
  `~/backups`. The completion output prints the paths used.
- Package setup supports apt, dnf, and pacman with distro repositories.
  On Arch, applying a plan with missing packages runs a full package upgrade
  to avoid a partial upgrade. The preview calls this out.

The simulated terminal tests are kept in the homelab repository under
`projects/bootstrap-scripts/tests`. The project README there shows how to
run them against this checkout.

## Private identity and repository access

Place your personal Git configuration in `dotfiles-secrets/git/.gitconfig`.
Include your own `[user]` name and email there. The bootstrap links it at
`~/.gitconfig-private` and the shared Git config includes that path.
If you already have a Git identity in `~/.gitconfig`, preserve it in the
private checkout before replacing that file.

The two submodule URLs are relative to the main repository's remote. Keep
the repositories as siblings or set the corresponding `submodule.<name>.url`
overrides in local Git configuration. SSH access is checked against each
selected repository using your existing SSH config and agent. A GitHub
token is only offered for a GitHub SSH key rejection. GitLab access uses
its own SSH identity and permissions.
