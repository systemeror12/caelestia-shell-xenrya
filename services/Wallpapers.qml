pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")
    readonly property list<string> nameFilters: Images.validWallpaperExtensions.map(ext => `*.${ext}`)

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear
    property string thumbnailRevision

    function cleanPath(path: string): string {
        const clean = String(path ?? "").split(/[?#]/)[0];
        return clean.startsWith("file://") ? clean.slice(7) : clean;
    }

    function isVideo(path: string): bool {
        return Images.isValidVideoByName(cleanPath(path));
    }

    function pathHash(path: string): string {
        const clean = cleanPath(path);
        let hash = 5381;
        for (let i = 0; i < clean.length; i++) {
            hash = ((hash << 5) + hash + clean.charCodeAt(i)) | 0;
        }
        return String(hash >>> 0);
    }

    function thumbnailPath(path: string): string {
        return `${Paths.cache}/videothumbs/${pathHash(path)}.jpg`;
    }

    function displaySource(path: string): string {
        if (!isVideo(path))
            return path;

        const revision = thumbnailRevision ? `?v=${thumbnailRevision}` : "";
        return `file://${thumbnailPath(path)}${revision}`;
    }

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
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
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
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Files
        nameFilters: root.nameFilters
    }

    Connections {
        function onEntriesChanged(): void {
            if (wallpapers.entries.some(entry => root.isVideo(entry.path)))
                thumbnailRefreshTimer.restart();
        }

        target: wallpapers
    }

    Timer {
        id: thumbnailRefreshTimer

        interval: 300
        onTriggered: {
            if (!extractThumbnailsProc.running)
                extractThumbnailsProc.running = true;
        }
    }

    Process {
        id: extractThumbnailsProc

        command: ["caelestia", "wallpaper", "--extract-thumbs"]
        onExited: root.thumbnailRevision = Date.now().toString() // qmllint disable signal-handler-parameters
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
