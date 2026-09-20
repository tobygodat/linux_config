-- Per-machine monitor config. Copy this to hosts/<hostname>/monitors.lua and
-- fill it in from `hyprctl monitors all` on that machine.
--
-- Do NOT copy the laptop's version to a desktop: it pins a 2880x1800@120
-- panel at scale 1.6 with GDK_SCALE=2, which on a 1440p/4K desktop gives you
-- a wrong mode and 2x-sized UI.

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Example: a specific display
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })
