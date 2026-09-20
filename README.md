# linux_config

Omarchy config, synced between machines.

Omarchy 4.0.4 · Hyprland · Arch

## Setting up a new machine

Install Omarchy first. For a **dual-boot alongside Windows**, use the ISO's
manual/custom partitioning path — the guided install claims the whole disk and
will take the Windows ESP with it. Then:

```bash
git clone https://github.com/tobygodat/linux_config ~/linux_config
cd ~/linux_config
./bootstrap.sh
```

`bootstrap.sh` installs the package set, clones the third-party shell plugins,
applies the config, and prints the handful of steps that can't be automated
(monitors, git credentials, theme).

## Day to day

```bash
./sync.sh diff     # what's changed locally vs the repo
./sync.sh pull     # ~/.config -> repo, then commit
./sync.sh apply    # repo -> ~/.config (backs up first)
```

`sync.sh` owns a fixed manifest of paths and ignores everything else in
`~/.config`. After `apply`:

```bash
hyprctl reload && hyprctl configerrors
omarchy restart shell
```

QML bar modules and plugins only reload on `omarchy restart shell` — editing
them and waiting will look like nothing happened.

## Layout

```
config/          mirrors ~/.config/
  hypr/            keybinds, looknfeel, input, autostart, startup-apps.sh
  omarchy/
    shell.json       bar layout, idle timers, enabled plugins
    bar/modules/     9 custom QML bar modules
    plugins/         tobygodat.dashboard, tobygodat.usage (mine)
    themes/          toby-godat, toby-godat-light
    backgrounds/     wallpapers (~28 MB)
    hooks/           post-update hooks
  alacritty/ foot/ kitty/ ghostty/ btop/ lazygit/ git/ fish/ nvim/
hosts/
  tobylinux/       laptop monitors.lua
  example/         template for a new machine
packages.txt     pacman -Qqe
plugins.txt      third-party plugin clone URLs
```

## Deliberately not in here

| | Why |
|---|---|
| `hypr/monitors.lua` | Per-machine. Lives in `hosts/<hostname>/` instead. |
| Third-party plugins | Upstream git repos, 57 MB. `plugins.txt` + `bootstrap.sh` re-clone them. |
| `omarchy/lock-videos/` | Symlinks into the lock-explorer plugin; regenerate themselves once it's cloned. |
| `hooks/post-update.d/setup-fingerprint.hook` | Laptop hardware only. |
| `~/.local/share/wireplumber` override | Works around the laptop's ipu7 camera stalling WirePlumber. No ipu7 on a desktop. |
| `~/.config/{1Password,Bitwarden,gh,Claude,Codex}` | Credentials. |
| `*.bak.*` files | Churn from omarchy-refresh and the omasettings plugin. Gitignored. |

## Gotchas

- **`shell.json` hardcodes an absolute path** to
  `/home/tobygodat/.config/omarchy/bar/modules/group.qml`. Use the same
  username on every machine or that bar module silently disappears.
- **`config/git/config` pins a mise path** for the gh credential helper
  (`.../installs/gh/2.101.0/...`). That version won't exist on a new machine —
  run `gh auth setup-git` to regenerate it.
- **Copies, not symlinks.** `omarchy refresh`, `omarchy bar` and the omasettings
  plugin rewrite these files by replacing them, which turns a symlink back into
  a regular file and silently detaches it from the repo. Hence explicit
  `pull`/`apply`.
- **`packages.txt` is `-Qqe`**, so it includes AUR packages that plain `pacman
  -S` can't resolve. `bootstrap.sh` reports the failures; install those with
  `omarchy pkg aur add <name>`.
