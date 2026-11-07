// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs
import VLC.Playlist
import VLC.Util

// The library of the redesign as a sidebar over the player (Figma
// "sidebar", 848:1996, redesign/design/sidebar.png): a rail of the parts
// of the library, and a page with its path, what it holds, how it is
// sorted and shown, and a search. A click plays a media or opens what
// holds others; a right click opens the menu of a file, a folder or a
// playlist (Figma 2404:13340, 2139:8935, 2459:9389).
Rectangle {
    id: root

    // Asks to go to the whole library
    signal popOutRequested()

    readonly property RedesignTheme theme: RedesignTheme {
        scaleFactor: VLCStyle.scale
        lightTheme: !VLCStyle.palette.isDark
        accentColor: MainCtx.redesignAccent
    }
    readonly property string _icons: "qrc:///redesign/menu/"

    function _dp(value: real) : real { return VLCStyle.dp(value, VLCStyle.scale) }

    // The pages that were seen, to go back and forth: { kind, title,
    // parentId, path }
    property var _history: [{ kind: "home", title: qsTr("Home"), path: [qsTr("Home")] }]
    property int _at: 0
    readonly property var page: _history[_at]

    property bool _grid: false
    property bool _searching: false

    function go(kind: string, title: string, parentId) {
        // Music ▸ Albums ▸ An album: a step further down the path
        const path = page.path.concat([title])
        // The id of the parent is kept as text: an MLItemId does not keep
        // its type in a list of JavaScript.
        const parentKey = (parentId !== undefined) ? parentId.toString() : undefined
        _history = _history.slice(0, _at + 1).concat([{ kind: kind, title: title, parentKey: parentKey, path: path }])
        _at = _history.length - 1
        _searching = false
    }

    function section(kind: string, title: string) {
        _history = _history.slice(0, _at + 1).concat([{ kind: kind, title: title, path: [title] }])
        _at = _history.length - 1
        _searching = false
    }

    color: theme.background

    // The rail
    Rectangle {
        id: rail

        width: root._dp(50)
        height: parent.height
        color: theme.field

        Column {
            y: root._dp(14)
            width: parent.width
            spacing: root._dp(20)

            Repeater {
                model: [
                    { kind: "home", title: qsTr("Home"), icon: "home", active: "home-active" },
                    { kind: "videos", title: qsTr("Videos"), icon: "videos", active: "videos-active" },
                    { kind: "music", title: qsTr("Music"), icon: "songs", active: "songs-active" },
                    { kind: "network", title: qsTr("Network"), icon: "streaming-two-tone", active: "streaming-active" },
                    { kind: "playlists", title: qsTr("Playlists"), icon: "playlist-two-tone", active: "playlist-active" },
                    { kind: "recent", title: qsTr("Recent"), icon: "recent-two-tone", active: "recent-two-tone" }
                ]

                T.AbstractButton {
                    id: railButton
                    required property var modelData
                    readonly property bool current: root.page.path[0] === modelData.title
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root._dp(32); height: width
                    text: modelData.title
                    Accessible.name: text
                    onClicked: root.section(modelData.kind, modelData.title)

                    background: Rectangle {
                        radius: root._dp(6)
                        color: railButton.hovered ? theme.hover : "transparent"
                    }
                    contentItem: Image {
                        anchors.centerIn: parent
                        width: root._dp(24); height: width
                        sourceSize: Qt.size(width, height)
                        source: root._icons + (railButton.current ? railButton.modelData.active
                                                                  : railButton.modelData.icon) + ".svg"
                    }
                }
            }

            // Add a folder to the library
            T.AbstractButton {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root._dp(32); height: width
                text: qsTr("Add a folder")
                Accessible.name: text
                onClicked: root._addFolder()
                contentItem: Widgets.IconLabel {
                    anchors.centerIn: parent
                    text: VLCIcons.add
                    font.pixelSize: VLCStyle.icon_normal
                    color: theme.foreground
                }
            }
        }
    }

    // The page
    Item {
        id: pagePane

        x: rail.width
        width: parent.width - x
        height: parent.height

        // Back, forth, where, its menu, and the whole library
        Item {
            id: header
            width: parent.width; height: root._dp(60)

            Row {
                x: root._dp(18)
                anchors.verticalCenter: parent.verticalCenter
                spacing: root._dp(12)

                Widgets.IconToolButton {
                    text: VLCIcons.back
                    description: qsTr("Back")
                    enabled: root._at > 0
                    onClicked: root._at--
                }
                Widgets.IconToolButton {
                    text: VLCIcons.arrow_right
                    description: qsTr("Forward")
                    enabled: root._at < root._history.length - 1
                    onClicked: root._at++
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: header.width - root._dp(190)
                    elide: Text.ElideLeft
                    // "… ▸ Shows ▸ The Wand": the last two steps of the path
                    text: {
                        const path = root.page.path
                        const shown = path.slice(-2).join("  ▸  ")
                        return path.length > 2 ? "…  ▸  " + shown : shown
                    }
                    color: theme.bright
                    font.pixelSize: root._dp(16)
                }
            }

            Row {
                anchors.right: parent.right; anchors.rightMargin: root._dp(14)
                anchors.verticalCenter: parent.verticalCenter
                spacing: root._dp(8)

                Widgets.IconToolButton {
                    id: moreButton
                    text: VLCIcons.more
                    description: qsTr("More")
                    onClicked: pageMenu.popup(moreButton, 0, moreButton.height)
                }
                Widgets.IconToolButton {
                    text: VLCIcons.open
                    description: qsTr("Open the library")
                    onClicked: root.popOutRequested()
                }
            }
        }

        // What it holds, sorting, view, search
        Item {
            id: toolbar
            y: header.height
            width: parent.width; height: root._dp(46)

            Text {
                x: root._dp(20)
                anchors.verticalCenter: parent.verticalCenter
                visible: !root._searching && content.listModel !== null
                text: {
                    const count = content.listModel ? content.listModel.count : 0
                    return count === 1 ? qsTr("1 item") : qsTr("%1 items").arg(count)
                }
                color: theme.foreground
                font.pixelSize: root._dp(14)
            }

            T.TextField {
                id: searchField
                x: root._dp(16)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - root._dp(150)
                height: root._dp(30)
                visible: root._searching
                leftPadding: root._dp(8)
                color: theme.bright
                font.pixelSize: root._dp(14)
                placeholderText: qsTr("Search")
                placeholderTextColor: theme.foreground
                background: Rectangle { radius: root._dp(4); color: theme.field; border.color: theme.accent; border.width: 1 }
                onTextChanged: if (content.listModel && content.listModel.searchPattern !== undefined)
                                   content.listModel.searchPattern = text
                Keys.onEscapePressed: root._searching = false
            }

            Row {
                anchors.right: parent.right; anchors.rightMargin: root._dp(14)
                anchors.verticalCenter: parent.verticalCenter
                spacing: root._dp(8)

                Widgets.IconToolButton {
                    id: sortButton
                    text: VLCIcons.sort
                    description: qsTr("Sort")
                    enabled: content.listModel?.sortCriteria !== undefined
                    onClicked: sortMenu.popup(sortButton, 0, sortButton.height)
                }
                Widgets.IconToolButton {
                    text: root._grid ? VLCIcons.list : VLCIcons.grid
                    description: root._grid ? qsTr("List") : qsTr("Grid")
                    onClicked: root._grid = !root._grid
                }
                Widgets.IconToolButton {
                    text: VLCIcons.search
                    description: qsTr("Search")
                    onClicked: {
                        root._searching = !root._searching
                        if (root._searching)
                            searchField.forceActiveFocus()
                        else
                            searchField.clear()
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                x: root._dp(18); width: parent.width - 2 * x; height: 1
                color: theme.border
                opacity: 0.6
            }
        }

        Loader {
            id: content

            y: toolbar.y + toolbar.height + root._dp(8)
            width: parent.width
            height: parent.height - y

            // The model of the page, to count, sort and search
            readonly property var listModel: item?.listModel ?? null

            sourceComponent: root.page.kind === "home" ? homePage : listPage
        }
    }

    // The library's models, made for the page that needs them
    Component { id: videoFolders; MLVideoFoldersModel { ml: MediaLib } }
    Component { id: videos; MLVideoModel { ml: MediaLib } }
    Component { id: songs; MLAudioModel { ml: MediaLib } }
    Component { id: albums; MLAlbumModel { ml: MediaLib } }
    Component { id: artists; MLArtistModel { ml: MediaLib } }
    Component { id: genres; MLGenreModel { ml: MediaLib } }
    Component { id: playlists; MLPlaylistListModel { ml: MediaLib } }
    Component { id: playlistMedia; MLPlaylistModel { ml: MediaLib } }
    Component { id: recent; MLRecentMediaModel { ml: MediaLib } }
    Component { id: sources; NetworkSourcesModel { ctx: MainCtx } }

    // A page and what it lists: [model component, kind of its rows, the
    // fixed rows before them]. Rows: "media" plays, "folder", "album",
    // "artist", "genre", "playlist" and "source" open.
    function _pageSpec(kind: string) : var {
        switch (kind) {
        case "videos": return [videoFolders, "folder", [{ action: "addFolder", title: qsTr("Add"), icon: "add" }]]
        case "folder": return [videos, "media", []]
        case "music": return [null, "", [
            { action: "songs", title: qsTr("Songs"), icon: "songs" },
            { action: "albums", title: qsTr("Albums"), icon: "album" },
            { action: "artists", title: qsTr("Artists"), icon: "artist" },
            { action: "genres", title: qsTr("Genres"), icon: "genre-two-tone" }]]
        case "songs": return [songs, "media", []]
        case "albums": return [albums, "album", []]
        case "artists": return [artists, "artist", []]
        case "genres": return [genres, "genre", []]
        case "album": case "artist": case "genre": return [songs, "media", []]
        case "network": return [sources, "source", [{ action: "addStream", title: qsTr("Add Network Stream"), icon: "add" }]]
        case "playlists": return [playlists, "playlist", [{ action: "createPlaylist", title: qsTr("Create playlist"), icon: "add" }]]
        case "playlist": return [playlistMedia, "media", []]
        case "recent": return [recent, "media", []]
        }
        return [null, "", []]
    }

    function _fixedAction(action: string) {
        switch (action) {
        case "addFolder": _addFolder(); break
        case "addStream": DialogsProvider.openNetDialog(); break
        case "createPlaylist": DialogsProvider.showRedesignNewPlaylist(); break
        case "songs": go("songs", qsTr("Songs")); break
        case "albums": go("albums", qsTr("Albums")); break
        case "artists": go("artists", qsTr("Artists")); break
        case "genres": go("genres", qsTr("Genres")); break
        }
    }

    // Opens a row that holds others, or plays a media
    function _open(rowKind: string, data) {
        const title = data.title || data.name || ""
        switch (rowKind) {
        case "media": MediaLib.addAndPlay([data.id]); break
        case "folder": go("folder", title, data.id); break
        case "album": go("album", title, data.id); break
        case "artist": go("artist", title, data.id); break
        case "genre": go("genre", title, data.id); break
        case "playlist": go("playlist", title, data.id); break
        case "source":
            // Network sources are browsed in the whole library.
            root.popOutRequested()
            History.push(["network"])
            break
        }
    }

    readonly property var _folderModel: MLFolderModel { ctx: MainCtx }

    function _addFolder() {
        const store = Qt.createQmlObject("import VLC.MainInterface; import VLC.Dialogs; RedesignPreferences { ctx: MainCtx }", root, "sidebarStore")
        const folder = store.chooseFolder("")
        store.destroy()
        if (folder.length > 0)
            _folderModel.add(folder.includes("://") ? folder : "file://" + folder)
    }

    // Home: what the library has, a few of each, and the way to all of it
    Component {
        id: homePage

        Flickable {
            readonly property var listModel: null
            contentHeight: homeColumn.height + root._dp(20)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: homeColumn
                x: root._dp(20)
                width: parent.width - 2 * x
                spacing: root._dp(6)

                HomeSection { title: qsTr("Continue Watching"); kind: "media"; more: "recent"; model: MLRecentVideoModel { ml: MediaLib; limit: 3 } }
                HomeSection { title: qsTr("Listen Again"); kind: "media"; more: "songs"; model: MLRecentMediaModel { ml: MediaLib; limit: 3 } }
                HomeSection { title: qsTr("Folders"); kind: "folder"; more: "videos"; model: MLVideoFoldersModel { ml: MediaLib; limit: 3 } }
                HomeSection { title: qsTr("Playlists"); kind: "playlist"; more: "playlists"; model: MLPlaylistListModel { ml: MediaLib; limit: 3 } }
                HomeSection { title: qsTr("Artists"); kind: "artist"; more: "artists"; model: MLArtistModel { ml: MediaLib; limit: 3 } }
            }
        }
    }

    component HomeSection: Column {
        id: homeSection
        property string title
        property string kind
        property string more
        property var model
        width: parent.width
        visible: (model?.count ?? 0) > 0
        spacing: root._dp(4)

        T.AbstractButton {
            width: parent.width; height: root._dp(48)
            text: homeSection.title
            onClicked: {
                const titles = { recent: qsTr("Recent"), songs: qsTr("Songs"), videos: qsTr("Videos"),
                                 playlists: qsTr("Playlists"), artists: qsTr("Artists") }
                root.section(homeSection.more, titles[homeSection.more])
            }
            contentItem: Item {
                Text { anchors.verticalCenter: parent.verticalCenter; text: homeSection.title; color: theme.bright; font.pixelSize: root._dp(16) }
                Widgets.IconLabel { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: VLCIcons.ic_fluent_chevron_right_24; color: theme.foreground; font.pixelSize: VLCStyle.icon_small }
            }
        }

        Repeater {
            model: homeSection.model
            Row_ { width: homeSection.width; rowKind: homeSection.kind; sourceModel: homeSection.model }
        }
    }

    // A list page: its fixed rows, then those of its model
    Component {
        id: listPage

        Item {
            id: listItem

            readonly property var spec: root._pageSpec(root.page.kind)
            readonly property var listModel: modelLoader.item

            Loader {
                id: modelLoader
                sourceComponent: listItem.spec[0]
                onLoaded: {
                    if (root.page.parentKey !== undefined && item.parentId !== undefined)
                        item.parentId = MediaLib.deserializeMlItemIdFromString(root.page.parentKey)
                }
            }

            GridView {
                id: grid
                anchors.fill: parent
                anchors.leftMargin: root._dp(14)
                anchors.rightMargin: root._dp(10)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: root._grid ? Math.floor(width / 2) : width
                cellHeight: root._grid ? root._dp(150) : root._dp(42)
                model: listItem.listModel

                header: Column {
                    width: grid.width
                    Repeater {
                        model: listItem.spec[2]
                        Row_ {
                            required property var modelData
                            index: 0
                            model: modelData
                            width: grid.width
                            fixed: modelData
                            rowKind: "fixed"
                        }
                    }
                }

                delegate: Row_ { width: grid.cellWidth; height: grid.cellHeight; rowKind: listItem.spec[1]; tile: root._grid; sourceModel: listItem.listModel }
            }
        }
    }

    // A row: a picture or an icon, and a name
    component Row_: T.AbstractButton {
        id: row

        required property var model
        required property int index

        property string rowKind
        property var fixed: null
        property bool tile: false
        // The list the row is in, for what its menu changes there
        property var sourceModel: null
        // The data of the row, from its model
        readonly property var _data: fixed ?? model
        readonly property string _image: String(_data.thumbnail ?? _data.cover ?? _data.small_cover ?? "")

        height: root._dp(42)
        text: _data.title || _data.name || ""
        Accessible.name: text

        function activate() {
            if (fixed)
                root._fixedAction(fixed.action)
            else
                root._open(rowKind, _data)
        }

        // The left button opens; the button itself would take the right
        // one too, which is for the menu.
        Accessible.onPressAction: activate()
        Keys.onReturnPressed: activate()

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: row.activate()
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            enabled: !row.fixed
            onTapped: (eventPoint) => root._contextMenu(row.rowKind, row._data, row.sourceModel, row.index, row, eventPoint.position)
        }

        background: Rectangle {
            radius: root._dp(4)
            color: row.hovered ? theme.hover : "transparent"
        }

        contentItem: Item {
            Image {
                id: picture
                x: root._dp(6)
                y: row.tile ? root._dp(6) : (parent.height - height) / 2
                width: row.tile ? parent.width - root._dp(12) : root._dp(32)
                height: row.tile ? parent.height - root._dp(40) : root._dp(32)
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(width * 2, height * 2)
                // The icon instead when there is no picture or it does not load
                visible: row._image.length > 0 && !row.fixed && status !== Image.Error
                source: row._image.length > 0 ? VLCAccessImage.uri(row._image) : ""
                asynchronous: true
            }
            Image {
                x: row.tile ? (parent.width - width) / 2 : root._dp(10)
                y: row.tile ? root._dp(40) : (parent.height - height) / 2
                width: root._dp(24); height: width
                sourceSize: Qt.size(width, height)
                visible: !picture.visible
                source: {
                    if (row.fixed)
                        return root._icons + (row.fixed.icon === "add" ? "add.svg" : row.fixed.icon + ".svg")
                    const icons = { media: "file-two-tone", folder: "folder-two-tone", album: "album", artist: "artist",
                                    genre: "genre-two-tone", playlist: "playlist-two-tone", source: "streaming-two-tone" }
                    return root._icons + (icons[row.rowKind] ?? "file-two-tone") + ".svg"
                }
            }
            Text {
                x: row.tile ? root._dp(6) : root._dp(48)
                y: row.tile ? parent.height - root._dp(28) : (parent.height - height) / 2
                width: parent.width - x - root._dp(6)
                text: row.text
                elide: Text.ElideRight
                color: row.hovered ? theme.bright : theme.foreground
                font.pixelSize: root._dp(15)
            }
        }
    }

    // The menus of a file, a folder and a playlist, as in the design
    property var _menuData: null
    property string _menuKind: ""
    property var _menuModel: null
    property int _menuIndex: -1

    function _contextMenu(rowKind: string, data, sourceModel, index: int, item, position) {
        _menuData = data
        _menuKind = rowKind
        _menuModel = sourceModel
        _menuIndex = index
        const point = item.mapToItem(root, position.x, position.y)
        const menu = rowKind === "media" ? fileMenu : (rowKind === "playlist" ? playlistMenu
                     : (rowKind === "folder" ? folderMenu : null))
        if (menu)
            menu.popup(root, point.x, point.y)
    }

    function _menuIds() : var { return _menuData ? [_menuData.id] : [] }

    RedesignMenu {
        id: fileMenu
        dark: !root.theme.lightTheme

        T.Action { text: qsTr("Play"); icon.source: root._icons + "playback-two-tone.svg"; onTriggered: MediaLib.addAndPlay(root._menuIds()) }
        // Watched and favorite are changed through the list of the row, for
        // the lists that know them.
        T.Action {
            text: (root._menuData?.playcount ?? 0) > 0 ? qsTr("Mark as Unwatched") : qsTr("Mark as Watched")
            icon.source: root._icons + "check-selected-two-tone.svg"
            enabled: typeof root._menuModel?.setItemPlayed === "function"
            onTriggered: root._menuModel.setItemPlayed(root._menuModel.index(root._menuIndex, 0),
                                                       !((root._menuData?.playcount ?? 0) > 0))
        }
        T.Action {
            text: root._menuData?.isFavorite ? qsTr("Remove from Favorites") : qsTr("Favorite")
            icon.source: root._icons + "favorite-two-tone.svg"
            enabled: typeof root._menuModel?.setMediaIsFavorite === "function"
            onTriggered: root._menuModel.setMediaIsFavorite(root._menuModel.index(root._menuIndex, 0),
                                                            !root._menuData?.isFavorite)
        }
        T.Action {
            text: qsTr("Stream")
            icon.source: root._icons + "streaming-two-tone.svg"
            enabled: !!root._menuData?.mrl
            onTriggered: DialogsProvider.streamingDialog([root._menuData.mrl], true)
        }
        T.Action {
            text: qsTr("Convert")
            icon.source: root._icons + "swap-two-tone.svg"
            enabled: !!root._menuData?.mrl
            onTriggered: DialogsProvider.streamingDialog([root._menuData.mrl], false)
        }
        T.Action { text: qsTr("Add to Queue"); icon.source: root._icons + "queue-two-tone.svg"; onTriggered: MediaLib.addToPlaylist(root._menuIds()) }
        T.Action { text: qsTr("Add to Playlist"); icon.source: root._icons + "playlist-two-tone.svg"; onTriggered: DialogsProvider.playlistsDialog(root._menuIds()) }
        T.Action {
            text: qsTr("Show in File Explorer")
            icon.source: root._icons + "folder-two-tone.svg"
            enabled: String(root._menuData?.mrl ?? "").startsWith("file://")
            onTriggered: {
                const mrl = String(root._menuData.mrl)
                Qt.openUrlExternally(mrl.substring(0, mrl.lastIndexOf("/")))
            }
        }
        T.Action { property bool divider: true; text: qsTr("Properties & Metadata"); icon.source: root._icons + "info-two-tone.svg"; onTriggered: DialogsProvider.mediaInfoDialog(root._menuData.id) }
    }

    RedesignMenu {
        id: folderMenu
        dark: !root.theme.lightTheme

        T.Action { text: qsTr("Play"); icon.source: root._icons + "playback-two-tone.svg"; onTriggered: MediaLib.addAndPlay(root._menuIds()) }
        T.Action { text: qsTr("Add to Queue"); icon.source: root._icons + "queue-two-tone.svg"; onTriggered: MediaLib.addToPlaylist(root._menuIds()) }
        T.Action { text: qsTr("Add Folder"); icon.source: root._icons + "new-folder-two-tone.svg"; onTriggered: root._addFolder() }
        T.Action { text: qsTr("Resync"); icon.source: root._icons + "refresh-two-tone.svg"; onTriggered: MediaLib.reload() }
    }

    RedesignMenu {
        id: playlistMenu
        dark: !root.theme.lightTheme

        T.Action { text: qsTr("Play"); icon.source: root._icons + "playback-two-tone.svg"; onTriggered: MediaLib.addAndPlay(root._menuIds()) }
        T.Action {
            text: qsTr("Shuffle")
            icon.source: root._icons + "shuffle-right-two-tone.svg"
            onTriggered: {
                MainPlaylistController.random = true
                MediaLib.addAndPlay(root._menuIds())
            }
        }
        T.Action { text: qsTr("Add to Queue"); icon.source: root._icons + "queue-two-tone.svg"; onTriggered: MediaLib.addToPlaylist(root._menuIds()) }
        T.Action { property bool divider: true; text: qsTr("Create playlist"); icon.source: root._icons + "playlist-two-tone.svg"; onTriggered: DialogsProvider.showRedesignNewPlaylist() }
    }

    // How the page is sorted, the current way checked
    RedesignMenu {
        id: sortMenu
        dark: !root.theme.lightTheme
        entryWidth: root._dp(257)

        readonly property var _model: content.listModel

        component SortAction: T.Action {
            property string criteria
            property int order: Qt.AscendingOrder
            checkable: true
            checked: sortMenu._model?.sortCriteria === criteria && sortMenu._model?.sortOrder === order
            onTriggered: {
                sortMenu._model.sortCriteria = criteria
                sortMenu._model.sortOrder = order
            }
        }

        SortAction { text: qsTr("Title A-Z"); criteria: "title" }
        SortAction { text: qsTr("Title Z-A"); criteria: "title"; order: Qt.DescendingOrder }
        SortAction { text: qsTr("Newest First"); criteria: "insertion"; order: Qt.DescendingOrder }
        SortAction { text: qsTr("Oldest First"); criteria: "insertion" }
        SortAction { text: qsTr("Shortest First"); criteria: "duration" }
        SortAction { text: qsTr("Longest First"); criteria: "duration"; order: Qt.DescendingOrder }
    }

    // Play or queue all the page holds
    RedesignMenu {
        id: pageMenu
        dark: !root.theme.lightTheme

        function _all() : var {
            const model = content.listModel
            const ids = []
            for (let i = 0; model && i < model.count; ++i)
                ids.push(model.getDataAt(i).id)
            return ids
        }

        T.Action { text: qsTr("Play All"); icon.source: root._icons + "playback-two-tone.svg"; enabled: (content.listModel?.count ?? 0) > 0; onTriggered: MediaLib.addAndPlay(pageMenu._all()) }
        T.Action { text: qsTr("Add All to Queue"); icon.source: root._icons + "queue-two-tone.svg"; enabled: (content.listModel?.count ?? 0) > 0; onTriggered: MediaLib.addToPlaylist(pageMenu._all()) }
        T.Action { property bool divider: true; text: qsTr("Resync"); icon.source: root._icons + "refresh-two-tone.svg"; onTriggered: MediaLib.reload() }
    }
}
