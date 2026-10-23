# `wallpaper get` returns the global wallpaper

While workspace wallpapers are enabled, the focused screen can show a workspace
wallpaper that differs from the global wallpaper. We considered making
`caelestia shell wallpaper get` return what the focused screen shows. It keeps
returning the global wallpaper, the contents of `path.txt`, whether the option
is on or off. Scripts read `get` as the source of the colour scheme, and the
scheme always comes from the global wallpaper. An answer that changed with the
focused workspace would break those scripts without warning. A read call for
workspace wallpapers can be added later if someone needs one.
