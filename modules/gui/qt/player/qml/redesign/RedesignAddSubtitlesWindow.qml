// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Dialogs
import VLC.Widgets as Widgets

// "Add Subtitles" of the redesign (Figma 1911:7545, 1919:8707;
// redesign/design/add-subtitles-1.png): the videos of a folder, or one
// video, each with the subtitle file that goes with it. Save copies each
// subtitle next to its video under the name of the video, which is how VLC
// finds the subtitles of a file by itself; the playing video also gets its
// subtitle at once. "From OpenSubtitles" hands over to VLSub, the extension
// of VLC that searches OpenSubtitles for the playing video.
Window {
    id: root

    readonly property RedesignTheme theme: RedesignTheme {
        scaleFactor: VLCStyle.scale
        lightTheme: !VLCStyle.palette.isDark
        accentColor: MainCtx.redesignAccent
    }
    readonly property color _control: theme.lightTheme ? "#D9D9D9" : "#151515"

    // The videos are those of this folder, or only this file, or those of
    // a playlist (URLs)
    property bool folderMode: true
    property bool playlistMode: false
    property var playlistVideos: []
    property string playlistTitle: ""
    property string folder: ""
    property string file: ""
    // The subtitle files that were picked, as URLs
    property var subtitles: []
    property var rows: []
    property string message: ""

    readonly property bool _canSave: rows.some((row) => row.subtitle.length > 0)

    RedesignPreferences { id: helper; ctx: MainCtx }

    title: qsTr("Add Subtitles — VLC Media Player")
    width: Math.min(theme.dp(1048), Screen.desktopAvailableWidth - theme.dp(40))
    height: Math.min(theme.dp(800), Screen.desktopAvailableHeight - theme.dp(60))
    minimumWidth: theme.dp(640); minimumHeight: theme.dp(420)
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    transientParent: MainCtx.intfMainWindow
    color: theme.background

    function _toUrl(path: string): string {
        return path.startsWith("file://") ? path : "file://" + encodeURI(path)
    }

    function _parentOf(url: string): string {
        return url.substring(0, url.lastIndexOf("/"))
    }

    function _nameOf(url: string): string {
        return decodeURIComponent(url.substring(url.lastIndexOf("/") + 1))
    }

    // target: the URL of a folder or of a file; empty for the playing media
    function begin(target: string, isFolder: bool) {
        let url = target
        if (url.length === 0) {
            url = Player.url.toString()
            isFolder = false
        }
        folderMode = isFolder
        playlistMode = false
        file = isFolder ? "" : url
        folder = isFolder ? url : _parentOf(url)
        subtitles = []
        message = ""
        _refresh()
        visible = true
        raise(); requestActivate()
        content.forceActiveFocus()
    }

    // The videos of a playlist: those that are files, as subtitles are
    // copied next to them
    function beginPlaylist(videos, title: string) {
        playlistVideos = videos.filter((url) => String(url).startsWith("file://"))
        playlistTitle = title
        playlistMode = true
        folderMode = false
        file = playlistVideos.length > 0 ? playlistVideos[0] : ""
        folder = file.length > 0 ? _parentOf(file) : ""
        subtitles = []
        message = playlistVideos.length < videos.length
                  ? qsTr("%n item(s) of the playlist are not files on this computer and are left out.", "", videos.length - playlistVideos.length)
                  : ""
        _refresh()
        visible = true
        raise(); requestActivate()
        content.forceActiveFocus()
    }

    function _refresh() {
        const videos = playlistMode ? playlistVideos
                     : folderMode ? helper.videosIn(folder) : (file.length > 0 ? [file] : [])
        rows = helper.pairSubtitles(videos, subtitles)
    }

    function _setFolderMode(on: bool) {
        if (on === folderMode && !playlistMode)
            return
        playlistMode = false
        if (!on) {
            // The playing video when it is in this folder, else the first one
            const playing = Player.url.toString()
            file = _parentOf(playing) === folder ? playing : (rows.length > 0 ? rows[0].video : "")
        }
        folderMode = on
        subtitles = []
        _refresh()
    }

    function _pickSubtitles() {
        const picked = helper.chooseSubtitleFiles(folderMode || playlistMode, folder)
        if (picked.length === 0)
            return
        subtitles = picked
        message = ""
        _refresh()
    }

    function _pickTarget() {
        if (folderMode) {
            const path = helper.chooseFolder(decodeURIComponent(folder.replace(/^file:\/\//, "")))
            if (path.length === 0)
                return
            folder = _toUrl(path)
        } else {
            const picked = helper.chooseFiles()
            if (picked.length === 0)
                return
            file = picked[0]
            folder = _parentOf(file)
        }
        subtitles = []
        _refresh()
    }

    function save() {
        const result = helper.saveSubtitles(rows)
        if (result.failed.length > 0) {
            message = qsTr("Could not copy %1.").arg(result.failed.join(", "))
            return
        }
        visible = false
    }

    Connections {
        target: DialogsProvider
        function onShowRedesignAddSubtitles(target, isFolder) { root.begin(target, isFolder) }
        function onShowRedesignAddSubtitlesList(videos, title) { root.beginPlaylist(videos, title) }
    }

    component Dropdown: Rectangle {
        id: dropdown
        property alias text: dropdownText.text
        signal clicked()
        width: theme.dp(200); height: theme.dp(34)
        radius: theme.dp(4)
        color: dropdownMouse.containsMouse ? theme.hover : root._control
        Text {
            id: dropdownText
            x: theme.dp(12); anchors.verticalCenter: parent.verticalCenter
            width: parent.width - theme.dp(48)
            elide: Text.ElideRight
            color: theme.foreground; font.pixelSize: theme.dp(14)
        }
        Widgets.IconLabel {
            x: parent.width - theme.dp(32); anchors.verticalCenter: parent.verticalCenter
            width: theme.dp(24); height: theme.dp(24)
            text: VLCIcons.chevron_down
            color: theme.foreground; font.pixelSize: theme.dp(20)
        }
        MouseArea {
            id: dropdownMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dropdown.clicked()
        }
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.visible = false

        // Title bar and the line of choices under it
        Rectangle { width: parent.width; height: theme.dp(96); color: theme.field }
        Text {
            x: theme.dp(19); height: theme.dp(50)
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Add Subtitles")
            color: theme.foreground; font.pixelSize: theme.dp(14)
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

        Dropdown {
            id: targetBox
            x: theme.dp(9); y: theme.dp(53)
            text: root.playlistMode ? qsTr("To This Playlist")
                  : root.folderMode ? qsTr("To This Folder") : qsTr("To This File")
            onClicked: targetMenu.popup(targetBox, 0, height + theme.dp(4))
        }
        RedesignMenu {
            id: targetMenu
            dark: !theme.lightTheme
            entryWidth: theme.dp(200)
            T.Action { text: qsTr("To This Folder"); icon.source: "qrc:///redesign/menu/folder-two-tone.svg"; onTriggered: root._setFolderMode(true) }
            T.Action { text: qsTr("To This File"); icon.source: "qrc:///redesign/menu/video-two-tone.svg"; onTriggered: root._setFolderMode(false) }
            T.Action {
                text: qsTr("To This Playlist")
                icon.source: "qrc:///redesign/menu/playlist-two-tone.svg"
                enabled: root.playlistVideos.length > 0
                onTriggered: {
                    root.playlistMode = true
                    root.folderMode = false
                    root.subtitles = []
                    root._refresh()
                }
            }
        }

        Dropdown {
            id: originBox
            x: theme.dp(219); y: theme.dp(53)
            text: qsTr("From Computer")
            onClicked: originMenu.popup(originBox, 0, height + theme.dp(4))
        }
        RedesignMenu {
            id: originMenu
            dark: !theme.lightTheme
            entryWidth: theme.dp(240)
            T.Action { text: qsTr("From Computer"); icon.source: "qrc:///redesign/menu/file-two-tone.svg"; onTriggered: root._pickSubtitles() }
            // VLSub looks for the subtitles of the playing video only
            T.Action {
                text: qsTr("From OpenSubtitles")
                icon.source: "qrc:///redesign/menu/streaming-two-tone.svg"
                enabled: Player.playingState !== Player.PLAYING_STATE_STOPPED
                onTriggered: { root.visible = false; Player.openVLsub() }
            }
        }

        // Where the videos are; a click picks another folder or file
        Rectangle {
            id: pathBox
            x: theme.dp(429); y: theme.dp(53)
            width: parent.width - x - theme.dp(9); height: theme.dp(34)
            radius: theme.dp(4)
            color: pathMouse.containsMouse ? theme.hover : root._control
            Widgets.IconLabel {
                x: theme.dp(8); anchors.verticalCenter: parent.verticalCenter
                width: theme.dp(24); height: theme.dp(24)
                text: root.folderMode ? VLCIcons.folder : root.playlistMode ? VLCIcons.playlist : VLCIcons.video
                color: theme.foreground; font.pixelSize: theme.dp(20)
            }
            Text {
                x: theme.dp(42); anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - theme.dp(12)
                elide: Text.ElideLeft
                color: theme.foreground; font.pixelSize: theme.dp(14)
                text: {
                    if (root.playlistMode)
                        return root.playlistTitle
                    const url = root.folderMode ? root.folder : root.file
                    const parts = decodeURIComponent(url.replace(/^file:\/\//, "")).split("/").filter((part) => part.length > 0)
                    return parts.slice(-4).join(" / ")
                }
            }
            MouseArea {
                id: pathMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !root.playlistMode
                onClicked: root._pickTarget()
            }
        }

        // Each video with its subtitle
        ListView {
            id: list
            x: 0; y: theme.dp(96)
            width: parent.width; height: footer.y - y
            clip: true
            topMargin: theme.dp(30); bottomMargin: theme.dp(30)
            spacing: theme.dp(16)
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row
                required property var modelData
                readonly property bool hasNew: modelData.subtitle.length > 0
                readonly property string subtitleName: hasNew ? modelData.subtitleName : modelData.existing
                readonly property real half: list.width / 2
                width: list.width; height: theme.dp(24)

                Widgets.IconLabel {
                    x: theme.dp(30); width: theme.dp(24); height: theme.dp(24)
                    text: VLCIcons.video
                    color: theme.foreground; font.pixelSize: theme.dp(24)
                }
                Text {
                    id: videoName
                    x: theme.dp(68); anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, row.half - x - theme.dp(60))
                    elide: Text.ElideMiddle
                    text: row.modelData.videoName
                    color: theme.foreground; font.pixelSize: theme.dp(14)
                }
                // The dashes between a video and its subtitle
                Row {
                    visible: row.subtitleName.length > 0
                    x: videoName.x + videoName.width + theme.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: theme.dp(4)
                    Repeater {
                        model: Math.max(0, Math.floor((row.half - theme.dp(14) - videoName.x - videoName.width - theme.dp(14)) / theme.dp(10)))
                        Rectangle {
                            width: theme.dp(6); height: Math.max(1, theme.dp(1))
                            color: row.hasNew ? theme.border : Qt.darker(theme.border, 1.4)
                        }
                    }
                }
                Widgets.IconLabel {
                    visible: row.subtitleName.length > 0
                    x: row.half + theme.dp(10); width: theme.dp(24); height: theme.dp(24)
                    text: VLCIcons.subtitles
                    color: row.hasNew ? theme.foreground : theme.border; font.pixelSize: theme.dp(24)
                }
                Text {
                    x: row.half + theme.dp(48); anchors.verticalCenter: parent.verticalCenter
                    width: row.half - theme.dp(78)
                    elide: Text.ElideMiddle
                    text: row.hasNew || row.subtitleName.length === 0 ? row.subtitleName
                                                                    : qsTr("%1 (already there)").arg(row.subtitleName)
                    color: row.hasNew ? theme.foreground : theme.border
                    font.pixelSize: theme.dp(14)
                }
            }
        }

        // A click on the side of the subtitles picks them
        Item {
            x: list.width / 2; y: list.y
            width: list.width / 2; height: list.height
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root._pickSubtitles() }
        }

        Text {
            anchors.centerIn: list
            visible: root.rows.length === 0
            text: root.playlistMode ? qsTr("There is no video file in this playlist.")
                  : root.folderMode ? qsTr("There is no video in this folder.") : qsTr("No video is chosen.")
            color: theme.foreground; font.pixelSize: theme.dp(14)
        }

        Item {
            id: footer
            y: parent.height - height
            width: parent.width; height: theme.dp(72)

            RedesignButton {
                id: cancelButton
                x: theme.dp(20); y: theme.dp(20)
                width: theme.dp(100); height: theme.dp(32)
                scaleFactor: theme.scaleFactor; lightTheme: theme.lightTheme; accentColor: theme.accent
                caption: qsTr("Cancel"); text: caption
                background: Rectangle { color: cancelButton.hovered ? theme.hover : theme.panel; radius: theme.dp(4) }
                onClicked: root.visible = false
            }

            Text {
                anchors.left: cancelButton.right; anchors.leftMargin: theme.dp(20)
                anchors.right: saveButton.left; anchors.rightMargin: theme.dp(20)
                anchors.verticalCenter: cancelButton.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                // What went wrong, or else how subtitles are chosen
                text: root.message.length > 0 ? root.message
                      : root.subtitles.length > 0 || root.rows.length === 0 ? ""
                      : root.folderMode || root.playlistMode ? qsTr("Click the right side to choose the subtitle files of these videos.")
                      : qsTr("Click the right side to choose a subtitle file for this video.")
                color: root.message.length > 0 ? theme.bright : theme.foreground
                font.pixelSize: theme.dp(14)
            }

            RedesignButton {
                id: saveButton
                anchors.right: parent.right; anchors.rightMargin: theme.dp(20); y: theme.dp(20)
                width: theme.dp(100); height: theme.dp(32)
                scaleFactor: theme.scaleFactor; lightTheme: theme.lightTheme; accentColor: theme.accent
                accent: true
                enabled: root._canSave
                caption: qsTr("Save"); text: caption
                onClicked: root.save()
            }
        }
    }
}
