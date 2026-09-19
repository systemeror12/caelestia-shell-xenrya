import QtQuick
import QtMultimedia

Item {
    id: root

    required property string path
    property bool paused
    property bool frameReady
    property bool pauseAfterFirstFrame

    readonly property bool ready: frameReady
    readonly property url mediaSource: {
        if (!path)
            return "";
        return path.startsWith("file://") ? path : `file://${path}`;
    }

    function syncPlayback(): void {
        if (!mediaSource) {
            player.stop();
        } else if (paused) {
            if (frameReady) {
                player.pause();
            } else {
                pauseAfterFirstFrame = true;
                player.play();
            }
        } else {
            pauseAfterFirstFrame = false;
            player.play();
        }
    }

    onMediaSourceChanged: {
        frameReady = false;
        pauseAfterFirstFrame = false;
    }
    onPausedChanged: syncPlayback()

    VideoOutput {
        id: output

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

    MediaPlayer {
        id: player

        source: root.mediaSource
        videoOutput: output
        loops: MediaPlayer.Infinite

        onErrorOccurred: (error, errorString) => {
            if (error !== MediaPlayer.NoError)
                console.warn(`Unable to play animated wallpaper ${root.path}: ${errorString}`);
        }
        onMediaStatusChanged: {
            if ([MediaPlayer.LoadedMedia, MediaPlayer.BufferedMedia].includes(mediaStatus))
                root.syncPlayback();
        }
        onPositionChanged: {
            if (position <= 0)
                return;

            root.frameReady = true;
            if (root.pauseAfterFirstFrame) {
                root.pauseAfterFirstFrame = false;
                pause();
            }
        }
    }
}
