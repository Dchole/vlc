// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Player
import VLC.Style
import VLC.Dialogs

// "New Playlist" of the redesign (Figma 6259:14954,
// redesign/design/new-playlist.png): a name, and files dropped in its box
// or picked from it; Save makes the playlist in the media library. The
// thumbnail of the design is left out: the media library makes that of a
// playlist from its media.
Window {
    id: root

    readonly property RedesignTheme theme: RedesignTheme {
        scaleFactor: VLCStyle.scale
        lightTheme: !VLCStyle.palette.isDark
        accentColor: MainCtx.redesignAccent
    }

    // The files of the playlist, as URLs
    property var files: []

    MLPlaylistListModel { id: playlists; ml: MediaLib }
    RedesignPreferences { id: helper; ctx: MainCtx }

    title: qsTr("New Playlist — VLC Media Player")
    width: Math.min(theme.dp(713), Screen.desktopAvailableWidth - theme.dp(40))
    height: Math.min(theme.dp(589), Screen.desktopAvailableHeight - theme.dp(60))
    minimumWidth: theme.dp(520); minimumHeight: theme.dp(480)
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    transientParent: MainCtx.intfMainWindow
    color: theme.background

    function begin() {
        nameField.text = ""
        files = []
        visible = true
        raise(); requestActivate()
        nameField.forceActiveFocus()
    }

    function _add(urls) {
        const added = files.slice()
        for (const url of urls) {
            const text = String(url)
            if (!added.includes(text))
                added.push(text)
        }
        files = added
    }

    function save() {
        const name = nameField.text.trim()
        if (name.length === 0)
            return
        playlists.create(name, files)
        visible = false
    }

    Connections {
        target: DialogsProvider
        function onShowRedesignNewPlaylist() { root.begin() }
    }

    component Heading: Column {
        property alias title: titleText.text
        property alias caption: captionText.text
        spacing: theme.dp(8)
        Text { id: titleText; color: theme.bright; font.pixelSize: theme.dp(16); height: theme.dp(28); verticalAlignment: Text.AlignVCenter }
        Text { id: captionText; color: theme.foreground; font.pixelSize: theme.dp(14); height: theme.dp(25); verticalAlignment: Text.AlignVCenter; width: parent.width; elide: Text.ElideRight }
    }

    Item {
        anchors.fill: parent
        Keys.onEscapePressed: root.visible = false

        Rectangle { width: parent.width; height: theme.dp(50); color: theme.field }
        Text {
            x: theme.dp(19); height: theme.dp(50)
            verticalAlignment: Text.AlignVCenter
            text: qsTr("New Playlist")
            color: theme.foreground; font.pixelSize: theme.dp(16)
        }
        MouseArea {
            width: parent.width - theme.dp(46); height: theme.dp(50)
            onPressed: root.startSystemMove()
        }
        RedesignButton {
            anchors.right: parent.right; anchors.rightMargin: theme.dp(9); y: theme.dp(9)
            width: theme.dp(32); height: theme.dp(32)
            scaleFactor: theme.scaleFactor; lightTheme: theme.lightTheme; accentColor: theme.accent
            iconName: "close"; text: qsTr("Close")
            onClicked: root.visible = false
        }

        Item {
            x: theme.dp(20); y: theme.dp(72)
            width: parent.width - 2 * x
            height: parent.height - y - theme.dp(72)

            Heading {
                width: parent.width
                title: qsTr("Playlist Details")
                caption: qsTr("The playlist will be saved and displayed with this title.")
            }

            Rectangle {
                y: theme.dp(80)
                width: parent.width; height: theme.dp(37)
                radius: theme.dp(4)
                color: theme.field
                border.width: theme.dp(1)
                border.color: nameField.activeFocus ? theme.accent : theme.border

                T.TextField {
                    id: nameField
                    anchors.fill: parent
                    leftPadding: theme.dp(13); rightPadding: theme.dp(13)
                    verticalAlignment: TextInput.AlignVCenter
                    color: theme.bright
                    font.pixelSize: theme.dp(14)
                    selectByMouse: true
                    selectionColor: theme.accent; selectedTextColor: theme.bright
                    placeholderText: qsTr("e.g., Favorite Videos")
                    placeholderTextColor: theme.foreground
                    Accessible.name: qsTr("Playlist name")
                    onAccepted: root.save()
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: nameField.leftPadding
                        anchors.verticalCenter: parent.verticalCenter
                        text: nameField.placeholderText; font: nameField.font; color: nameField.placeholderTextColor
                        visible: !nameField.text.length && !nameField.preeditText.length
                    }
                }
            }

            Rectangle {
                y: theme.dp(139)
                width: parent.width; height: theme.dp(1)
                color: theme.border
            }

            Heading {
                y: theme.dp(159)
                width: parent.width
                title: qsTr("Select Files")
                caption: root.files.length > 0
                         ? qsTr("%1 files will be added to the playlist.").arg(root.files.length)
                         : qsTr("These files will be added to the playlist.")
            }

            // Drop files here, or click to pick them
            Rectangle {
                id: dropBox
                y: theme.dp(237)
                width: parent.width; height: parent.height - y
                radius: theme.dp(4)
                color: theme.field
                border.width: theme.dp(1)
                border.color: dropArea.containsDrag || dropMouse.containsMouse ? theme.accent : theme.border

                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    onDropped: (drop) => {
                        if (drop.hasUrls) {
                            root._add(drop.urls)
                            drop.accept()
                        }
                    }
                }

                MouseArea {
                    id: dropMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._add(helper.chooseFiles())
                }

                Column {
                    anchors.centerIn: parent
                    visible: root.files.length === 0
                    spacing: theme.dp(14)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Drag files into the box or click here to select files.")
                        color: theme.foreground
                        font.pixelSize: theme.dp(14)
                    }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: theme.dp(24); height: width
                        sourceSize: Qt.size(width, height)
                        source: "qrc:///redesign/menu/add.svg"
                    }
                }

                ListView {
                    anchors.fill: parent
                    anchors.margins: theme.dp(12)
                    visible: root.files.length > 0
                    clip: true
                    spacing: theme.dp(6)
                    model: root.files
                    delegate: Text {
                        required property string modelData
                        width: ListView.view.width
                        text: decodeURIComponent(modelData.substring(modelData.lastIndexOf("/") + 1))
                        elide: Text.ElideMiddle
                        color: theme.bright
                        font.pixelSize: theme.dp(14)
                    }
                }
            }
        }

        RedesignButton {
            id: cancelButton
            x: theme.dp(20); y: parent.height - theme.dp(52)
            width: theme.dp(100); height: theme.dp(32)
            scaleFactor: theme.scaleFactor; lightTheme: theme.lightTheme; accentColor: theme.accent
            caption: qsTr("Cancel"); text: caption
            background: Rectangle { color: cancelButton.hovered ? theme.hover : theme.panel; radius: theme.dp(4) }
            onClicked: root.visible = false
        }

        RedesignButton {
            anchors.right: parent.right; anchors.rightMargin: theme.dp(20); y: parent.height - theme.dp(52)
            width: theme.dp(100); height: theme.dp(32)
            scaleFactor: theme.scaleFactor; lightTheme: theme.lightTheme; accentColor: theme.accent
            accent: true
            enabled: nameField.text.trim().length > 0
            caption: qsTr("Save"); text: caption
            onClicked: root.save()
        }
    }
}
