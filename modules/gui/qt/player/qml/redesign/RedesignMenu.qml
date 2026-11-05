// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Templates as T

import VLC.Style

// A menu as the redesign draws them (Figma "right-click menu", 6065:13616,
// redesign/design/right-click-menu.png): rows of a two-tone icon, a text,
// and either a shortcut or an arrow to a submenu.
//
// Entries are T.Action: `icon.source` is the icon, and two properties that
// an Action can declare are read when present:
//   property string shortcutText  shown at the right, nothing more: the
//                                 shortcut itself is handled elsewhere
//   property bool divider         a line above the entry
//   property bool arrow           the arrow of a submenu, for an entry that
//                                 opens something else, such as a panel
// A checkable Action that is checked shows a check mark at the right.
// A submenu is another RedesignMenu, with `title`, `iconSource` and
// `divider`.
T.Menu {
    id: root

    property bool dark: true

    // The width of the rows, without the padding of the menu: 284 in the
    // menu of the video, 367 in the main menu (Figma 6062:13354).
    property real entryWidth: _dp(284)

    // The icon of this menu where it is an entry of another one
    property url iconSource
    // A line above this menu where it is an entry of another one
    property bool divider: false

    readonly property color backgroundColor: dark ? "#191919" : "#E7E7E7"
    readonly property color textColor: dark ? "#8F8F8F" : "#3C3C3C"
    readonly property color shortcutColor: dark ? "#6B6B6B" : "#7A7A7A"
    readonly property color disabledColor: dark ? "#4A4A4A" : "#ABABAB"
    readonly property color dividerColor: dark ? "#1D1D1D" : "#D5D5D5"
    readonly property color highlightColor: dark ? "#222222" : "#DCDCDC"

    function _dp(value: real) : real {
        return VLCStyle.dp(value, VLCStyle.scale)
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    // The keys move in the menu, they are not hotkeys of the player while
    // it is open.
    focus: true

    // Every time it opens, nothing is highlighted until the pointer or a
    // key goes to an entry.
    onAboutToShow: currentIndex = -1

    padding: _dp(4)
    margins: 0
    // A submenu starts at the edge of the rows of its menu, over its padding.
    overlap: _dp(4)
    cascade: true

    delegate: T.MenuItem {
        id: item

        readonly property var _entry: subMenu ?? action
        readonly property bool _divider: _entry?.divider ?? false
        readonly property string _shortcutText: action?.shortcutText ?? ""
        readonly property bool _arrow: !!subMenu || (action?.arrow ?? false)
        readonly property bool _check: !subMenu && checkable && checked

        implicitWidth: root.entryWidth
        implicitHeight: root._dp(48) + topPadding

        // The line above the entry takes one pixel, as in the design.
        topPadding: _divider ? 1 : 0
        leftPadding: 0
        rightPadding: 0
        bottomPadding: 0

        hoverEnabled: true

        icon.source: subMenu ? subMenu.iconSource : (action?.icon.source ?? "")

        Accessible.name: text

        contentItem: Item {
            Image {
                x: root._dp(14)
                anchors.verticalCenter: parent.verticalCenter

                width: root._dp(24)
                height: width
                sourceSize: Qt.size(width, height)

                source: item.icon.source
                opacity: item.enabled ? 1.0 : 0.4
            }

            Text {
                x: root._dp(48)
                anchors.verticalCenter: parent.verticalCenter
                width: (shortcut.visible ? (shortcut.x - root._dp(8))
                                         : (parent.width - root._dp(48)))
                       - x

                text: item.text
                textFormat: Text.PlainText
                elide: Text.ElideRight

                font.pixelSize: root._dp(14)
                color: item.enabled ? root.textColor : root.disabledColor
            }

            Text {
                id: shortcut

                anchors.right: parent.right
                anchors.rightMargin: root._dp(14)
                anchors.verticalCenter: parent.verticalCenter

                visible: !item._arrow && !item._check && text.length > 0

                text: item._shortcutText
                textFormat: Text.PlainText

                font.pixelSize: root._dp(14)
                color: item.enabled ? root.shortcutColor : root.disabledColor
            }
        }

        indicator: Image {
            x: item.width - root._dp(14) - width
            y: item.topPadding + (item.availableHeight - height) / 2

            width: root._dp(24)
            height: width
            sourceSize: Qt.size(width, height)

            visible: item._check
            source: "qrc:///redesign/menu/check-active.svg"
        }

        arrow: Image {
            x: item.width - root._dp(14) - width
            y: item.topPadding + (item.availableHeight - height) / 2

            width: root._dp(24)
            height: width
            sourceSize: Qt.size(width, height)

            visible: item._arrow
            source: "qrc:///redesign/menu/chevron-right.svg"
        }

        background: Item {
            Rectangle {
                width: parent.width
                height: 1
                visible: item._divider
                color: root.dividerColor
            }

            Rectangle {
                y: item.topPadding
                width: parent.width
                height: parent.height - y
                radius: root._dp(6)
                color: item.highlighted ? root.highlightColor : "transparent"
            }
        }
    }

    contentItem: ListView {
        implicitHeight: contentHeight
        model: root.contentModel
        interactive: Window.window ? (contentHeight + root.topPadding + root.bottomPadding > Window.window.height)
                                   : false
        clip: true
        currentIndex: root.currentIndex
        boundsBehavior: Flickable.StopAtBounds
    }

    background: Rectangle {
        implicitWidth: root.entryWidth + root.leftPadding + root.rightPadding
        radius: root._dp(10)
        color: root.backgroundColor
    }
}
