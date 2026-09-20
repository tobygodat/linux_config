#!/usr/bin/env bash
# One-time setup on a fresh Omarchy install. Safe to re-run.
#
#   ./bootstrap.sh
#
# Installs packages (repo + AUR), the mise toolchain, the third-party shell
# plugins, then hands off to ./sync.sh apply -- which is what actually brings
# over the app launchers in ~/.local/share/applications.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"

echo "==> Repo packages"
mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$REPO/packages.txt")
echo "    ${#pkgs[@]} packages"
sudo pacman -S --needed --noconfirm "${pkgs[@]}" || echo "    (some failed -- see above)"

echo
echo "==> AUR packages"
mapfile -t aur < <(grep -vE '^\s*(#|$)' "$REPO/packages-aur.txt")
echo "    ${#aur[@]} packages: ${aur[*]}"
omarchy pkg aur add "${aur[@]}" || echo "    (some failed -- install by hand)"

echo
echo "==> mise toolchain"
# config/mise/config.toml is applied by sync.sh; install what it declares.
if command -v mise >/dev/null; then
  cp -a "$REPO/config/mise" "${XDG_CONFIG_HOME:-$HOME/.config}/"
  mise install || echo "    (some tools failed)"
else
  echo "    mise not found -- skipping (omarchy normally ships it)"
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
echo "==> Config and app launchers"
"$REPO/sync.sh" apply

cat <<'EOF'

==> Remaining manual steps

  1. monitors.lua -- if apply said it left yours alone, write one:
       hyprctl monitors all
       $EDITOR ~/.config/hypr/monitors.lua
     then commit it as hosts/$(hostnamectl hostname)/monitors.lua

  2. git credentials -- config/git/config pins an absolute mise path for the
     gh credential helper. Regenerate it for this machine:
       gh auth login && gh auth setup-git

  3. uv (fish conf.d sources its env file):
       curl -LsSf https://astral.sh/uv/install.sh | sh

  4. Not packaged, install by hand if you want them on this machine:
       librepods      https://github.com/kavishdevar/librepods   (AirPods; the
                      OpenPods launcher and omapods bar plugin both need it)
       iphone-mirror  python app in ~/.local/share/iphone-mirror; its launcher
                      points at a venv, so reinstall rather than copy

  5. Theme and restart:
       omarchy theme set toby-godat
       omarchy restart shell
EOF
