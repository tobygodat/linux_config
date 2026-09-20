#!/usr/bin/env bash
# Sync Omarchy config between this repo and the live home directory.
#
#   ./sync.sh pull     home -> repo   (capture local changes)
#   ./sync.sh apply    repo -> home
#   ./sync.sh diff     show what differs, change nothing
#
# Copy-based on purpose, not symlinks: omarchy-refresh, omarchy-bar and the
# omasettings plugin all rewrite these files by replacing them, which silently
# turns a symlink back into a regular file and detaches it from the repo.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
HOST="$(hostnamectl hostname 2>/dev/null || hostname)"

# Paths under ~/.config that this repo owns. monitors.lua is deliberately
# absent -- it is per-machine and lives in hosts/<hostname>/.
MANIFEST_CONFIG=(
  hypr/autostart.lua
  hypr/bindings.lua
  hypr/hyprland.lua
  hypr/input.lua
  hypr/looknfeel.lua
  hypr/omasettings.lua
  hypr/hyprsunset.conf
  hypr/xdph.conf
  hypr/startup-apps.sh
  hypr/.luarc.json

  omarchy/shell.json
  omarchy/omasettings.json
  omarchy/bar/modules
  omarchy/plugins/tobygodat.dashboard
  omarchy/plugins/tobygodat.usage
  omarchy/themes/toby-godat
  omarchy/themes/toby-godat-light
  omarchy/backgrounds/toby-godat
  omarchy/extensions/omarchy-menu.jsonc
  omarchy/hooks/post-update.d/install-voxtype.hook
  omarchy/hooks/post-update.d/setup-agent.hook

  mise

  alacritty
  foot
  ghostty
  kitty
  btop
  lazygit
  git
  fish
  nvim
)

# Paths under ~/.local/share. This is where the apps actually live: every
# launcher in applications/ is user-created (omarchy webapp install / omarchy
# tui install), so none of them come back from a package install.
MANIFEST_DATA=(
  applications
  icons
)

RSYNC=(rsync -a --exclude='*.bak' --exclude='*.bak.*' --exclude='.git/' --exclude='mimeinfo.cache')

# rsync needs a trailing slash on a directory source to copy its contents
# rather than nest it one level deeper.
slash() { [[ -d $1 ]] && printf '%s/' "$1" || printf '%s' "$1"; }

copy_set() { # copy_set <from-root> <to-root> <manifest-name> [extra rsync args...]
  local from=$1 to=$2 name=$3; shift 3
  local -n manifest=$name
  local entry src dst
  for entry in "${manifest[@]}"; do
    src="$from/$entry"
    dst="$to/$entry"
    [[ -e $src ]] || { echo "  skip (absent): $entry"; continue; }
    mkdir -p "$(dirname "$dst")"
    [[ -d $src ]] && mkdir -p "$dst"
    "${RSYNC[@]}" "$@" "$(slash "$src")" "$dst"
  done
}

case "${1:-}" in
  pull)
    echo "Pulling home -> repo"
    copy_set "$CONFIG_HOME" "$REPO/config" MANIFEST_CONFIG --delete
    copy_set "$DATA_HOME"   "$REPO/local/share" MANIFEST_DATA --delete

    mkdir -p "$REPO/hosts/$HOST"
    [[ -e $CONFIG_HOME/hypr/monitors.lua ]] && cp -a "$CONFIG_HOME/hypr/monitors.lua" "$REPO/hosts/$HOST/monitors.lua"

    # -Qqm is the foreign (AUR) set; the rest come from the official repos.
    pacman -Qqm | sort > "$REPO/packages-aur.txt"
    comm -23 <(pacman -Qqe | sort) "$REPO/packages-aur.txt" > "$REPO/packages.txt"

    echo "Done. Review with: git -C '$REPO' status"
    ;;

  apply)
    backup="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
    echo "Backing up current config -> $backup"
    mkdir -p "$backup"
    for entry in "${MANIFEST_CONFIG[@]}"; do
      [[ -e "$CONFIG_HOME/$entry" ]] || continue
      mkdir -p "$backup/config/$(dirname "$entry")"
      cp -a "$CONFIG_HOME/$entry" "$backup/config/$entry"
    done
    for entry in "${MANIFEST_DATA[@]}"; do
      [[ -e "$DATA_HOME/$entry" ]] || continue
      mkdir -p "$backup/share/$(dirname "$entry")"
      cp -a "$DATA_HOME/$entry" "$backup/share/$entry"
    done

    echo "Applying repo -> home"
    copy_set "$REPO/config" "$CONFIG_HOME" MANIFEST_CONFIG
    copy_set "$REPO/local/share" "$DATA_HOME" MANIFEST_DATA

    if [[ -f "$REPO/hosts/$HOST/monitors.lua" ]]; then
      cp -a "$REPO/hosts/$HOST/monitors.lua" "$CONFIG_HOME/hypr/monitors.lua"
      echo "  monitors.lua <- hosts/$HOST"
    else
      echo
      echo "  NOTE: no hosts/$HOST/monitors.lua -- leaving the existing one alone."
      echo "        Write one from:  hyprctl monitors all"
    fi

    command -v update-desktop-database >/dev/null && update-desktop-database "$DATA_HOME/applications" 2>/dev/null || true

    echo
    echo "Now: hyprctl reload && hyprctl configerrors && omarchy restart shell"
    ;;

  diff)
    for entry in "${MANIFEST_CONFIG[@]}"; do
      diff -rq --exclude='*.bak.*' "$REPO/config/$entry" "$CONFIG_HOME/$entry" 2>/dev/null \
        | sed "s|$REPO/config/|repo:|; s|$CONFIG_HOME/|live:|"
    done
    for entry in "${MANIFEST_DATA[@]}"; do
      diff -rq --exclude='mimeinfo.cache' "$REPO/local/share/$entry" "$DATA_HOME/$entry" 2>/dev/null \
        | sed "s|$REPO/local/share/|repo:|; s|$DATA_HOME/|live:|"
    done
    ;;

  *)
    sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
    exit 1
    ;;
esac
