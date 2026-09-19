pragma Singleton

import Quickshell

Singleton {
    readonly property list<string> validImageTypes: ["jpeg", "png", "webp", "tiff", "svg", "gif"]
    readonly property list<string> validImageExtensions: ["jpg", "jpeg", "png", "webp", "tif", "tiff", "svg", "gif"]
    readonly property list<string> validVideoExtensions: ["mp4", "webm", "mkv"]
    readonly property list<string> validWallpaperExtensions: [...validImageExtensions, ...validVideoExtensions]

    function isValidImageByName(name: string): bool {
        const lower = name.toLowerCase();
        return validImageExtensions.some(t => lower.endsWith(`.${t}`));
    }

    function isValidVideoByName(name: string): bool {
        const lower = name.toLowerCase();
        return validVideoExtensions.some(t => lower.endsWith(`.${t}`));
    }
}
