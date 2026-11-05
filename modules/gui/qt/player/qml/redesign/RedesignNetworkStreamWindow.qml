// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T
import VLC.MainInterface
import VLC.Style
import VLC.Dialogs
import VLC.Playlist

// "Open Network Stream" of the redesign (Figma 6216:13614): links, one per
// line, that are queued and played, and an optional name under which they
// are also kept as a playlist of the media library.
Window {
    id: root

    property real scaleFactor: VLCStyle.scale
    property color accentColor: MainCtx.redesignAccent
    property bool lightTheme: !VLCStyle.palette.isDark
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }

    // The playlists of the media library, when there is one: its QML module
    // only exists then.
    property var _playlists: null

    readonly property var _links: urlArea.text.split(/\s+/).filter((link) => link.length > 0)

    title: qsTr("Open Network Stream — VLC Media Player")
    width: Math.min(theme.dp(1048), Screen.desktopAvailableWidth - theme.dp(40))
    height: Math.min(theme.dp(631), Screen.desktopAvailableHeight - theme.dp(60))
    minimumWidth: theme.dp(520); minimumHeight: theme.dp(480)
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    transientParent: MainCtx.intfMainWindow
    color: theme.background

    function begin() {
        urlArea.text = ""
        nameField.text = ""
        visible = true
        raise(); requestActivate()
        urlArea.forceActiveFocus()
    }

    function save() {
        if (_links.length === 0)
            return

        MainPlaylistController.append(_links, true)

        const name = nameField.text.trim()
        if (name.length > 0 && MainCtx.mediaLibraryAvailable) {
            if (!_playlists)
                _playlists = Qt.createQmlObject("import VLC.MediaLibrary; MLPlaylistListModel { ml: MediaLib }",
                                                root, "networkStreamPlaylists")
            _playlists.create(name, _links)
        }

        visible = false
    }

    Connections {
        target: DialogsProvider
        function onShowRedesignNetworkStream() { root.begin() }
    }

    component Heading: Column {
        property alias title: titleText.text
        property alias caption: captionText.text
        spacing: theme.dp(8)
        Text { id: titleText; color: theme.bright; font.pixelSize: theme.dp(16); height: theme.dp(28); verticalAlignment: Text.AlignVCenter }
        Text { id: captionText; color: theme.foreground; font.pixelSize: theme.dp(14); height: theme.dp(25); verticalAlignment: Text.AlignVCenter; width: parent.width; elide: Text.ElideRight }
    }

    component Field: Rectangle {
        property bool active: false
        color: theme.field
        radius: theme.dp(4)
        border.width: theme.dp(1)
        border.color: active ? theme.accent : theme.border
    }

    Item {
        id: content
        anchors.fill: parent
        Keys.onEscapePressed: root.visible = false

        // Title bar
        Rectangle { width: parent.width; height: theme.dp(50); color: theme.field }
        Text {
            x: theme.dp(19); height: theme.dp(50)
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Open Network Stream")
            color: theme.foreground; font.pixelSize: theme.dp(16)
        }
        MouseArea {
            width: parent.width - theme.dp(46); height: theme.dp(50)
            onPressed: root.startSystemMove()
        }
        RedesignButton {
            anchors.right: parent.right; anchors.rightMargin: theme.dp(9); y: theme.dp(9)
            width: theme.dp(32); height: theme.dp(32)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            iconName: "close"; text: qsTr("Close")
            onClicked: root.visible = false
        }

        Item {
            id: body
            x: theme.dp(20); y: theme.dp(50) + theme.dp(22)
            width: parent.width - 2 * theme.dp(20)
            height: footer.y - y

            Heading {
                id: urlHeading
                width: parent.width
                title: qsTr("Network URL")
                caption: qsTr("You can enter multiple links to load.")
            }

            Field {
                id: urlBox
                y: theme.dp(78)
                width: parent.width
                height: Math.max(theme.dp(80), separator.y - theme.dp(20) - y)
                active: urlArea.activeFocus

                Flickable {
                    id: urlFlick
                    anchors.fill: parent
                    anchors.margins: theme.dp(1)
                    clip: true
                    contentWidth: width
                    contentHeight: urlArea.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    T.TextArea {
                        id: urlArea
                        width: urlFlick.width
                        height: Math.max(urlFlick.height, implicitHeight)
                        leftPadding: theme.dp(13); rightPadding: theme.dp(13)
                        topPadding: theme.dp(9); bottomPadding: theme.dp(9)
                        color: theme.bright
                        font.pixelSize: theme.dp(14)
                        wrapMode: TextEdit.WrapAnywhere
                        selectByMouse: true
                        selectionColor: theme.accent; selectedTextColor: theme.bright
                        placeholderText: qsTr("e.g., https://www.example.com/stream.avi")
                        placeholderTextColor: theme.foreground
                        Accessible.name: qsTr("Network URL")
                        // Tab goes to the next field rather than into the
                        // links, Ctrl+Return saves.
                        Keys.onTabPressed: (nameField.enabled ? nameField : cancelButton).forceActiveFocus(Qt.TabFocusReason)
                        Keys.onBacktabPressed: saveButton.forceActiveFocus(Qt.BacktabFocusReason)
                        Keys.onReturnPressed: (event) => {
                            if (event.modifiers & Qt.ControlModifier)
                                root.save()
                            else
                                event.accepted = false
                        }
                        onCursorRectangleChanged: {
                            if (cursorRectangle.y < urlFlick.contentY)
                                urlFlick.contentY = cursorRectangle.y
                            else if (cursorRectangle.y + cursorRectangle.height > urlFlick.contentY + urlFlick.height)
                                urlFlick.contentY = cursorRectangle.y + cursorRectangle.height - urlFlick.height
                        }

                        Text {
                            x: urlArea.leftPadding; y: urlArea.topPadding
                            text: urlArea.placeholderText
                            font: urlArea.font
                            color: urlArea.placeholderTextColor
                            visible: !urlArea.text.length && !urlArea.preeditText.length
                        }
                    }
                }
            }

            Rectangle {
                id: separator
                y: Math.max(urlBox.y + theme.dp(100), nameHeading.y - theme.dp(20))
                width: parent.width; height: theme.dp(1)
                color: theme.border
            }

            Heading {
                id: nameHeading
                y: nameBox.y - theme.dp(20) - height
                width: parent.width
                title: qsTr("Playlist Name (optional)")
                caption: MainCtx.mediaLibraryAvailable
                         ? qsTr("The playlist will be saved and displayed with this title.")
                         : qsTr("Saving a playlist needs the media library, which is not available.")
            }

            Field {
                id: nameBox
                y: parent.height - theme.dp(22) - height
                width: parent.width; height: theme.dp(37)
                active: nameField.activeFocus
                opacity: nameField.enabled ? 1 : 0.5

                T.TextField {
                    id: nameField
                    anchors.fill: parent
                    leftPadding: theme.dp(13); rightPadding: theme.dp(13)
                    verticalAlignment: TextInput.AlignVCenter
                    enabled: MainCtx.mediaLibraryAvailable
                    color: theme.bright
                    font.pixelSize: theme.dp(14)
                    selectByMouse: true
                    selectionColor: theme.accent; selectedTextColor: theme.bright
                    placeholderText: qsTr("e.g., Favorite TV Channels")
                    placeholderTextColor: theme.foreground
                    Accessible.name: qsTr("Playlist Name")
                    KeyNavigation.tab: cancelButton
                    onAccepted: root.save()

                    Text {
                        anchors.left: parent.left; anchors.leftMargin: nameField.leftPadding
                        anchors.verticalCenter: parent.verticalCenter
                        text: nameField.placeholderText
                        font: nameField.font
                        color: nameField.placeholderTextColor
                        visible: !nameField.text.length && !nameField.preeditText.length
                    }
                }
            }
        }

        // Buttons
        Item {
            id: footer
            y: parent.height - height
            width: parent.width; height: theme.dp(72)

            RedesignButton {
                id: cancelButton
                x: theme.dp(20); y: theme.dp(20)
                width: theme.dp(100); height: theme.dp(32)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                caption: qsTr("Cancel"); text: caption
                background: Rectangle { color: cancelButton.hovered ? theme.hover : theme.panel; radius: theme.dp(4); border.width: cancelButton.visualFocus ? theme.dp(2) : 0; border.color: theme.accent }
                KeyNavigation.tab: saveButton
                onClicked: root.visible = false
            }

            RedesignButton {
                id: saveButton
                anchors.right: parent.right; anchors.rightMargin: theme.dp(20); y: theme.dp(20)
                width: theme.dp(100); height: theme.dp(32)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                accent: true
                enabled: root._links.length > 0
                caption: qsTr("Save"); text: caption
                KeyNavigation.tab: urlArea
                onClicked: root.save()
            }
        }
    }
}
