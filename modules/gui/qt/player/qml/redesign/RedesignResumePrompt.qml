// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Templates as T
import VLC.MainInterface
import VLC.Style
import VLC.Player

// The question whether to play from where it was left, next to the playback
// controls (Figma "continue" in "Player - Music", 4767:23750): "You've
// watched till 00:45:08 already." and Continue Watching. It goes after a
// while, or with Escape, and then the media plays from its start.
Rectangle {
    id: root

    property real scaleFactor: VLCStyle.scale
    property color accentColor: MainCtx.redesignAccent
    property bool lightTheme: !VLCStyle.palette.isDark
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }

    // Asked by the player, and not answered yet
    property bool asked: false

    // "00:45:08" for where playback stopped, empty if it is not known
    readonly property string _time: {
        const position = Player.restorePosition
        const length = Player.length
        if (!(position > 0) || !length.valid())
            return ""
        const seconds = Math.floor(position * length.toSeconds())
        const pad = (n) => String(n).padStart(2, "0")
        return pad(Math.floor(seconds / 3600)) + ":" + pad(Math.floor(seconds / 60) % 60) + ":" + pad(seconds % 60)
    }

    signal hidden()

    function ask() {
        asked = true
        timeout.restart()
        continueButton.forceActiveFocus()
    }

    // Not answered: the media plays from its start.
    function dismiss() {
        timeout.stop()
        asked = false
        Player.acknowledgeRestoreCallback()
        hidden()
    }

    visible: asked
    width: row.implicitWidth + theme.dp(30)
    height: theme.dp(52)
    radius: theme.dp(10)
    color: theme.panel

    Accessible.role: Accessible.Dialog
    Accessible.name: label.text

    Keys.onEscapePressed: dismiss()

    Component.onCompleted: {
        if (Player.canRestorePlayback)
            ask()
    }

    Connections {
        target: Player
        // The signal of canRestorePlayback (and restorePosition)
        function onPlaybackRestoreQueried() {
            if (Player.canRestorePlayback)
                root.ask()
            else if (root.asked)
                root.dismiss()
        }
    }

    Timer {
        id: timeout
        interval: 10000
        onTriggered: root.dismiss()
    }

    Row {
        id: row
        x: theme.dp(20)
        anchors.verticalCenter: parent.verticalCenter
        spacing: theme.dp(40)

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root._time.length > 0 ? qsTr("You’ve watched till %1 already.").arg(root._time)
                                         : qsTr("You’ve watched part of this already.")
            color: theme.bright
            font.pixelSize: theme.dp(16)
        }

        RedesignButton {
            id: continueButton
            anchors.verticalCenter: parent.verticalCenter
            width: theme.dp(146); height: theme.dp(32)
            scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
            accent: true
            caption: qsTr("Continue Watching"); text: caption
            Keys.onEscapePressed: root.dismiss()
            onClicked: {
                timeout.stop()
                Player.restorePlaybackPos()
                root.asked = false
                Player.acknowledgeRestoreCallback()
                root.hidden()
            }
        }
    }
}
