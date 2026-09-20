#!/usr/bin/env bash
# Sync Omarchy config between this repo and ~/.config.
#
#   ./sync.sh pull     ~/.config  ->  repo   (capture local changes)
#   ./sync.sh apply    repo       ->  ~/.config
#   ./sync.sh diff     show what differs, change nothing
#
# Copy-based on purpose, not symlinks: omarchy-refresh, omarchy-bar and the
# omasettings plugin all rewrite these files by replacing them, which silently
# turns a symlink back into a regular file and detaches it from the repo.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}"
HOST="$(hostnamectl hostname 2>/dev/null || hostname)"

# Paths relative to ~/.config that this repo owns. Everything else in
# ~/.config is left alone. monitors.lua is deliberately absent -- it is
# per-machine and lives in hosts/<hostname>/.
MANIFEST=(
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

RSYNC=(rsync -a --exclude='*.bak' --exclude='*.bak.*' --exclude='.git/')

# rsync needs a trailing slash on a directory source to copy its contents
# rather than nest it one level deeper.
slash() { [[ -d $1 ]] && printf '%s/' "$1" || printf '%s' "$1"; }

copy_set() { # copy_set <from-root> <to-root> [extra rsync args...]
  local from=$1 to=$2; shift 2
  local entry src dst
  for entry in "${MANIFEST[@]}"; do
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
    echo "Pulling $DEST -> repo"
    copy_set "$DEST" "$REPO/config" --delete
    mkdir -p "$REPO/hosts/$HOST"
    [[ -e $DEST/hypr/monitors.lua ]] && cp -a "$DEST/hypr/monitors.lua" "$REPO/hosts/$HOST/monitors.lua"
    pacman -Qqe > "$REPO/packages.txt"
    echo "Done. Review with: git -C '$REPO' status"
    ;;

  apply)
    backup="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
    echo "Backing up current config -> $backup"
    mkdir -p "$backup"
    for entry in "${MANIFEST[@]}"; do
      [[ -e "$DEST/$entry" ]] || continue
      mkdir -p "$backup/$(dirname "$entry")"
      cp -a "$DEST/$entry" "$backup/$entry"
    done

    echo "Applying repo -> $DEST"
    copy_set "$REPO/config" "$DEST"

    if [[ -f "$REPO/hosts/$HOST/monitors.lua" ]]; then
      cp -a "$REPO/hosts/$HOST/monitors.lua" "$DEST/hypr/monitors.lua"
      echo "  monitors.lua <- hosts/$HOST"
    else
      echo
      echo "  NOTE: no hosts/$HOST/monitors.lua -- leaving the existing one alone."
      echo "        Write one from:  hyprctl monitors all"
    fi

    echo
    echo "Now: hyprctl reload && hyprctl configerrors && omarchy restart shell"
    ;;

  diff)
    for entry in "${MANIFEST[@]}"; do
      diff -rq --exclude='*.bak.*' "$REPO/config/$entry" "$DEST/$entry" 2>/dev/null \
        | sed "s|$REPO/config/|repo:|; s|$DEST/|live:|"
    done
    ;;

  *)
    sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
    exit 1
    ;;
esac
