# Isolated Quickshell testing

Checked 2026-09-17 with Quickshell 0.3.1. The repository now has one supported
local runtime check:

```sh
scripts/test-shell.sh
```

It builds the checkout, starts an isolated compositor, gives the test its own
XDG config/data/state/cache/runtime directories, denies access to the user and
system D-Bus sockets, launches the checkout by absolute path, and stops both
processes by PID. The default smoke test uses headless Sway. Interactive mode
uses nested Hyprland for the protocols the shell expects. Both modes were
validated while the installed Caelestia shell remained on its original PID.

For a visible, interactive preview similar to a headed browser test:

```sh
scripts/test-shell.sh --interactive
```

This opens private Hyprland as one nested window on the current desktop.
Quickshell connects only to the nested Wayland and Hyprland IPC sockets, not to
the live equivalents. The script copies the current Caelestia config, wallpaper
state, colour scheme, and application index into temporary directories first.
The preview can read the same wallpaper file, but config and state writes stay
inside the temporary tree. Interact with the shell in that window and press
Ctrl+C in the terminal to stop it. For quick repeats after an unchanged build:

```sh
scripts/test-shell.sh --interactive --skip-build
```

For a longer startup window or a captured frame:

```sh
scripts/test-shell.sh --duration 15
scripts/test-shell.sh --screenshot /tmp/caelestia-test.png
```

The required runtime tools are `qs` plus `sway` for headless mode or `Hyprland`
for interactive mode. Screenshots also require `grim`. On Arch Linux, Sway is
available as the `sway` package. The script makes a temporary copy of the Sway
executable so Arch's `cap_sys_nice` file capability is not inherited inside
development harnesses that reject capability-bearing child processes.

## Why a separate compositor is required

Quickshell's [`--path` option](https://quickshell.org/docs/v0.3.1/guide/distribution/)
selects this checkout instead of the named installed config. Quickshell derives
instance identity from the resolved config path, and supports selecting IPC and
kill targets by PID in its
[`list`, `ipc`, and `kill` commands](https://github.com/quickshell-mirror/quickshell/blob/v0.3.1/src/launch/parsecommand.cpp).
Those boundaries prevent command-target confusion, but they do not isolate
Wayland objects from the compositor.

That matters here because startup creates compositor-facing objects:

- [`ServiceLoader.qml`](../../modules/ServiceLoader.qml) force-loads
  notifications, players, brightness, weather, and idle services.
- [`Shortcuts.qml`](../../modules/Shortcuts.qml) registers Hyprland global
  shortcuts.
- The shell creates layer surfaces and imports a session-lock implementation.
- [`Notifs.qml`](../../services/Notifs.qml) attempts to own the desktop
  notification service on the session bus.

Quickshell documents `PanelWindow` as a layer-shell window and warns that only
one `WlSessionLock` may be active. See the official
[`PanelWindow`](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/PanelWindow/)
and
[`WlSessionLock`](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlSessionLock/)
references.

An offscreen launch is not a valid full-shell smoke test. A local attempt with
`QT_QPA_PLATFORM=offscreen` failed while loading `Notifs.qml` because no
`PanelWindow` backend was available. The offscreen command in
[`.github/workflows/lint.yml`](../../.github/workflows/lint.yml) remains useful
for QML tooling setup, but it should not be treated as runtime acceptance.

Headless Sway supplies a real Wayland and layer-shell implementation for the
fast smoke test. This matches the existing headless Sway check in
[`.github/workflows/update-flake-inputs.yml`](../../.github/workflows/update-flake-inputs.yml).
Interactive mode uses nested Hyprland so Quickshell also receives native
Hyprland IPC, workspace, session-lock, and global-shortcut protocols. Only the
nested compositor's host window is placed on the live compositor. The test
script discovers each private Wayland and IPC socket instead of assuming a
socket or instance name.

The script intentionally provides unreachable D-Bus addresses instead of using
`dbus-run-session`. During local validation, a private bus auto-activated desktop
portal backends whose service environment still pointed at the live Hyprland
display. Removing the bus prevents that bridge back into the live session.

## What the smoke test proves

It checks that:

- the C++ and QML plugin build succeeds;
- the checkout's imports and root component load;
- Wayland windows and layer surfaces can be created;
- the process remains alive for the requested test window;
- an optional compositor screenshot can be captured.

The source checkout sets `settings.watchFiles: false` in
[`shell.qml`](../../shell.qml). The install rule in
[`CMakeLists.txt`](../../CMakeLists.txt) writes the same value into the
installed copy. Each run starts from a fresh temporary snapshot of the selected
visual state.

## What remains shared or unavailable

This is process, user-state, D-Bus, and compositor isolation. It is not a virtual
machine.

- Headless Sway does not provide Hyprland IPC, workspace dispatch,
  Hyprland-specific session-lock behavior, or
  `hyprland_global_shortcuts_v1`. Use interactive mode when those affect the
  feature under test.
- Nested Hyprland has empty workspaces and no host applications. The sidebar
  structure renders, but live workspace icons, active windows, and tray clients
  are not copied into it.
- The private runtime hides the live PipeWire socket, so host audio is
  unavailable.
- Kernel interfaces and networking still exist. System D-Bus is blocked, and
  the script masks known host-changing command names used for power, network,
  VPN, brightness, audio, recording, and process control. This is defense in
  depth, not a complete container or syscall boundary.
- Weather and other network clients are not network-sandboxed.

The environment is suitable for startup checks, screenshots, and ordinary
visual interaction. Avoid deliberately exercising system-changing actions.
Hardware-facing and system-mutating acceptance tests still need a disposable
login session or VM. Testing those paths on the live shell should be the final
manual check, not the first one.

## Recommended development order

1. Make the smallest source change and run focused static or build checks.
2. Run `scripts/test-shell.sh` before any live-shell launch.
3. Use `scripts/test-shell.sh --interactive` for visual and interaction checks,
   or capture a headless screenshot when only the initial state matters.
4. Use a disposable login session or VM for hardware-facing or system-mutating
   behavior.
5. Test in the live shell only after the earlier gates pass.

Never use an unscoped `qs kill`, `qs ipc`, or deprecated `qs msg` when more than
one instance may exist. Use the saved PID or the script's direct child-process
cleanup. Quickshell's
[`IpcHandler` documentation](https://quickshell.org/docs/v0.3.1/types/Quickshell.Io/IpcHandler/)
describes the supported IPC operations.
