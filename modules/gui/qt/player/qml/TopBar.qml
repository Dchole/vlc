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
import QtQuick.Layouts
import QtQuick.Window


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.PlayerControls
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Dialogs
import VLC.Util

FocusScope{
    id: root

    // Properties

    required property int textWidth

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    property int reservedHeight: 0

    property int topMargin: 0
    property int sideMargin: 0

    property string title

    property bool showCSD: false
    property bool showToolbar: false
    property bool pinControls: false

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Private

    property bool _showTopBar: (pinControls === false || showToolbar === false)

    property bool _showCenterText: (pinControls && showToolbar === false && showCSD)

    readonly property int _sideMargin: VLCStyle.margin_small + sideMargin

    // The folder a local file is in. Other media have none.
    readonly property string _folderName: {
        const url = Player.url.toString()
        if (!url.startsWith("file:"))
            return ""

        const parts = url.split("/")
        return (parts.length >= 2) ? decodeURIComponent(parts[parts.length - 2]) : ""
    }

    // Whether the window buttons, which are not always ours to draw, have
    // taken the full screen button in.
    readonly property bool _fullscreenInCSD: showCSD
                                             && (csdDecorations.status === Loader.Ready)
                                             && csdDecorations.item.hasOwnProperty("beforeClose")

    // Aliases

    property alias resumeVisible: resumeDialog.visible

    property bool playlistVisible: false

    // Signals

    signal togglePlaylistVisibility()
    signal requestLockUnlockAutoHide(bool lock)
    signal backRequested()

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    Accessible.role: Accessible.ToolBar
    Accessible.name: qsTr("Player topbar")
    AccessibleCompat.id: "playerTopBar"

    // Events

    Component.onCompleted: _layout()

    onShowCSDChanged: _layout()
    onPinControlsChanged: _layout()
    onShowToolbarChanged: _layout()
    onTopMarginChanged: _layout()
    onSideMarginChanged: _layout()

    on_ShowTopBarChanged: _layout()
    on_ShowCenterTextChanged: _layout()

    // Functions

    // FIXME: Imperative layouting in QML is stupid, this needs to be gone.
    function _layoutLine(c1, c2, offset)
    {
        let c1Height = c1?.implicitHeight ?? 0
        let c2Height = c2?.implicitHeight ?? 0

        if (c2 === csdDecorations) {
            //csdDecorations.implicitHeight gets overwritten when the height is set,
            //VLCStyle.icon_normal is its initial value
            c2Height = VLCStyle.icon_normal
        }

        const lineHeight = Math.max(c1Height, c2Height)

        if (c1) {
            c1.height = lineHeight
            c1.anchors.topMargin = offset
        }

        if (c2) {
            c2.height = lineHeight
            c2.anchors.topMargin = offset
        }
        return lineHeight
    }

    // FIXME: Imperative layouting in QML is stupid, this needs to be gone.
    //FIXME: if CSD will be weirdly placed if application safe-area are used,
    //nota that if you need a safe area (kiosk mode), you probably don't need CSD
    function _layout() {
        let offset = topMargin

        if (_showCenterText) {
            //place everything on one line
            //csdDecorations.implicitHeight gets overwritten when the height is set,
            //VLCStyle.icon_normal is its initial value
            const lineHeight = Math.max(logoOrResume.implicitHeight, playlistGroup.implicitHeight, VLCStyle.icon_normal)

            centerTitleText.y = 0
            centerTitleText.height = lineHeight

            csdDecorations.height  = lineHeight

            logoOrResume.height =  lineHeight

            playlistGroup.height = lineHeight
            playlistGroup.anchors.topMargin = 0
            playlistGroup.extraRightMargin = Qt.binding(function() { return width - csdDecorations.x })


            implicitHeight = lineHeight
            offset += lineHeight

        } else {
            playlistGroup.extraRightMargin = 0

            let left = undefined
            let right = undefined
            let logoPlaced = false

            if (showToolbar) {
                left = menubar
            }

            if (showCSD) {
                right = csdDecorations
                if (!left) {
                    left = logoOrResume
                    logoPlaced = true
                }
            }

            if (!!left || !!right) {
                offset += _layoutLine(left, right, offset)

                if (showCSD) {
                    tapNDrag.height = offset
                }
            }

            if (!logoPlaced) {
                left = logoOrResume
            } else {
                left = undefined
            }

            if (_showTopBar)
                right = playlistGroup
            else
                right = undefined

            offset += _layoutLine(left, right, offset)
        }

        implicitHeight = offset
        reservedHeight = offset
    }

    // Children

    Component {
        id: fullscreenComponent

        Widgets.IconToolButton {
            font.pixelSize: VLCStyle.icon_normal
            padding: VLCStyle.margin_xxxsmall
            horizontalPadding: VLCStyle.dp(6, VLCStyle.scale)

            enabled: Player.hasVideoOutput
            text: Player.fullscreen ? VLCIcons.defullscreen : VLCIcons.fullscreen
            description: qsTr("Fullscreen")

            AccessibleCompat.id: "topBarFullscreenButton"

            Navigation.parentItem: root
            Navigation.leftItem: folderBtn.visible ? folderBtn : backBtn

            onClicked: Player.fullscreen = !Player.fullscreen

            onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
        }
    }

    //drag and dbl click the titlebar in CSD mode
    Loader {
        id: tapNDrag

        anchors.fill: parent
        active: root.showCSD
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"

        Connections {
            target: tapNDrag.item
            enabled: tapNDrag.status === Loader.Ready
            function onCsdMenuVisibleChanged() {
                root.requestLockUnlockAutoHide(tapNDrag.item.csdMenuVisible)
            }
        }
    }

    // Components -
    Menus.Menubar {
        id: menubar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: root.sideMargin
        anchors.right: root.showCSD ? csdDecorations.left : parent.right


        visible: root.showToolbar
        enabled: root.showToolbar

        onHoveredChanged: menu => root.requestLockUnlockAutoHide(hovered)
        onMenuOpenedChanged: menu => root.requestLockUnlockAutoHide(menuOpened)
        onImplicitHeightChanged: root._layout()
    }

    Item {
        id: logoOrResume

        anchors.left: root.left
        anchors.top: root.top
        anchors.leftMargin:  root._sideMargin

        implicitWidth: resumeVisible ? resumeDialog.implicitWidth
                                     : logoGroup.implicitWidth

        implicitHeight: {
            if (root.resumeVisible) {
                // Only if there are multiple lines use `resumeDialog`'s implicit height, otherwise the video
                // window may get resized by few pixels unnecessarily when `resumeDialog` is no longer visible.
                if (resumeDialog.implicitHeight >= (logoGroup.implicitHeight + resumeDialog.baselineOffset))
                    return resumeDialog.implicitHeight
                else
                    return logoGroup.implicitHeight
            } else if (_showTopBar)
                return logoGroup.implicitHeight
            else
                return 0
        }

        onImplicitHeightChanged: root._layout()

        Item {
            id: logoGroup

            anchors.fill: parent

            visible: (root._showTopBar && root.resumeVisible === false)

            implicitHeight: VLCStyle.dp(40, VLCStyle.scale)
            implicitWidth: logoRow.implicitWidth

            Row {
                id: logoRow

                anchors.fill: parent

                // One pixel short of the 13 the logo is from the edge in the
                // redesign: the rest is the margin of the parent.
                leftPadding: VLCStyle.dp(1, VLCStyle.scale)

                Widgets.IconLabel {
                    id: logo

                    anchors.verticalCenter: parent.verticalCenter

                    text: VLCIcons.cone
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.accent
                }

                Item {
                    id: logoSpacer

                    width: VLCStyle.dp(14, VLCStyle.scale)
                    height: 1
                }

                Widgets.IconToolButton {
                    id: menuSelector

                    anchors.verticalCenter: parent.verticalCenter

                    visible: !root.showToolbar
                    enabled: visible

                    // The dots are drawn smaller than the other icons, in a box
                    // of the same size.
                    font.pixelSize: VLCStyle.dp(18, VLCStyle.scale)
                    padding: VLCStyle.dp(5, VLCStyle.scale)

                    text: VLCIcons.more
                    description: qsTr("Menu")

                    AccessibleCompat.id: "topBarMenuButton"

                    checked: contextMenu.visible

                    Navigation.parentItem: root
                    Navigation.rightItem: backBtn

                    onClicked: {
                        if (contextMenu.visible)
                            contextMenu.dismiss()
                        else
                            contextMenu.popup(this, 0, height + VLCStyle.dp(6, VLCStyle.scale))
                    }

                    onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

                    // The main menu of the redesign (Figma 6062:13354). What
                    // it leaves out of VLC's menus is in the menu bar (F10).
                    RedesignMenu {
                        id: contextMenu

                        readonly property string _icons: "qrc:///redesign/menu/"

                        // The recently played media, when there is a media
                        // library: its QML module only exists then.
                        readonly property var _recents: MainCtx.mediaLibraryAvailable
                            ? Qt.createQmlObject("import VLC.MediaLibrary; MLRecentMediaModel { ml: MediaLib; limit: 10 }",
                                                 contextMenu, "recentMedia")
                            : null

                        dark: root.colorContext.palette.isDark
                        entryWidth: VLCStyle.dp(367, VLCStyle.scale)

                        onAboutToShow: root.requestLockUnlockAutoHide(true)
                        onAboutToHide: root.requestLockUnlockAutoHide(false)

                        // The keys move in the menu, not in the player.
                        onOpened: MainCtx.preferHotkeys = false
                        onClosed: MainCtx.preferHotkeys = true

                        T.Action {
                            property string shortcutText: "Ctrl + O"
                            text: qsTr("Open File(s)")
                            icon.source: contextMenu._icons + "file-two-tone.svg"
                            onTriggered: DialogsProvider.simpleOpenDialog()
                        }

                        T.Action {
                            property string shortcutText: "Ctrl + F"
                            text: qsTr("Open Folder")
                            icon.source: contextMenu._icons + "folder-two-tone.svg"
                            onTriggered: DialogsProvider.PLOpenDir()
                        }

                        T.Action {
                            property string shortcutText: "Ctrl + N"
                            text: qsTr("Open Network Stream")
                            icon.source: contextMenu._icons + "streaming-two-tone.svg"
                            onTriggered: DialogsProvider.openNetDialog()
                        }

                        T.Action {
                            property string shortcutText: "Ctrl + D"
                            text: qsTr("Open Disc")
                            icon.source: contextMenu._icons + "disc-two-tone.svg"
                            onTriggered: DialogsProvider.openDiscDialog()
                        }

                        T.Action {
                            property string shortcutText: "Ctrl + C"
                            text: qsTr("Open Capture Device")
                            icon.source: contextMenu._icons + "capture-device-two-tone.svg"
                            onTriggered: DialogsProvider.openCaptureDialog()
                        }

                        T.Action {
                            property string shortcutText: "Ctrl + R"
                            text: qsTr("Convert")
                            icon.source: contextMenu._icons + "swap-two-tone.svg"
                            onTriggered: DialogsProvider.openAndTranscodingDialogs()
                        }

                        RedesignMenu {
                            id: recentMenu

                            title: qsTr("Open Recent")
                            iconSource: contextMenu._icons + "recent-two-tone.svg"
                            dark: contextMenu.dark
                            enabled: (contextMenu._recents?.count ?? 0) > 0

                            Instantiator {
                                model: contextMenu._recents

                                delegate: T.Action {
                                    readonly property string url: model.url

                                    text: model.title || url
                                    onTriggered: MainPlaylistController.append(url, true)
                                }

                                onObjectAdded: (index, object) => recentMenu.insertAction(index, object)
                                onObjectRemoved: (index, object) => recentMenu.removeAction(object)
                            }
                        }

                        // The profiles of the control bar.
                        RedesignMenu {
                            id: profileMenu

                            readonly property var _profiles: MainCtx.controlbarProfileModel

                            title: qsTr("Profile (%1)").arg(_profiles.currentModel?.name ?? "")
                            iconSource: contextMenu._icons + "profile-two-tone.svg"
                            dark: contextMenu.dark
                            divider: true

                            Instantiator {
                                model: profileMenu._profiles

                                // The roles of the row are in the context of
                                // the delegate: required properties are not
                                // set on an Action.
                                delegate: T.Action {
                                    readonly property int row: index

                                    text: model.name
                                    checkable: true
                                    checked: profileMenu._profiles.selectedProfile === row
                                    onTriggered: profileMenu._profiles.selectedProfile = row
                                }

                                onObjectAdded: (index, object) => profileMenu.insertAction(index, object)
                                onObjectRemoved: (index, object) => profileMenu.removeAction(object)
                            }
                        }

                        T.Action {
                            text: qsTr("Keyboard Shortcuts")
                            icon.source: contextMenu._icons + "hotkeys-two-tone.svg"
                            onTriggered: DialogsProvider.showRedesignShortcuts()
                        }

                        T.Action {
                            text: qsTr("Customize Player")
                            icon.source: contextMenu._icons + "paint-two-tone.svg"
                            onTriggered: DialogsProvider.showToolbarEditorDialog()
                        }

                        T.Action {
                            property string shortcutText: "Ctrl + P"
                            text: qsTr("Settings")
                            icon.source: contextMenu._icons + "settings-two-tone.svg"
                            onTriggered: DialogsProvider.prefsDialog()
                        }

                        T.Action {
                            property string shortcutText: "Shift + F1"
                            text: qsTr("About VLC")
                            icon.source: contextMenu._icons + "info-two-tone.svg"
                            onTriggered: DialogsProvider.aboutDialog()
                        }
                    }

                    Connections {
                        target: root

                        function onForceUnlock() {
                            contextMenu.close()
                        }
                    }
                }

                Item {
                    id: menuSpacer

                    width: menuSelector.visible ? VLCStyle.dp(10, VLCStyle.scale) : 0
                    height: 1
                }

                Widgets.IconToolButton {
                    id: backBtn

                    anchors.verticalCenter: parent.verticalCenter

                    objectName: "IconToolButton"
                    font.pixelSize: VLCStyle.icon_normal
                    padding: VLCStyle.margin_xxxsmall

                    text: VLCIcons.panel_left
                    description: qsTr("Library")

                    AccessibleCompat.id: "topBarBackButton"

                    focus: true

                    Navigation.parentItem: root
                    Navigation.leftItem: menuSelector.visible ? menuSelector : null
                    Navigation.rightItem: folderBtn.visible ? folderBtn : fullscreenLoader.item
                    onClicked: root.backRequested()

                    onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
                }

                Widgets.IconLabel {
                    id: divider

                    anchors.verticalCenter: parent.verticalCenter

                    visible: folderBtn.visible

                    text: VLCIcons.divider
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.separator
                }

                T.AbstractButton {
                    // What the current media is part of: the way back to the
                    // rest of it.
                    id: folderBtn

                    anchors.verticalCenter: parent.verticalCenter

                    visible: (text !== "")

                    text: root._folderName

                    padding: 0
                    rightPadding: VLCStyle.margin_xxsmall

                    implicitWidth: implicitContentWidth + leftPadding + rightPadding
                    implicitHeight: implicitContentHeight + topPadding + bottomPadding

                    Accessible.name: qsTr("Library, %1").arg(text)
                    AccessibleCompat.id: "topBarFolderButton"

                    Navigation.parentItem: root
                    Navigation.leftItem: backBtn
                    Navigation.rightItem: fullscreenLoader.item

                    Keys.priority: Keys.AfterItem
                    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                    onClicked: root.backRequested()

                    onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

                    readonly property ColorContext colorContext: ColorContext {
                        id: folderTheme

                        colorSet: ColorContext.ToolButton

                        focused: folderBtn.visualFocus
                        hovered: folderBtn.hovered
                        pressed: folderBtn.down
                    }

                    background: Widgets.AnimatedBackground {
                        enabled: folderTheme.initialized

                        radius: VLCStyle.dp(6, VLCStyle.scale)

                        color: folderTheme.bg.primary

                        border.color: folderBtn.visualFocus ? folderTheme.visualFocus : "transparent"
                    }

                    contentItem: Row {
                        spacing: VLCStyle.margin_xxsmall

                        Widgets.IconLabel {
                            anchors.verticalCenter: parent.verticalCenter

                            width: VLCStyle.dp(28, VLCStyle.scale)
                            height: width

                            text: VLCIcons.folder
                            font.pixelSize: VLCStyle.icon_normal
                            color: folderTheme.fg.primary
                        }

                        T.Label {
                            anchors.verticalCenter: parent.verticalCenter

                            text: folderBtn.text
                            font.pixelSize: VLCStyle.dp(14, VLCStyle.scale)
                            color: folderTheme.fg.primary
                        }
                    }
                }
            }
        }

        ResumeDialog {
            id: resumeDialog

            anchors.fill: parent
            //add aditional margin so it align with menubar text when visible (see MenuBar.qml)
            anchors.leftMargin: VLCStyle.margin_xsmall

            maxWidth: ((root.showCSD && !root.pinControls) ? csdDecorations : playlistGroup).x
                - VLCStyle.applicationHorizontalMargin
                - VLCStyle.margin_large

            colorContext.palette: theme.palette

            Navigation.parentItem: rootPlayer

            onHidden: {
                if (activeFocus) {
                    backBtn.forceActiveFocus()
                }
            }

            onVisibleChanged: {
                root.requestLockUnlockAutoHide(visible)
            }
        }
    }

    //FIXME use the the right class
    T.Label {
        id: centerTitleText

        readonly property int _leftLimit: logoOrResume.x + logoOrResume.width
        readonly property int _rightLimit: playlistGroup.x
        readonly property int _availableWidth: _rightLimit - _leftLimit
        readonly property int _centerX: ((root.width - centerTitleText.implicitWidth) / 2)
        readonly property bool _alignHCenter: _centerX > _leftLimit
                                              && _centerX + centerTitleText.implicitWidth < _rightLimit

        visible: (_showCenterText && root.resumeVisible === false)

        enabled: visible

        width: Math.min(centerTitleText._availableWidth, centerTitleText.implicitWidth)

        leftPadding: VLCStyle.margin_small
        rightPadding: VLCStyle.margin_small

        text: root.title
        color: theme.fg.primary
        font.pixelSize: VLCStyle.dp(13, VLCStyle.scale)
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter

        on_AlignHCenterChanged: _layout()
        Component.onCompleted: _layout()

        function _layout() {
            if (_alignHCenter) {
                centerTitleText.x = 0
                centerTitleText.anchors.horizontalCenter = root.horizontalCenter
            } else {
                centerTitleText.anchors.horizontalCenter = undefined
                centerTitleText.x = Qt.binding(function() { return centerTitleText._leftLimit })
            }
        }
    }

    //FIXME use the the right class
    T.Label {
        id: leftTitleText

        anchors.left: parent.left
        anchors.top: logoOrResume.bottom
        anchors.leftMargin: root._sideMargin

        width: root.textWidth - VLCStyle.margin_normal

        visible: !root.pinControls

        enabled: visible

        topPadding: VLCStyle.margin_large
        leftPadding: logo.x

        text: root.title
        horizontalAlignment: Text.AlignLeft
        color: theme.fg.primary
        font.weight: Font.DemiBold
        font.pixelSize: VLCStyle.dp(18, VLCStyle.scale)
        elide: Text.ElideRight
    }

    Loader {
        id: csdDecorations

        anchors.top: parent.top
        anchors.right: parent.right

        focus: false
        height: VLCStyle.icon_normal
        active: root.showCSD
        enabled: root.showCSD
        visible: root.showCSD
        source:  VLCStyle.palette.hasCSDImage
            ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
            : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"

        onLoaded: {
            if (item.hasOwnProperty("beforeClose"))
                item.beforeClose = fullscreenComponent
        }

        Connections {
            target: csdDecorations.item
            enabled: csdDecorations.status === Loader.Ready
            function onButtonHoveredChanged() { root.requestLockUnlockAutoHide(csdDecorations.item.buttonHovered) }
        }
    }

    Row {
        id: playlistGroup

        property int extraRightMargin: 0

        focus: true
        spacing: VLCStyle.margin_xxsmall

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: root._sideMargin + extraRightMargin

        visible: root._showTopBar

        Loader {
            id: fullscreenLoader

            anchors.verticalCenter: parent.verticalCenter

            // It is among the window buttons when there are any.
            active: !root._fullscreenInCSD

            sourceComponent: fullscreenComponent
        }
    }
}
