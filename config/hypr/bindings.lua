-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Mouse resize: hold SUPER+SHIFT+W and move the mouse (was: SUPER + right mouse)
hl.unbind("SUPER + mouse:273")
-- Unbind existing SUPER+SHIFT+W (was: Omawrite), moved to SUPER+ALT+W
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Resize window", hl.dsp.window.resize(), { mouse = true })
o.bind("SUPER + ALT + W", "Omawrite", { launch = "omawrite" })

-- SUPER+A: Claude desktop. SUPER+SHIFT+A (was: ChatGPT webapp) is disabled.
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + A", "Claude", { launch = "claude-desktop", focus = "^com\\.anthropic\\.Claude$" })

-- SUPER+ALT+R: reopen any closed workspace apps (Claude, ChatGPT, browser,
-- Obsidian, Spotify) in their usual spots.
o.bind("SUPER + ALT + R", "Reopen workspace apps", os.getenv("HOME") .. "/.config/hypr/startup-apps.sh")

-- SUPER+D: dashboard (clock, calendar, media, system meters).
o.bind("SUPER + D", "Dashboard", "omarchy-shell shell toggle tobygodat.dashboard")

-- window manager
o.bind("SUPER + E", "Exposé", hl.dsp.event("expose.window-overview:toggle"))

-- Browser on SUPER+B (was: SUPER+SHIFT+B, now unbound)
hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + B", "Browser", { omarchy = "browser" })
