#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
    printf '%s\n' \
        "Usage: scripts/test-shell.sh [--interactive] [--duration SECONDS] [--screenshot FILE] [--skip-build]" \
        "" \
        "Build and test this checkout in an isolated Hyprland session." \
        "The default smoke test runs Hyprland inside headless labwc." \
        "Use --interactive to open the nested Hyprland as a window on the live desktop." \
        "The test never connects Quickshell itself to the live Wayland compositor."
}

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

duration=5
screenshot=
skip_build=0
interactive=0

while (($# > 0)); do
    case $1 in
        --duration)
            if (($# < 2)); then
                printf '%s requires a value\n' "$1" >&2
                exit 64
            fi
            duration=$2
            shift 2
            ;;
        --screenshot)
            if (($# < 2)); then
                printf '%s requires a value\n' "$1" >&2
                exit 64
            fi
            screenshot=$2
            shift 2
            ;;
        --skip-build)
            skip_build=1
            shift
            ;;
        --interactive)
            interactive=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

if [[ ! $duration =~ ^[1-9][0-9]*$ ]]; then
    printf 'Duration must be a positive integer, got: %s\n' "$duration" >&2
    exit 64
fi

required_commands=(cmake cp find qs Hyprland)
if ((interactive == 0)); then
    required_commands+=(hyprctl labwc)
fi
for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null; then
        printf 'Missing dependency: %s\n' "$command_name" >&2
        exit 69
    fi
done

if [[ -n $screenshot ]] && ! command -v grim >/dev/null; then
    printf 'Missing dependency for --screenshot: grim\n' >&2
    exit 69
fi

build_dir="$repo_root/build"
if ((skip_build == 0)); then
    if [[ ! -f $build_dir/CMakeCache.txt ]]; then
        cmake -S "$repo_root" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
    fi
    cmake --build "$build_dir"
fi

if [[ ! -d $build_dir/qml ]]; then
    printf 'Missing build output: %s\n' "$build_dir/qml" >&2
    printf 'Run without --skip-build to configure and build the project.\n' >&2
    exit 66
fi

host_home=${HOME:?}
host_config_dir=${XDG_CONFIG_HOME:-$host_home/.config}
host_state_dir=${XDG_STATE_HOME:-$host_home/.local/state}

# Keep this path short enough for Hyprland's Unix-domain IPC socket limit.
test_root=$(mktemp -d -t cqs.XXXXXX)
host_pid=
compositor_pid=
shell_pid=

cleanup() {
    if [[ -n $shell_pid ]]; then
        kill "$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    if [[ -n $compositor_pid ]]; then
        kill "$compositor_pid" 2>/dev/null || true
        wait "$compositor_pid" 2>/dev/null || true
    fi
    if [[ -n $host_pid ]]; then
        kill "$host_pid" 2>/dev/null || true
        wait "$host_pid" 2>/dev/null || true
    fi
    find "$test_root" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

runtime_dir="$test_root/runtime"
config_dir="$test_root/config"
data_dir="$test_root/data"
state_dir="$test_root/state"
cache_dir="$test_root/cache"
home_dir="$test_root/home"
blocked_bin_dir="$test_root/blocked-bin"
host_log="$test_root/labwc.log"
compositor_log="$test_root/compositor.log"
shell_log="$test_root/quickshell.log"

mkdir -p \
    "$runtime_dir" \
    "$config_dir" \
    "$data_dir" \
    "$state_dir" \
    "$cache_dir" \
    "$home_dir" \
    "$blocked_bin_dir"
chmod 700 "$runtime_dir"

# Copy the user's visual configuration and harmless shell state. The private
# copies let the preview match the live shell without writing back to it.
if [[ -d $host_config_dir/caelestia ]]; then
    cp -a -- "$host_config_dir/caelestia" "$config_dir/"
fi
mkdir -p "$state_dir/caelestia"
for state_name in wallpaper scheme.json apps.sqlite sequences.txt; do
    if [[ -e $host_state_dir/caelestia/$state_name || -L $host_state_dir/caelestia/$state_name ]]; then
        cp -a -- "$host_state_dir/caelestia/$state_name" "$state_dir/caelestia/"
    fi
done

blocked_commands=(
    brightnessctl
    caelestia
    ddcutil
    gpu-screen-recorder
    halt
    hyprctl
    killall
    loginctl
    mullvad
    nmcli
    openvpn
    pactl
    pkill
    playerctl
    poweroff
    reboot
    shutdown
    systemctl
    tailscale
    warp-cli
    wf-recorder
    wg-quick
    wpctl
)
for command_name in "${blocked_commands[@]}"; do
    ln -s /usr/bin/false "$blocked_bin_dir/$command_name"
done

if ((interactive == 1)); then
    host_runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    host_wayland_display=${WAYLAND_DISPLAY:-}
    if [[ -z $host_wayland_display ]]; then
        printf 'Interactive mode requires WAYLAND_DISPLAY.\n' >&2
        exit 69
    fi

    if [[ $host_wayland_display = /* ]]; then
        host_wayland_socket=$host_wayland_display
    else
        host_wayland_socket="$host_runtime_dir/$host_wayland_display"
    fi
    if [[ ! -S $host_wayland_socket ]]; then
        printf 'Live Wayland socket not found: %s\n' "$host_wayland_socket" >&2
        exit 69
    fi
else
    # Without a seat, Hyprland gets its GPU from a parent compositor, and it needs
    # xdg_wm_base v6, which Sway does not offer. Headless labwc is only that parent.
    host_runtime_dir="$test_root/labwc-runtime"
    labwc_config_dir="$test_root/labwc-config"
    mkdir -p "$host_runtime_dir" "$labwc_config_dir"
    chmod 700 "$host_runtime_dir"

    # Left to choose, wlroots can pick a discrete NVIDIA GPU, where grim cannot
    # capture Hyprland. Use the first render node unless the caller picks one.
    render_node=${WLR_RENDER_DRM_DEVICE:-$(find /dev/dri -maxdepth 1 -name 'renderD*' -print | sort | head -n 1)}

    env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u SWAYSOCK -u I3SOCK \
        HOME="$home_dir" \
        XDG_RUNTIME_DIR="$host_runtime_dir" \
        XDG_CONFIG_HOME="$config_dir" \
        XDG_DATA_HOME="$data_dir" \
        XDG_STATE_HOME="$state_dir" \
        XDG_CACHE_HOME="$cache_dir" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/no-session-bus" \
        DBUS_SYSTEM_BUS_ADDRESS="unix:path=$runtime_dir/no-system-bus" \
        LABWC_UPDATE_ACTIVATION_ENV=false \
        WLR_BACKENDS=headless \
        WLR_RENDERER=gles2 \
        WLR_RENDER_DRM_DEVICE="$render_node" \
        PATH="$blocked_bin_dir:$PATH" \
        labwc --config-dir "$labwc_config_dir" >"$host_log" 2>&1 &
    host_pid=$!

    host_wayland_socket=
    for _ in $(seq 1 50); do
        host_wayland_socket=$(find "$host_runtime_dir" -maxdepth 1 -type s -name 'wayland-*' -print -quit)
        if [[ -n $host_wayland_socket ]] || ! kill -0 "$host_pid" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    if [[ -z $host_wayland_socket ]]; then
        printf 'labwc did not create a Wayland socket.\n' >&2
        sed -n '1,240p' "$host_log" >&2
        exit 70
    fi
fi

host_wayland_display=host-wayland
ln -s -- "$host_wayland_socket" "$runtime_dir/$host_wayland_display"

env -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u SWAYSOCK -u I3SOCK \
    HOME="$home_dir" \
    XDG_RUNTIME_DIR="$runtime_dir" \
    XDG_CONFIG_HOME="$config_dir" \
    XDG_DATA_HOME="$data_dir" \
    XDG_STATE_HOME="$state_dir" \
    XDG_CACHE_HOME="$cache_dir" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/no-session-bus" \
    DBUS_SYSTEM_BUS_ADDRESS="unix:path=$runtime_dir/no-system-bus" \
    XDG_CURRENT_DESKTOP=Hyprland \
    WAYLAND_DISPLAY="$host_wayland_display" \
    HYPRLAND_NO_SD_VARS=1 \
    PATH="$blocked_bin_dir:$PATH" \
    Hyprland --config "$repo_root/scripts/hyprland-test.lua" >"$compositor_log" 2>&1 &
compositor_pid=$!

wayland_display=
hyprland_signature=
hyprland_ipc_ready=0
for _ in $(seq 1 50); do
    wayland_display=$(find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' -quit)
    hyprland_signature=$(find "$runtime_dir/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' -quit 2>/dev/null || true)
    if [[ -n $hyprland_signature \
        && -S $runtime_dir/hypr/$hyprland_signature/.socket.sock \
        && -S $runtime_dir/hypr/$hyprland_signature/.socket2.sock ]]; then
        hyprland_ipc_ready=1
    fi
    if [[ -n $wayland_display && $hyprland_ipc_ready == 1 ]]; then
        break
    fi
    if ! kill -0 "$compositor_pid" 2>/dev/null; then
        break
    fi
    sleep 0.1
done

if [[ -z $wayland_display ]]; then
    printf 'Hyprland did not create a Wayland socket.\n' >&2
    sed -n '1,240p' "$compositor_log" >&2
    exit 70
fi
if ((hyprland_ipc_ready == 0)); then
    printf 'Hyprland did not create usable isolated IPC sockets.\n' >&2
    sed -n '1,240p' "$compositor_log" >&2
    exit 70
fi

isolated_hyprctl() {
    env XDG_RUNTIME_DIR="$runtime_dir" HYPRLAND_INSTANCE_SIGNATURE="$hyprland_signature" hyprctl "$@"
}

if ((interactive == 0)); then
    # Aquamarine announces the nested window as a monitor only after the parent
    # compositor sends another event, and idle headless labwc never does.
    isolated_hyprctl output create headless >/dev/null
    monitor_ready=0
    for _ in $(seq 1 50); do
        if [[ $(isolated_hyprctl -j monitors) == *'"name"'* ]]; then
            monitor_ready=1
            break
        fi
        sleep 0.1
    done
    if ((monitor_ready == 0)); then
        printf 'Hyprland did not add its headless monitor.\n' >&2
        sed -n '1,240p' "$compositor_log" >&2
        exit 70
    fi
fi

qml_import_path="$build_dir/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

shell_environment=(
    "HOME=$home_dir"
    "XDG_RUNTIME_DIR=$runtime_dir"
    "XDG_CONFIG_HOME=$config_dir"
    "XDG_DATA_HOME=$data_dir"
    "XDG_STATE_HOME=$state_dir"
    "XDG_CACHE_HOME=$cache_dir"
    "DBUS_SESSION_BUS_ADDRESS=unix:path=$runtime_dir/no-session-bus"
    "DBUS_SYSTEM_BUS_ADDRESS=unix:path=$runtime_dir/no-system-bus"
    "WAYLAND_DISPLAY=$wayland_display"
    "XDG_CURRENT_DESKTOP=Hyprland"
    "HYPRLAND_INSTANCE_SIGNATURE=$hyprland_signature"
    "PATH=$blocked_bin_dir:$PATH"
    "QML2_IMPORT_PATH=$qml_import_path"
    "CAELESTIA_LIB_DIR=$build_dir/lib"
    "QS_NO_RELOAD_POPUP=1"
)
env -u DISPLAY -u SWAYSOCK -u I3SOCK \
    "${shell_environment[@]}" \
    qs --no-color --no-duplicate -p "$repo_root" >"$shell_log" 2>&1 &
shell_pid=$!

for _ in $(seq 1 "$((duration * 10))"); do
    if ! kill -0 "$shell_pid" 2>/dev/null; then
        set +e
        wait "$shell_pid"
        shell_status=$?
        set -e
        shell_pid=
        printf 'Quickshell exited during the smoke-test window with status %s.\n' "$shell_status" >&2
        if ! kill -0 "$compositor_pid" 2>/dev/null; then
            printf 'Hyprland also exited. Its log follows.\n' >&2
            sed -n '1,240p' "$compositor_log" >&2
        fi
        sed -n '1,260p' "$shell_log" >&2
        if ((shell_status == 0)); then
            exit 1
        fi
        exit "$shell_status"
    fi
    sleep 0.1
done

if [[ -n $screenshot ]]; then
    env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        WAYLAND_DISPLAY="$wayland_display" \
        grim "$screenshot"
fi

if ((interactive == 1)); then
    printf '%s\n' \
        'Interactive preview is running in the nested Hyprland window.' \
        'The preview uses private copies of your Caelestia config and visual state.' \
        'Host-changing commands are blocked. Press Ctrl+C here to stop.'

    while kill -0 "$compositor_pid" 2>/dev/null && kill -0 "$shell_pid" 2>/dev/null; do
        sleep 0.2
    done

    if ! kill -0 "$compositor_pid" 2>/dev/null; then
        wait "$compositor_pid" 2>/dev/null || true
        compositor_pid=
        printf 'Interactive preview closed.\n'
        exit 0
    fi

    set +e
    wait "$shell_pid"
    shell_status=$?
    set -e
    shell_pid=
    printf 'Quickshell exited during interactive preview with status %s.\n' "$shell_status" >&2
    sed -n '1,260p' "$shell_log" >&2
    if ((shell_status == 0)); then
        exit 1
    fi
    exit "$shell_status"
fi

kill "$shell_pid" 2>/dev/null || true
wait "$shell_pid" 2>/dev/null || true
shell_pid=

printf 'Isolated Quickshell smoke test passed after %s seconds.\n' "$duration"
if [[ -n $screenshot ]]; then
    printf 'Screenshot written to %s\n' "$screenshot"
fi
