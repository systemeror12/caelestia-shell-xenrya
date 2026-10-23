# Wallpaper changes assign to the focused workspace

Workspace wallpapers need a way to be assigned. We considered a separate "set
for this workspace" action in the launcher and Nexus, a hand-written
workspace-to-path map in the config, and assigning only wallpapers set from
inside the shell. While workspace wallpapers are enabled, every change to the
global wallpaper also assigns that wallpaper to the focused workspace. This
covers the launcher, Nexus, IPC, the CLI, and scripts that call it, because they
all end in `path.txt`. That file is the only place the shell can observe a
change. Loading `path.txt` at startup is not a change, and neither is the
fallback wallpaper the shell writes when `path.txt` is empty or missing, at
startup or while running. Neither assigns. The shell cannot tell a hand-typed CLI call from a script, and a rule
that treated them differently would make the terminal behave unlike the
launcher. Users with random-wallpaper timers who do not want their workspaces
assigned can leave the feature off.

A wallpaper set from inside the shell (the launcher, Nexus, and `wallpaper set`
over IPC, which all go through `setWallpaper`) is also assigned to the focused
workspace when it is set, before the CLI writes `path.txt`. Otherwise the
background would fall back to that workspace's old wallpaper until the write
lands. The cost: if focus moves between the pick and the write, both workspaces
get the wallpaper.
