// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T
import VLC.MainInterface
import VLC.Style
import VLC.Dialogs

// The welcome screens of the redesign (Figma "Onboarding", 1899:3055,
// 1902:3670 and its colors, 1902:6770; redesign/design/onboarding-*.png):
// a media folder, the theme and color, the basic shortcuts. Shown at the
// start while "qt-onboarding" is on, which Finish turns off.
Window {
    id: root

    property real scaleFactor: VLCStyle.scale
    property color accentColor: MainCtx.redesignAccent
    property bool lightTheme: !VLCStyle.palette.isDark
    readonly property RedesignTheme theme: RedesignTheme { scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor }

    // 0: welcome and media folder, 1: theme and color, 2: shortcuts
    property int step: 0

    // The folders of the media library, when there is one: its QML module
    // only exists then.
    property var _folders: null

    RedesignPreferences { id: preferenceStore; ctx: MainCtx; autoSave: true }

    title: qsTr("Welcome — VLC Media Player")
    width: Math.min(theme.dp(1066), Screen.desktopAvailableWidth - theme.dp(40))
    height: Math.min(theme.dp(742), Screen.desktopAvailableHeight - theme.dp(60))
    minimumWidth: theme.dp(760); minimumHeight: theme.dp(600)
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.ApplicationModal
    transientParent: MainCtx.intfMainWindow
    color: theme.background

    function begin() {
        step = 0
        folderField.text = MainCtx.mediaLibraryAvailable ? preferenceStore.videosFolder() : ""
        visible = true
        raise(); requestActivate()
        nextButton.forceActiveFocus()
    }

    function finish() {
        // The folder of the first screen joins the media library.
        const folder = folderField.text.trim()
        if (folder.length > 0 && MainCtx.mediaLibraryAvailable) {
            // The welcome screens close whatever becomes of the folder.
            try {
                if (!_folders)
                    _folders = Qt.createQmlObject("import VLC.MainInterface; import VLC.MediaLibrary; MLFolderModel { ctx: MainCtx }",
                                                  root, "onboardingFolders")
                _folders.add(_url(folder))
            } catch (error) {
                console.warn("The media folder could not be added:", error)
            }
        }

        MainCtx.setOption("qt-onboarding", false)
        visible = false
    }

    function _url(folder: string) : url {
        return folder.includes("://") ? folder : "file://" + folder
    }

    // A hotkey of VLC as key caps: "Shift+r" is ["Shift", "R"]. The first
    // one where there are several.
    function _caps(option: string) : var {
        const keys = MainCtx.option(option)
        if (typeof keys !== "string" || keys.length === 0)
            return []
        const names = { "Left": "←", "Right": "→", "Up": "↑", "Down": "↓" }
        return keys.split("\t")[0].split("+").map((key) => names[key] ?? ((key.length === 1) ? key.toUpperCase() : key))
    }

    Component.onCompleted: {
        if (MainCtx.showOnboarding())
            Qt.callLater(begin)
    }

    component Heading: Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: theme.bright
        font.pixelSize: theme.dp(24)
        horizontalAlignment: Text.AlignHCenter
    }

    // A key cap of the shortcuts screen
    component KeyCap: Rectangle {
        property alias label: capText.text
        width: Math.max(theme.dp(40), capText.implicitWidth + theme.dp(24))
        height: theme.dp(40)
        radius: theme.dp(8)
        color: root.lightTheme ? "#C9C9C9" : "#121212"
        Rectangle {
            width: parent.width; height: parent.height - theme.dp(4)
            radius: parent.radius
            color: root.lightTheme ? "#F2F2F2" : "#1B1B1B"
            border.width: theme.dp(2)
            border.color: root.lightTheme ? "#BDBDBD" : "#2B2B2B"
            Text {
                id: capText
                anchors.centerIn: parent
                color: theme.bright
                font.pixelSize: theme.dp(15)
            }
        }
    }

    // A shortcut of the third screen: what it does and its keys; two
    // options are two keys with a slash between them.
    component ShortcutRow: Item {
        property string label
        property var options: []
        width: theme.dp(460); height: theme.dp(40)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: theme.foreground
            font.pixelSize: theme.dp(15)
        }
        Row {
            x: theme.dp(235)
            anchors.verticalCenter: parent.verticalCenter
            spacing: theme.dp(10)
            Repeater {
                model: parent.parent.options
                Row {
                    required property string modelData
                    required property int index
                    spacing: theme.dp(8)
                    Text {
                        visible: index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "/"
                        color: theme.foreground
                        font.pixelSize: theme.dp(15)
                    }
                    Row {
                        spacing: theme.dp(4)
                        Repeater {
                            model: root._caps(modelData)
                            KeyCap { required property string modelData; label: modelData }
                        }
                    }
                }
            }
        }
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.finish()

        MouseArea {
            anchors.fill: parent
            onPressed: root.startSystemMove()
        }

        // Welcome and media folder
        Item {
            anchors.fill: parent
            visible: root.step === 0

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                y: theme.dp(116)
                width: theme.dp(124); height: width
                sourceSize: Qt.size(width, height)
                source: "qrc:///redesign/menu/vlc.svg"
            }

            Heading {
                y: theme.dp(280)
                text: qsTr("Welcome to VLC!")
                font.pixelSize: theme.dp(30)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: theme.dp(357)
                width: theme.dp(580)
                text: qsTr("VLC is a free and open source cross-platform multimedia player and framework that plays most multimedia files as well as DVDs, Audio CDs, VCDs, and various streaming protocols.")
                wrapMode: Text.WordWrap
                lineHeight: 1.45
                color: theme.foreground
                font.pixelSize: theme.dp(15)
            }

            Text {
                x: (parent.width - theme.dp(580)) / 2
                y: theme.dp(489)
                text: MainCtx.mediaLibraryAvailable
                      ? qsTr("Choose a Media Folder to get started with")
                      : qsTr("A media folder needs the media library, which is not available.")
                color: theme.foreground
                font.pixelSize: theme.dp(13)
            }

            Rectangle {
                x: (parent.width - theme.dp(580)) / 2
                y: theme.dp(514)
                width: theme.dp(460); height: theme.dp(34)
                radius: theme.dp(4)
                color: theme.field
                border.width: theme.dp(1)
                border.color: folderField.activeFocus ? theme.accent : theme.border
                opacity: folderField.enabled ? 1 : 0.5

                T.TextField {
                    id: folderField
                    anchors.fill: parent
                    leftPadding: theme.dp(13); rightPadding: theme.dp(13)
                    verticalAlignment: TextInput.AlignVCenter
                    enabled: MainCtx.mediaLibraryAvailable
                    color: theme.bright
                    font.pixelSize: theme.dp(15)
                    selectByMouse: true
                    selectionColor: theme.accent; selectedTextColor: theme.bright
                    Accessible.name: qsTr("Media folder")
                }
            }

            RedesignButton {
                x: (parent.width + theme.dp(580)) / 2 - width
                y: theme.dp(514)
                width: theme.dp(112); height: theme.dp(34)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                enabled: MainCtx.mediaLibraryAvailable
                caption: qsTr("Browse"); text: caption
                background: Rectangle { color: parent.hovered ? theme.hover : theme.panel; radius: theme.dp(4) }
                onClicked: {
                    const folder = preferenceStore.chooseFolder(folderField.text)
                    if (folder.length > 0)
                        folderField.text = folder
                }
            }
        }

        // Theme and color
        Item {
            anchors.fill: parent
            visible: root.step === 1

            // The window behind, in the theme and color chosen
            Rectangle {
                x: theme.dp(16); y: theme.dp(18)
                width: parent.width - 2 * x; height: theme.dp(582)
                color: theme.field
                Rectangle { width: parent.width; height: theme.dp(22); color: theme.panel }
                Image {
                    x: theme.dp(8); y: theme.dp(3)
                    width: theme.dp(16); height: width
                    sourceSize: Qt.size(width, height)
                    source: "qrc:///redesign/menu/vlc.svg"
                }
                Rectangle {
                    y: parent.height - height
                    width: parent.width; height: theme.dp(30)
                    color: theme.panel
                    Rectangle {
                        x: theme.dp(30); anchors.verticalCenter: parent.verticalCenter
                        width: theme.dp(30); height: theme.dp(16); radius: theme.dp(3)
                        color: root.accentColor
                    }
                    Rectangle {
                        x: theme.dp(138); anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - theme.dp(250); height: theme.dp(14); radius: theme.dp(2)
                        color: theme.background
                        Rectangle {
                            width: parent.width * 0.08; height: parent.height; radius: parent.radius
                            color: Qt.darker(root.accentColor, 3)
                        }
                    }
                }
            }

            Heading {
                y: theme.dp(176)
                text: qsTr("Select your preferred theme and color.")
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: theme.dp(266)
                spacing: theme.dp(34)

                Repeater {
                    // The values of MainCtx.colorScheme
                    model: [{ label: qsTr("Light"), value: 1 }, { label: qsTr("Dark"), value: 2 }, { label: qsTr("System"), value: 0 }]

                    T.AbstractButton {
                        id: schemeButton
                        required property var modelData
                        readonly property bool current: MainCtx.colorScheme.scheme === modelData.value
                        width: theme.dp(120); height: theme.dp(170)
                        text: modelData.label
                        Accessible.name: text
                        onClicked: MainCtx.colorScheme.setData(MainCtx.colorScheme.index(modelData.value, 0), true, Qt.CheckStateRole)

                        Rectangle {
                            width: theme.dp(120); height: width; radius: theme.dp(18)
                            color: "transparent"
                            border.width: theme.dp(3)
                            border.color: schemeButton.current ? root.accentColor
                                          : (schemeButton.hovered || schemeButton.visualFocus ? theme.border : "transparent")
                            Rectangle {
                                anchors.centerIn: parent
                                width: theme.dp(98); height: width; radius: theme.dp(10)
                                clip: true
                                color: schemeButton.modelData.value === 1 ? "#AFAFAF" : "#222222"
                                // System: dark and light, split on the diagonal
                                Rectangle {
                                    visible: schemeButton.modelData.value === 0
                                    // From a sixth of the top to three quarters of
                                    // the bottom, as in the design
                                    x: parent.width * 0.17; y: 0
                                    width: parent.width; height: parent.height * 1.6
                                    rotation: -30
                                    transformOrigin: Item.TopLeft
                                    color: "#AFAFAF"
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: theme.dp(136)
                            text: schemeButton.text
                            color: theme.foreground
                            font.pixelSize: theme.dp(15)
                        }
                    }
                }
            }

            Row {
                x: theme.dp(40)
                y: parent.height - theme.dp(100)
                spacing: theme.dp(16)

                Repeater {
                    // The accent colors of the preferences, in the order of
                    // the design, and its gray
                    model: ["#d37918", "#bd5960", "#b99327", "#809f3c", "#438b71", "#3c85b7", "#7360ba", "#a35ca0", "#8f8f8f"]

                    T.AbstractButton {
                        id: accentButton
                        required property string modelData
                        readonly property bool current: Qt.colorEqual(root.accentColor, modelData)
                        width: theme.dp(62); height: width
                        text: modelData
                        Accessible.name: qsTr("Accent color %1").arg(modelData)
                        onClicked: preferenceStore.stage("qt-accent-color", modelData === "#d37918" ? "default" : modelData)

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: theme.dp(3)
                            border.color: accentButton.current ? Qt.darker(accentButton.modelData, 2)
                                          : (accentButton.hovered || accentButton.visualFocus ? theme.border : "transparent")
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: theme.dp(40); height: width; radius: width / 2
                            color: accentButton.modelData
                        }
                    }
                }
            }
        }

        // Basic shortcuts, VLC's own
        Item {
            anchors.fill: parent
            visible: root.step === 2

            Heading {
                y: theme.dp(64)
                text: qsTr("Learn the basic keyboard shortcuts.")
            }

            Column {
                x: theme.dp(60); y: theme.dp(150)
                spacing: theme.dp(40)
                ShortcutRow { label: qsTr("Play / Pause"); options: ["key-play-pause"] }
                ShortcutRow { label: qsTr("Seek Backward / Forward"); options: ["key-jump-extrashort", "key-jump+extrashort"] }
                ShortcutRow { label: qsTr("Previous / Next Item"); options: ["key-prev", "key-next"] }
                ShortcutRow { label: qsTr("Previous / Next Frame"); options: ["key-frame-previous", "key-frame-next"] }
                ShortcutRow { label: qsTr("Cycle Subtitle Track"); options: ["key-subtitle-track"] }
                ShortcutRow { label: qsTr("Cycle Audio Track"); options: ["key-audio-track"] }
            }

            Column {
                // In a little from the middle: some hotkeys take four caps.
                x: parent.width / 2 + theme.dp(20); y: theme.dp(150)
                spacing: theme.dp(40)
                ShortcutRow { label: qsTr("Toggle Fullscreen"); options: ["key-toggle-fullscreen"] }
                ShortcutRow { label: qsTr("Increase / Decrease Volume"); options: ["key-vol-up", "key-vol-down"] }
                ShortcutRow { label: qsTr("Take a Snapshot"); options: ["key-snapshot"] }
                ShortcutRow { label: qsTr("Record"); options: ["key-record"] }
            }

            Text {
                x: theme.dp(60)
                // Level with the buttons, which are not in this item
                y: parent.height - theme.dp(84) + (theme.dp(32) - height) / 2
                text: qsTr("Find the full list in the menu.")
                color: theme.foreground
                font.pixelSize: theme.dp(15)
            }
        }

        Row {
            id: finishRow
            anchors.right: parent.right; anchors.rightMargin: theme.dp(48)
            y: parent.height - theme.dp(84)
            spacing: theme.dp(10)

            RedesignButton {
                visible: root.step > 0
                width: theme.dp(98); height: theme.dp(32)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                caption: qsTr("Back"); text: caption
                background: Rectangle { color: parent.hovered ? theme.hover : theme.panel; radius: theme.dp(4); border.width: parent.visualFocus ? theme.dp(2) : 0; border.color: theme.accent }
                onClicked: root.step--
            }

            RedesignButton {
                id: nextButton
                width: theme.dp(98); height: theme.dp(32)
                scaleFactor: root.scaleFactor; lightTheme: root.lightTheme; accentColor: root.accentColor
                accent: true
                caption: root.step < 2 ? qsTr("Next") : qsTr("Finish"); text: caption
                onClicked: {
                    if (root.step < 2)
                        root.step++
                    else
                        root.finish()
                }
            }
        }
    }
}
