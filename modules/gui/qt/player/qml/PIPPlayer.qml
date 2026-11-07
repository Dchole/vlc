/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.Util

// The mini player of the redesign (Figma "Miniplayer", 970:3091,
// redesign/design/miniplayer.png): the video in a card over the library,
// with its progress, its title, where it comes from and who made it, and
// the queue above it. Over the video: close, back to the player, and the
// playback buttons.
T.Control {
    id: root

    // The card without the queue, as in the design
    readonly property real cardWidth: VLCStyle.dp(391, VLCStyle.scale)
    readonly property real cardHeight: VLCStyle.dp(339, VLCStyle.scale)
    readonly property real queueHeight: VLCStyle.dp(355, VLCStyle.scale)

    // Whether the queue is shown above the card
    property bool queueOpen: false

    width: cardWidth
    height: cardHeight + (queueOpen ? queueHeight : 0)

    objectName: "pip window"

    property real dragXMin: 0
    property real dragXMax: 0
    property real dragYMin: undefined
    property real dragYMax: undefined

    property int textStyle: Text.Outline

    // `hideControls` being `false` does not necessarily mean that the buttons are shown:
    property bool hideControls: MainCtx.usingTouch // By default controls are hidden with touch

    readonly property RedesignTheme theme: RedesignTheme {
        scaleFactor: VLCStyle.scale
        lightTheme: !VLCStyle.palette.isDark
        accentColor: MainCtx.redesignAccent
    }

    readonly property bool _ended: Player.playingState === Player.PLAYING_STATE_STOPPED

    readonly property bool _overVideo: videoHover.hovered

    // The folder the media is in, for a media that has no album
    readonly property string _folder: {
        const path = decodeURIComponent(String(Player.url))
        const parts = path.split("/").filter((part) => part.length > 0)
        return parts.length > 1 ? parts[parts.length - 2] : ""
    }

    Accessible.role: Accessible.Graphic
    Accessible.focusable: false
    Accessible.name: qsTr("video content")

    Drag.active: dragHandler.active

    Drag.onActiveChanged: {
        root.anchors.left = undefined
        root.anchors.right = undefined
        root.anchors.top = undefined
        root.anchors.bottom = undefined
        root.anchors.verticalCenter = undefined
        root.anchors.horizontalCenter = undefined
    }

    // The queue opens above the card: keep the card where it is.
    onQueueOpenChanged: {
        if (root.anchors.bottom === undefined)
            root.y += queueOpen ? -queueHeight : queueHeight
    }

    DragHandler {
        id: dragHandler

        target: root

        cursorShape: Qt.DragMoveCursor

        grabPermissions: PointerHandler.CanTakeOverFromAnything

        xAxis.minimum: root.dragXMin
        xAxis.maximum: root.dragXMax
        yAxis.minimum: root.dragYMin
        yAxis.maximum: root.dragYMax
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.ArrowCursor
    }

    background: Rectangle {
        radius: VLCStyle.dp(14, VLCStyle.scale)
        color: root.theme.panel

        Widgets.DefaultShadow { }
    }

    contentItem: Item {
        // The queue
        Item {
            id: queue

            width: parent.width
            height: root.queueHeight
            visible: root.queueOpen
            clip: true

            readonly property PlaylistListModel model: PlaylistListModel {
                playlist: MainPlaylistController.playlist
            }

            Rectangle {
                width: parent.width; height: VLCStyle.dp(58, VLCStyle.scale)
                radius: VLCStyle.dp(14, VLCStyle.scale)
                color: root.theme.hover
                Rectangle { y: parent.height / 2; width: parent.width; height: parent.height / 2; color: parent.color }

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Queue")
                    color: root.theme.foreground
                    font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                }
            }

            Text {
                x: VLCStyle.dp(36, VLCStyle.scale); y: VLCStyle.dp(82, VLCStyle.scale)
                text: {
                    const count = queue.model.count
                    const items = (count === 1) ? qsTr("1 item") : qsTr("%1 items").arg(count)
                    const duration = queue.model.duration
                    if (count === 0 || !duration.valid())
                        return items
                    return qsTr("%1 - %2").arg(items).arg(duration.formatShort())
                }
                color: root.theme.foreground
                opacity: 0.7
                font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
            }

            ListView {
                x: VLCStyle.dp(24, VLCStyle.scale); y: VLCStyle.dp(120, VLCStyle.scale)
                width: parent.width - 2 * x
                height: parent.height - y - VLCStyle.dp(8, VLCStyle.scale)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: VLCStyle.dp(12, VLCStyle.scale)
                model: queue.model

                delegate: T.AbstractButton {
                    id: queueRow

                    required property int index
                    required property var model

                    width: ListView.view.width
                    height: VLCStyle.dp(32, VLCStyle.scale)
                    text: model.title
                    Accessible.name: text
                    onClicked: MainPlaylistController.goTo(index, true)

                    background: Rectangle {
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: queueRow.hovered ? root.theme.hover : "transparent"
                    }

                    contentItem: Item {
                        Widgets.IconLabel {
                            x: VLCStyle.dp(8, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            text: VLCIcons.move
                            font.pixelSize: VLCStyle.icon_normal
                            color: root.theme.foreground
                        }
                        Text {
                            x: VLCStyle.dp(46, VLCStyle.scale)
                            width: duration.x - x - VLCStyle.dp(8, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            text: queueRow.text
                            elide: Text.ElideRight
                            color: queueRow.model.isCurrent ? root.theme.accent : root.theme.bright
                            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        }
                        Text {
                            id: duration
                            anchors.right: parent.right
                            anchors.rightMargin: VLCStyle.dp(8, VLCStyle.scale)
                            anchors.verticalCenter: parent.verticalCenter
                            text: queueRow.model.duration.valid() ? queueRow.model.duration.formatShort() : ""
                            color: root.theme.foreground
                            opacity: 0.7
                            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                        }
                    }
                }
            }
        }

        // The card
        Item {
            id: card

            y: root.queueOpen ? root.queueHeight : 0
            width: parent.width
            height: root.cardHeight

            // The video, framed
            Rectangle {
                id: videoFrame

                x: VLCStyle.dp(9, VLCStyle.scale); y: x
                width: parent.width - 2 * x
                height: VLCStyle.dp(209, VLCStyle.scale)
                radius: VLCStyle.dp(8, VLCStyle.scale)
                color: "black"
                border.width: VLCStyle.dp(1, VLCStyle.scale)
                border.color: root.theme.border
                clip: true

                VideoSurface {
                    id: videoSurface
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    videoSurfaceProvider: MainCtx.videoSurfaceProvider
                }

                HoverHandler { id: videoHover }

                DoubleClickIgnoringItem {
                    anchors.fill: parent

                    TapHandler {
                        gesturePolicy: TapHandler.WithinBounds

                        onDoubleTapped: (eventPoint, button) => {
                            if (eventPoint.device.type !== PointerDevice.TouchScreen)
                                MainCtx.playerView = true
                        }

                        onTapped: (eventPoint, button) => {
                            if (eventPoint.device.type === PointerDevice.TouchScreen)
                                root.hideControls = !root.hideControls
                            else
                                MainPlaylistController.togglePlayPause()
                        }
                    }
                }

                // The buttons over the video, while the pointer is over it
                Rectangle {
                    anchors.fill: parent
                    z: 1
                    visible: !root.hideControls && (root._overVideo || root._ended)
                    color: Qt.rgba(0, 0, 0, 0.55)
                    radius: parent.radius

                    component OverlayButton: Widgets.IconButton {
                        font.pixelSize: VLCStyle.icon_normal
                        textStyle: root.textStyle
                        color: "white"
                    }

                    OverlayButton {
                        id: closeButton
                        x: VLCStyle.dp(12, VLCStyle.scale); y: x
                        text: VLCIcons.close
                        description: qsTr("close video")
                        AccessibleCompat.id: "pipCloseButton"
                        onClicked: MainPlaylistController.stop()
                    }

                    OverlayButton {
                        id: fullscreenButton
                        anchors.right: parent.right; anchors.rightMargin: VLCStyle.dp(12, VLCStyle.scale)
                        y: VLCStyle.dp(12, VLCStyle.scale)
                        text: VLCIcons.open
                        description: qsTr("maximize player")
                        AccessibleCompat.id: "pipFullscreenButton"
                        onClicked: MainCtx.playerView = true
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: VLCStyle.dp(44, VLCStyle.scale)

                        OverlayButton {
                            anchors.verticalCenter: parent.verticalCenter
                            text: VLCIcons.previous
                            description: qsTr("Previous")
                            enabled: MainPlaylistController.hasPrev
                            onClicked: MainPlaylistController.prev()
                        }

                        OverlayButton {
                            id: playButton
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: VLCStyle.icon_large
                            description: root._ended ? qsTr("replay") : qsTr("play/pause")
                            AccessibleCompat.id: "pipPlayButton"
                            text: root._ended ? VLCIcons.replay
                                  : (Player.playingState !== Player.PLAYING_STATE_PAUSED ? VLCIcons.pause_filled
                                                                                       : VLCIcons.play_filled)
                            onClicked: MainPlaylistController.togglePlayPause()
                        }

                        OverlayButton {
                            anchors.verticalCenter: parent.verticalCenter
                            text: VLCIcons.next
                            description: qsTr("Next")
                            enabled: MainPlaylistController.hasNext
                            onClicked: MainPlaylistController.next()
                        }
                    }
                }
            }

            // The progress, which a click moves
            Rectangle {
                id: progress

                x: videoFrame.x
                y: videoFrame.y + videoFrame.height + VLCStyle.dp(6, VLCStyle.scale)
                width: videoFrame.width
                height: VLCStyle.dp(14, VLCStyle.scale)
                radius: height / 2
                color: root.theme.field

                Rectangle {
                    width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, Player.position)))
                    height: parent.height
                    radius: parent.radius
                    color: root.theme.progress

                    Rectangle {
                        anchors.right: parent.right
                        width: VLCStyle.dp(8, VLCStyle.scale); height: parent.height
                        radius: width / 2
                        color: root.theme.accent
                        visible: progressMouse.containsMouse || root._overVideo
                    }
                }

                MouseArea {
                    id: progressMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: (mouse) => Player.position = mouse.x / width
                }
            }

            Text {
                x: VLCStyle.dp(16, VLCStyle.scale)
                y: progress.y + progress.height + VLCStyle.dp(17, VLCStyle.scale)
                width: parent.width - 2 * x
                text: Player.title || Player.name
                elide: Text.ElideRight
                color: root.theme.bright
                font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
            }

            // Where it comes from and who made it, and the queue
            Row {
                x: VLCStyle.dp(16, VLCStyle.scale)
                y: parent.height - VLCStyle.dp(48, VLCStyle.scale)
                spacing: VLCStyle.dp(20, VLCStyle.scale)

                component MetaLabel: Row {
                    property alias icon: metaIcon.text
                    property alias label: metaText.text
                    spacing: VLCStyle.dp(8, VLCStyle.scale)
                    visible: label.length > 0
                    Widgets.IconLabel {
                        id: metaIcon
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: VLCStyle.icon_normal
                        color: root.theme.foreground
                    }
                    Text {
                        id: metaText
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, VLCStyle.dp(120, VLCStyle.scale))
                        elide: Text.ElideRight
                        color: root.theme.foreground
                        font.pixelSize: VLCStyle.dp(16, VLCStyle.scale)
                    }
                }

                MetaLabel {
                    icon: Player.album ? VLCIcons.album : VLCIcons.folder
                    label: Player.album || root._folder
                }

                MetaLabel {
                    icon: VLCIcons.artist
                    label: Player.artist
                }
            }

            Widgets.IconButton {
                anchors.right: parent.right; anchors.rightMargin: VLCStyle.dp(16, VLCStyle.scale)
                y: parent.height - VLCStyle.dp(48, VLCStyle.scale)
                font.pixelSize: VLCStyle.icon_normal
                text: VLCIcons.queue
                description: qsTr("Queue")
                color: root.queueOpen ? root.theme.accent : root.theme.foreground
                onClicked: root.queueOpen = !root.queueOpen
            }
        }
    }
}
