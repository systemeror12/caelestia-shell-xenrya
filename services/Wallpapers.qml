pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import Caelestia.State
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear
    property bool ignoreNextLoad: true
    property list<string> missingWorkspaceWallpapers

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        Quickshell.execDetached(["caelestia", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        actualCurrent = path;
        if (GlobalConfig.background.workspaceWallpapers.enabled)
            assignToFocusedWorkspace(path);
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
    }

    function forScreen(screen: ShellScreen): string {
        if (showPreview)
            return previewPath;
        if (GlobalConfig.background.workspaceWallpapers.enabled) {
            const wall = PersistentState.workspaceWallpapers[Hypr.monitorFor(screen)?.activeWorkspace?.name];
            if (wall && !missingWorkspaceWallpapers.includes(wall))
                return wall;
        }
        return actualCurrent;
    }

    function assignToFocusedWorkspace(path: string): void {
        const name = Hypr.focusedMonitor?.activeWorkspace?.name;
        if (!name)
            return;
        const walls = Object.assign({}, PersistentState.workspaceWallpapers);
        walls[name] = path;
        PersistentState.workspaceWallpapers = walls;
    }

    function useFallback(): void {
        actualCurrent = fallback;
        previewColourLock = false;
        ignoreNextLoad = true;
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", fallback, ...smartArg]);
    }

    function checkWorkspaceWallpapers(): void {
        if (!GlobalConfig.background.workspaceWallpapers.enabled)
            return;
        missingCheckProc.exec(["sh", "-c", 'for p; do [ -e "$p" ] || printf "%s\\n" "$p"; done', "sh", ...Object.values(PersistentState.workspaceWallpapers)]);
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    Component.onCompleted: checkWorkspaceWallpapers()

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const wall = text().trim();
            if (!wall) {
                root.useFallback();
                return;
            }
            // The startup load and the result of the shell's own fallback write are not changes (ADR 0001)
            if (!root.ignoreNextLoad && GlobalConfig.background.workspaceWallpapers.enabled)
                root.assignToFocusedWorkspace(wall);
            root.ignoreNextLoad = false;
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: root.useFallback()
    }

    Connections {
        function onWorkspaceWallpapersChanged(): void {
            root.checkWorkspaceWallpapers();
        }

        target: PersistentState
    }

    Connections {
        function onEntriesChanged(): void {
            root.checkWorkspaceWallpapers();
        }

        target: wallpapers
    }

    Connections {
        function onEnabledChanged(): void {
            root.checkWorkspaceWallpapers();
        }

        target: GlobalConfig.background.workspaceWallpapers
    }

    Process {
        id: missingCheckProc

        stdout: StdioCollector {
            onStreamFinished: root.missingWorkspaceWallpapers = text.split("\n").filter(p => p)
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images | FileSystemModel.Videos
    }

    Process {
        id: getPreviewColoursProc

        command: ["caelestia", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }
}
