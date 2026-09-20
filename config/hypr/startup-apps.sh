#!/bin/bash
# Open apps at login, one at a time so each workspace keeps its left-to-right
# order. Workspace rules in hyprland.lua decide where each app lands.

wait_for() {
  for _ in $(seq 1 60); do
    hyprctl clients -j | grep -q "\"class\": \"$1\"" && return
    sleep 0.5
  done
}

launch() {
  local class=$1; shift
  hyprctl clients -j | grep -q "\"class\": \"$class\"" && return
  uwsm-app -- "$@" >/dev/null 2>&1 &
  wait_for "$class"
}

launch com.anthropic.Claude claude-desktop
launch chatgpt chatgpt
launch google-chrome google-chrome-stable
launch md.obsidian.Obsidian obsidian
launch Spotify spotify

# Scratchpad (SUPER+S): the agent on the left, a terminal on the right.
scratch_address() {
  hyprctl clients -j | jq -r --arg c "$1" \
    'first(.[] | select(.class == $c and .workspace.name == "special:scratchpad") | .address) // empty'
}

scratch() {
  local class=$1 x=$2 y=$3 w=$4 h=$5; shift 5
  local address; address=$(scratch_address "$class")

  if [[ -z $address ]]; then
    local before; before=$(hyprctl clients -j | jq -r --arg c "$class" '.[] | select(.class == $c) | .address')
    uwsm-app -- "$@" >/dev/null 2>&1 &
    for _ in $(seq 1 60); do
      address=$(hyprctl clients -j | jq -r --arg c "$class" '.[] | select(.class == $c) | .address' | grep -vxF -f <(echo "$before") | head -1)
      [[ -n $address ]] && break
      sleep 0.5
    done
    [[ -z $address ]] && return
    hyprctl dispatch "hl.dsp.window.move({ workspace = 'special:scratchpad', follow = false, window = 'address:$address' })" >/dev/null
  fi

  hyprctl dispatch "hl.dsp.window.resize({ x = $w, y = $h, window = 'address:$address' })" >/dev/null
  hyprctl dispatch "hl.dsp.window.move({ x = $x, y = $y, window = 'address:$address' })" >/dev/null
}

(cd "$HOME/Work" && scratch org.omarchy.agent 31 115 1071 829 omarchy-agent)
scratch com.mitchellh.ghostty 1113 119 788 826 ghostty --working-directory="$HOME"

# Finish on workspace 1, showing Claude.
hyprctl dispatch "hl.dsp.focus({ window = 'class:^(com\\\\.anthropic\\\\.Claude)\$' })" >/dev/null
