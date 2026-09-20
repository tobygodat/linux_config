#!/usr/bin/env bash
# One-time setup on a fresh Omarchy install. Safe to re-run.
#
#   ./bootstrap.sh
#
# Installs the package set, re-clones the third-party shell plugins (they are
# upstream git repos, not vendored here), then hands off to ./sync.sh apply.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"

echo "==> Packages"
if [[ -f "$REPO/packages.txt" ]]; then
  mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$REPO/packages.txt")
  echo "    ${#pkgs[@]} packages from packages.txt"
  sudo pacman -S --needed --noconfirm "${pkgs[@]}" || {
    echo "    Some packages failed (AUR-only or renamed). Retry those with:"
    echo "      omarchy pkg aur add <name>"
  }
fi

echo
echo "==> Third-party shell plugins"
mkdir -p "$PLUGIN_DIR"
while read -r id url; do
  [[ -z ${id:-} || $id == \#* ]] && continue
  if [[ -d "$PLUGIN_DIR/$id/.git" ]]; then
    echo "    $id (already cloned, pulling)"
    git -C "$PLUGIN_DIR/$id" pull --ff-only || true
  else
    echo "    $id <- $url"
    git clone --depth 1 "$url" "$PLUGIN_DIR/$id"
  fi
done < "$REPO/plugins.txt"

echo
echo "==> Config"
"$REPO/sync.sh" apply

cat <<'EOF'

==> Remaining manual steps

  1. monitors.lua -- if bootstrap said it left yours alone, write one:
       hyprctl monitors all
       $EDITOR ~/.config/hypr/monitors.lua
     then commit it as hosts/$(hostnamectl hostname)/monitors.lua

  2. git credentials -- config/git/config pins an absolute mise path for the
     gh credential helper. Regenerate it for this machine:
       gh auth login && gh auth setup-git

  3. Theme:
       omarchy theme set toby-godat

  4. Restart the shell so the QML bar modules and plugins load:
       omarchy restart shell
EOF
