pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property var content
    required property ScreenState screenState
    required property var panels
    required property real maxHeight
    required property SearchBar search
    required property int padding
    required property int rounding

    readonly property bool showWallpapers: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}wallpaper `)
    readonly property var currentList: showWallpapers ? wallpaperList.item : appList.item // Can be either ListView or PathView, so can't type properly
    readonly property string staticLabel: Tr.tr("Static")
    readonly property string animatedLabel: Tr.tr("Animated")
    readonly property string refreshLabel: Tr.tr("Refresh")
    property string animState: showWallpapers ? "wallpapers" : "apps"
    property bool showAnimatedWallpapers: Wallpapers.isVideo(Wallpapers.actualCurrent)
    property real wallpaperControlsHeight

    function toggleWallpaperType(): void {
        if (showWallpapers)
            showAnimatedWallpapers = !showAnimatedWallpapers;
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    clip: true
    state: animState

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.implicitWidth: root.Tokens.sizes.launcher.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, appList.implicitHeight > 0 ? appList.implicitHeight : empty.implicitHeight)
                appList.active: true
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "wallpapers"

            PropertyChanges {
                root.implicitWidth: Math.max(root.Tokens.sizes.launcher.itemWidth * 1.2, wallpaperList.implicitWidth)
                root.implicitHeight: root.Tokens.sizes.launcher.wallpaperHeight + root.wallpaperControlsHeight
                wallpaperList.active: true
            }
        }
    ]

    Behavior on animState {
        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                from: 1
                to: 0
                type: Anim.DefaultEffects
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                from: 0
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: appList

        active: false

        anchors.fill: parent

        sourceComponent: AppList {
            objectName: "launcherAppList"

            search: root.search
            screenState: root.screenState
        }
    }

    Loader {
        id: wallpaperList

        asynchronous: true
        active: false

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        sourceComponent: ColumnLayout {
            id: wallpaperPicker

            readonly property int count: listComp.count
            readonly property var currentItem: listComp.currentItem

            function decrementCurrentIndex(): void {
                listComp.decrementCurrentIndex();
            }

            function incrementCurrentIndex(): void {
                listComp.incrementCurrentIndex();
            }

            spacing: root.Tokens.spacing.small
            implicitWidth: Math.max(controls.implicitWidth, listComp.implicitWidth)

            Binding {
                target: root
                property: "wallpaperControlsHeight"
                value: controls.implicitHeight + wallpaperPicker.spacing
            }

            RowLayout {
                id: controls

                Layout.alignment: Qt.AlignHCenter
                spacing: root.Tokens.spacing.small

                IconTextButton {
                    icon: "image"
                    text: root.staticLabel
                    font: root.Tokens.font.body.medium
                    isRound: true
                    horizontalPadding: root.Tokens.padding.medium
                    verticalPadding: root.Tokens.padding.extraSmall
                    type: root.showAnimatedWallpapers ? IconTextButton.Tonal : IconTextButton.Filled
                    onClicked: root.showAnimatedWallpapers = false
                }

                IconTextButton {
                    icon: "movie"
                    text: root.animatedLabel
                    font: root.Tokens.font.body.medium
                    isRound: true
                    horizontalPadding: root.Tokens.padding.medium
                    verticalPadding: root.Tokens.padding.extraSmall
                    type: root.showAnimatedWallpapers ? IconTextButton.Filled : IconTextButton.Tonal
                    onClicked: root.showAnimatedWallpapers = true
                }

                IconTextButton {
                    icon: "refresh"
                    text: root.refreshLabel
                    font: root.Tokens.font.body.medium
                    isRound: true
                    horizontalPadding: root.Tokens.padding.medium
                    verticalPadding: root.Tokens.padding.extraSmall
                    type: IconTextButton.Tonal
                    visible: root.showAnimatedWallpapers
                    disabled: Wallpapers.thumbnailsRefreshing
                    onClicked: Wallpapers.refreshVideoThumbnails()
                }
            }

            WallpaperList {
                id: listComp

                objectName: "launcherWallpaperList"

                Layout.fillWidth: true
                Layout.fillHeight: true

                search: root.search
                screenState: root.screenState
                panels: root.panels
                content: root.content
                showAnimated: root.showAnimatedWallpapers
            }
        }
    }

    Row {
        id: empty

        opacity: root.currentList?.count === 0 ? 1 : 0
        scale: root.currentList?.count === 0 ? 1 : 0.5

        spacing: Tokens.spacing.medium
        padding: Tokens.padding.large

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            text: root.state === "wallpapers" ? "wallpaper_slideshow" : "manage_search"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.extraLarge

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: root.state === "wallpapers" ? Tr.tr("No wallpapers found") : Tr.tr("No results")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                text: root.state === "wallpapers" && Wallpapers.list.length === 0 ? Tr.tr("Try putting some wallpapers in %1").arg(Paths.shortenHome(Paths.wallsdir)) : Tr.tr("Try searching for something else")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitWidth {
        enabled: root.screenState.launcher

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: root.screenState.launcher

        Anim {}
    }
}
