-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

-- Terminals (and the Claude/agent window) open floating and centered at a
-- fixed size instead of tiling across the full screen width.
o.window("^(com\\.mitchellh\\.ghostty|org\\.omarchy\\.agent)$", {
  float = true,
  center = true,
  size = { 1300, 930 },
})

-- Pin apps to workspaces. Workspaces 1-3 use the scrolling layout, so apps
-- sharing a workspace sit side by side.
o.window("^(com\\.anthropic\\.Claude|chatgpt)$", { workspace = "1" })
o.window("^(google-chrome|md\\.obsidian\\.Obsidian)$", { workspace = "2" })
o.window("^([Ss]potify)$", { workspace = "3" })

-- Load settings written by OmaSettings (omasettings:managed).
require("hypr.omasettings")
