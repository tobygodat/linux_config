-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- Claude + ChatGPT (workspace 1), browser + Obsidian (2), Spotify (3).
o.exec_on_start(os.getenv("HOME") .. "/.config/hypr/startup-apps.sh")
