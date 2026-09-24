pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen

    property string source: Wallpapers.current
    property Item current
    property bool completed

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool coveredByWindows: monitor?.activeWorkspace?.toplevels?.values.some(t => !t.lastIpcObject?.floating) ?? false
    readonly property bool videoPaused: (Config.background.animatedWallpaper.pauseOnBattery && UPower.onBattery) || (Config.background.animatedWallpaper.pauseOnWindows && coveredByWindows)

    function createWallpaper(): void {
        if (!source) {
            current?.destroy();
            current = null;
            return;
        }

        const component = Wallpapers.isVideo(source) ? videoComp : imgComp;
        current = component.createObject(root, {
            path: source
        });
    }

    onSourceChanged: {
        if (completed)
            createWallpaper();
    }

    Component.onCompleted: {
        completed = true;
        createWallpaper();
    }

    Loader {
        asynchronous: true
        anchors.fill: parent

        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(5).build()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: Tr.tr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Bold).build()
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.extraLargeIncreased
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: Tr.tr("Select a wallpaper")
                            filterLabel: Tr.tr("Wallpaper files")
                            filters: Images.validWallpaperExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: Tr.tr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.body.large
                        }
                    }
                }
            }
        }
    }

    Component {
        id: imgComp

        CachingImage {
            id: img

            readonly property bool ready: status === Image.Ready

            anchors.fill: parent

            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== img && root.current?.opacity === 1
                interval: anim.duration
                onTriggered: img.destroy()
            }
        }
    }

    Component {
        id: videoComp

        VideoWallpaper {
            id: video

            anchors.fill: parent
            paused: root.videoPaused
            opacity: 0

            onReadyChanged: {
                if (ready)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== video && root.current?.opacity === 1
                interval: anim.duration
                onTriggered: video.destroy()
            }
        }
    }
}
