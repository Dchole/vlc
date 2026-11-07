// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.Dialogs

// Presets for a show (Figma, "Setting Preset", 2372:8834): the speed, the
// audio and subtitle delays and the chosen audio and subtitle tracks, kept
// for the videos of a folder (the "Preset for This Show" of the Playback
// tab, SettingsPanel.qml). This gives them to each video of that folder
// when it is opened. Tracks are found again by their name.
Item {
    id: root

    visible: false

    RedesignPreferences { id: helper; ctx: MainCtx }

    property var _preset: ({})
    readonly property bool _active: _preset.rate !== undefined
    property bool _timesSet: false
    // Tracks are only chosen while the media starts, so that a track chosen
    // or added later, by Add Subtitles for one, is left alone.
    property bool _tracksOpen: false

    function _apply() {
        const url = Player.url.toString()
        _preset = url.length > 0 ? helper.showPreset(url) : ({})
        _timesSet = false
        _tracksOpen = _active
        if (_tracksOpen)
            tracksTimer.restart()
        _applyTimes()
        _applyTracks()
    }

    function _applyTimes() {
        if (!_active || _timesSet || Player.playingState === Player.PLAYING_STATE_STOPPED)
            return
        Player.rate = _preset.rate
        Player.audioDelayMS = _preset.audioDelay
        Player.subtitleDelayMS = _preset.subtitleDelay
        _timesSet = true
    }

    // Chooses the track of this name, else the one at this place in the
    // list (the name of a subtitle file's track tells the episode); none
    // for an empty name, which is how a preset says that subtitles are off.
    function _select(model, name: string, place: int, noneAllowed: bool) {
        let found = -1
        for (let i = 0; i < model.count && found < 0; ++i)
            if (name.length > 0 && model.data(model.index(i, 0), Qt.DisplayRole) === name)
                found = i
        if (found < 0 && name.length > 0 && place >= 0 && place < model.count)
            found = place
        for (let i = 0; i < model.count; ++i) {
            const index = model.index(i, 0)
            const selected = model.data(index, Qt.CheckStateRole)
            if (i === found && !selected)
                model.setData(index, true, Qt.CheckStateRole)
            else if (found < 0 && name.length === 0 && noneAllowed && selected)
                model.setData(index, false, Qt.CheckStateRole)
        }
    }

    function _applyTracks() {
        if (!_active || !_tracksOpen)
            return
        if (_preset.audioTrack)
            _select(Player.audioTracks, _preset.audioTrack, _preset.audioPlace ?? -1, false)
        _select(Player.subtitleTracks, _preset.subtitleTrack ?? "", _preset.subtitlePlace ?? -1, true)
    }

    Timer {
        id: tracksTimer
        interval: 5000
        onTriggered: root._tracksOpen = false
    }

    Connections {
        target: Player
        function onInputChanged() { root._apply() }
        function onLengthChanged() { root._applyTimes() }
        function onPlayingStateChanged() { root._applyTimes() }
    }

    Connections {
        target: Player.audioTracks
        function onCountChanged() { root._applyTracks() }
    }

    Connections {
        target: Player.subtitleTracks
        function onCountChanged() { root._applyTracks() }
    }

    Component.onCompleted: _apply()
}
