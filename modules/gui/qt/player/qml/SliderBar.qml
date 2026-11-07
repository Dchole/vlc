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

import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.MainInterface
import VLC.Dialogs

T.ProgressBar {
    id: control

    // A tall track with the played part and the handle drawn inside of it,
    // instead of a thin line with a round handle that shows up on hover.
    property bool thick: false

    // Bars for the sound rather than a bar: what plays is audio only
    readonly property bool waveform: thick && !Player.hasVideoOutput && !Player.hasChapters
                                     && Player.playingState !== Player.PLAYING_STATE_STOPPED

    readonly property real _thickInset: VLCStyle.dp(2, VLCStyle.scale)
    readonly property real _thickHandleWidth: VLCStyle.dp(8, VLCStyle.scale)
    readonly property real _thickRadius: VLCStyle.dp(4, VLCStyle.scale)

    // Right edge of the played part, the handle sits at the end of it.
    readonly property real _thickPlayedEnd: _thickInset + Math.max(_thickHandleWidth,
                                                                    visualPosition * (availableWidth - 2 * _thickInset))

    // Geometry of what is drawn on the track: chapters, played part, buffer.
    readonly property real _segmentHeight: thick ? (barHeight - 2 * _thickInset) : barHeight
    readonly property real _segmentY: thick ? _thickInset : 0
    readonly property color _playedColor: thick ? theme.bg.secondary : theme.fg.primary

    readonly property real _hoveredScalingFactor: thick ? 1.0 : 1.8
    property int barHeight: VLCStyle.dp(5, VLCStyle.scale)

    // "Show Subtitle Timeline on Seekbar", of the Playback tab of the settings
    property bool _subtitleTimeline: MainCtx.option("qt-subtitle-timeline") === true
    // The times of the subtitles of the media, in ms: [start, end, ...]
    property var _cues: []

    function _loadCues() {
        _cues = (thick && _subtitleTimeline) ? subtitleFiles.subtitleCues(Player.url.toString()) : []
    }

    RedesignPreferences { id: subtitleFiles; ctx: MainCtx }

    Connections {
        target: MainCtx
        function onOptionChanged(name) {
            if (name === "qt-subtitle-timeline") {
                control._subtitleTimeline = (MainCtx.option(name) === true)
                control._loadCues()
            }
        }
    }

    Connections {
        target: Player
        function onInputChanged() { control._loadCues() }
        function onLengthChanged() { control._loadCues() }
    }

    // A subtitle file that is added to the media, by Add Subtitles for one
    Connections {
        target: Player.subtitleTracks
        function onRowsInserted() { control._loadCues() }
        function onModelReset() { control._loadCues() }
    }


    // Whether the pointer is over the bar, and where as a fraction of its
    // width. This is for the preview of the frame at that position.
    readonly property bool pointerOver: hoverHandler.hovered
    readonly property real pointerPosition: (width > 0) ? Helpers.clamp(hoverHandler.point.position.x / width, 0., 1.)
                                                        : 0.

    readonly property real _scaledBarHeight: control.barHeight * _hoveredScalingFactor
    readonly property real _scaledY: (-control.barHeight / 2) * (control._hoveredScalingFactor - 1)

    property bool _isSeekPointsShown: true
    readonly property int _seekPointsDistance: VLCStyle.dp(2, VLCStyle.scale)
    readonly property int _seekPointsRadius: VLCStyle.dp(0.5, VLCStyle.scale)
    readonly property real _scaledSeekPointsRadius: _seekPointsRadius * _hoveredScalingFactor

    property bool _currentChapterHovered: false
    property real _tooltipPosition: (Widgets.PointingToolTipAttached.instance?.pos.x ?? 0.0) / width

    property color backgroundColor: theme.bg.primary
    property real touchHandlerMargin: VLCStyle.touchHandlerMargin

    Keys.onRightPressed: Player.jumpFwd()
    Keys.onLeftPressed: Player.jumpBwd()

    Accessible.onIncreaseAction: Player.jumpFwd()
    Accessible.onDecreaseAction: Player.jumpBwd()

    function showChapterMarks() {
        _isSeekPointsShown = true
        seekpointTimer.restart()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider

        enabled: control.enabled
        focused: control.visualFocus
        hovered: hoverHandler.hovered
    }

    Timer {
        id: seekpointTimer
        running: Player.hasChapters && !hoverHandler.hovered && _isSeekPointsShown
        interval: 3000
        onTriggered: control._isSeekPointsShown = false
    }

    // The thick bar comes with a preview of what is under the pointer, which
    // has the time on it.
    Widgets.PointingToolTipAttached.visible: control.visualFocus
                                             || (!control.thick && (hoverHandler.hovered || dragHandler.active))

    Widgets.PointingToolTipAttached.text: {
        if (!Widgets.PointingToolTipAttached.instance?.visible)
            return ""

        let _text

        const length = Player.length
        if (hoverHandler.hovered)
            _text = length.scale(Widgets.PointingToolTipAttached.instance.pos.x / control.width)
        else
            _text = Player.time

        _text = _text.formatHMS(length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)

        if (Player.hasChapters)
            _text += " - " + Player.chapters.getNameAtPosition(control._tooltipPosition)

        return _text
    }

    Widgets.PointingToolTipAttached.pos: Qt.point(hoverHandler.hovered ? Helpers.clamp(hoverHandler.point.position.x, 0, control.availableWidth)
                                                                       : (control.visualPosition * control.width), 0)

    FSM {
        id: fsm
        signal playerUpdatePosition(real position)
        signal pressControl(real position, bool forcePrecise)
        signal releaseControl(real position, bool forcePrecise)
        signal moveControl(real position, bool forcePrecise)
        signal inputChanged()

        //each signal is associated to a key, when a signal is received,
        //transitions of active state for the given key are evaluated
        signalMap: ({
            "playerUpdatePosition": fsm.playerUpdatePosition,
            "pressControl": fsm.pressControl,
            "releaseControl": fsm.releaseControl,
            "moveControl": fsm.moveControl,
            "inputChanged": fsm.inputChanged
        })

        initialState: fsmReleased

        function _setPositionFromValue(position) {
            control.value = position
        }

        function _seekToPosition(position, threshold, forcePrecise) {
            position = Helpers.clamp(position, 0., 1.)
            control.value = position
            if (!forcePrecise) {
                const chapter = Player.chapters.getClosestChapterFromPos(position, threshold)
                if (chapter !== -1) {
                    Player.chapters.selectChapter(chapter)
                    return
                }
            }
            Player.position = position
        }

        FSMState {
            id: fsmReleased

            transitions: ({
                "playerUpdatePosition": {
                    action: (position) => {
                        control.value = position
                    }
                },
                "pressControl": {
                    action: (position, forcePrecise) => {
                        control.forceActiveFocus()
                        fsm._seekToPosition(position, VLCStyle.dp(4, VLCStyle.scale) / control.width, forcePrecise)
                    },
                    target: fsmHeld
                }
            })
        }

        FSMState  {
            id: fsmHeld

            transitions: ({
                "moveControl": {
                    action: (position, forcePrecise) => {
                        fsm._seekToPosition(position, VLCStyle.dp(2, VLCStyle.scale) / control.width, forcePrecise)
                    }
                },
                "releaseControl": {
                    target: fsmReleased
                },
                "inputChanged": {
                    target: fsmHeldWrongInput
                }
            })
        }

        FSMState  {
            id: fsmHeldWrongInput

            function enter() {
                fsm._setPositionFromValue(Player.position)
            }

            transitions: ({
                "playerUpdatePosition": {
                    action: fsm._setPositionFromValue
                },
                "releaseControl": {
                    target: fsmReleased
                }
            })
        }
    }

    Connections {
        target: Player
        function onPositionChanged() {  fsm.playerUpdatePosition(Player.position) }
        function onInputChanged() {  fsm.inputChanged() }
    }

    Component.onCompleted: { value = Player.position; _loadCues() }

    implicitHeight: control.barHeight
    height: implicitHeight

    padding: 0

    //we use our own HoverHandler
    hoverEnabled: false

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: () => {
            if (hovered) {
                if(Player.hasChapters)
                    control._isSeekPointsShown = true
            } else {
                if(Player.hasChapters)
                    seekpointTimer.restart()
            }
        }
    }

    contentItem: Item {
        implicitHeight: control.implicitHeight
        implicitWidth: control.implicitWidth

        //placing the TapHandler directly in the Control doesn't work with 6.2
        TapHandler {
            acceptedButtons: Qt.LeftButton

            gesturePolicy: TapHandler.WithinBounds

            // Make it easier to tap with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0.0

            onPressedChanged: {
                if (pressed) {
                    fsm.pressControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                } else {
                    // NOTE: Point is still valid at this point.
                    fsm.releaseControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                }
            }
        }

        DragHandler {
            id: dragHandler
            acceptedButtons: Qt.LeftButton

            // Make it easier to drag with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0

            target: null
            dragThreshold: 0
            grabPermissions: PointerHandler.CanTakeOverFromAnything

            property bool filterEvents: false

            function moveControl() {
                fsm.moveControl(dragHandler.centroid.position.x / control.width,
                                dragHandler.centroid.modifiers === Qt.ShiftModifier)
            }

            onActiveChanged: {
                if (active) {
                    filterEvents = false
                    fsm.pressControl(centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                } else {
                    fsm.releaseControl( centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                }
            }

            onCentroidChanged: {
                // FIXME: Qt 6.5 use xAxis.onActiveValueChanged in the DragHandler
                if (filterEvents) {
                    Qt.callLater(dragHandler.moveControl)
                } else {
                    dragHandler.moveControl()
                    filterEvents = true
                }
            }
        }

        WheelHandler {
            orientation: Qt.Vertical | Qt.Horizontal

            acceptedDevices: PointerDevice.AllDevices

            onWheel: (wheel) => {
                wheelToVLC.qmlWheelEvent(wheel)
                wheel.accepted = true
            }
        }

        WheelToVLCConverter {
            id: wheelToVLC

            function handleVertical(steps: int) {
                if (steps > 0)
                    Player.jumpFwd()
                else
                    Player.jumpBwd()
            }

            function handleHorizontal(steps: int) {
                if (steps > 0)
                    Player.jumpBwd()
                else
                    Player.jumpFwd()
            }

            Component.onCompleted: {
                wheelUpDown.connect(wheelToVLC, wheelToVLC.handleVertical)
                wheelLeftRight.connect(wheelToVLC, wheelToVLC.handleHorizontal)
            }
        }
    }

    background: Item {
        width: control.availableWidth
        implicitHeight: control.implicitHeight
        height: implicitHeight

        Rectangle {
            id: sliderRect
            visible: control.thick || !Player.hasChapters
            color: control.backgroundColor
            anchors.fill: parent
            radius: control.thick ? VLCStyle.dp(6, VLCStyle.scale) : implicitHeight
        }

        Repeater {
            id: seekpointsRptr

            anchors.left: parent.left
            anchors.right: parent.right
            height: control.barHeight
            visible: Player.hasChapters

            model: Player.chapters
            Item {
                Rectangle {
                    id: seekpointsRect
                    readonly property real startPosition: model.startPosition ??  0.0
                    readonly property real endPosition: model.endPosition ?? 1.0

                    readonly property int _currentChapter: {
                        if (control.visualPosition < seekpointsRect.startPosition)
                            return 1
                        else if (control.visualPosition > seekpointsRect.endPosition)
                            return -1
                        return 0
                    }
                    on_CurrentChapterChanged: {
                        if(_hovered)
                            control._currentChapterHovered = _currentChapter === 0
                    }

                    readonly property bool _hovered: hoverHandler.hovered &&
                                            (hoverHandler.point.position.x > x && hoverHandler.point.position.x < x+width)

                    color: _currentChapter < 0 ? control._playedColor
                                               : (control.thick ? "transparent" : control.backgroundColor)
                    width: sliderRect.width * seekpointsRect.endPosition - x - control._seekPointsDistance
                    x: Math.max(control.thick ? control._thickInset : 0,
                                sliderRect.width * seekpointsRect.startPosition)

                    Rectangle {
                        id: progressRepRect
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: parent.radius

                        width: control.thick ? (control._thickPlayedEnd - parent.x)
                                             : (sliderRect.width * control.visualPosition - parent.x - control._seekPointsDistance)
                        visible: parent._currentChapter === 0
                        color: control._playedColor

                        // We use dynamic mutability group because time interpolation
                        // may induce rapid change:
                        // TODO: Do not use `Binding` when minimum Qt is 6.12:
                        Binding {
                            target: progressRepRect
                            property: "mutabilityGroup"
                            when: (progressRepRect.mutabilityGroup !== undefined)
                            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                                          : Item.StaticMutabilityGroup
                        }
                    }
                }

                transitions: [
                    Transition {
                        to: "*"
                        SequentialAnimation{
                            PropertyAction { targets: control; property: "_currentChapterHovered" }
                            NumberAnimation {
                                targets: [seekpointsRect, progressRepRect]; properties: "height, y, radius"
                                duration: VLCStyle.duration_short; easing.type: Easing.InSine
                            }
                        }
                    }
                ]

                states:[
                    State {
                        name: "visible"
                        PropertyChanges {
                            target: control;
                            _currentChapterHovered: seekpointsRect._currentChapter === 0 ? false : control._currentChapterHovered
                        }
                        PropertyChanges { target: seekpointsRect; height: control._segmentHeight }
                        PropertyChanges { target: seekpointsRect; y: control._segmentY }
                        PropertyChanges { target: seekpointsRect; radius: control.thick ? control._thickRadius : control._seekPointsRadius }
                    },
                    State {
                        name: "visibleLarge"
                        PropertyChanges {
                            target: control;
                            _currentChapterHovered: seekpointsRect._currentChapter === 0 ? true : control._currentChapterHovered
                        }
                        PropertyChanges { target: seekpointsRect; height: control.thick ? control._segmentHeight : control._scaledBarHeight }
                        PropertyChanges { target: seekpointsRect; y: control.thick ? control._segmentY : control._scaledY }
                        PropertyChanges { target: seekpointsRect; radius: control.thick ? control._thickRadius : control._scaledSeekPointsRadius }
                    }
                ]

                state: (seekpointsRect._hovered || (seekpointsRect._currentChapter === 0 && fsm._state === fsm.fsmHeld))
                       ? "visibleLarge"
                       : "visible"
            }
        }

        // The music player of the redesign shows the bar as a waveform
        // (Figma, Controls "waveform", 2139:8124): bars, the played ones in
        // the accent color. VLC gives the interface nothing of the sound to
        // draw them from, so their heights are a pattern of their own, the
        // same for a media each time, not the waveform of its audio.
        Item {
            id: waveform

            visible: control.waveform
            x: control._thickInset
            y: control._segmentY
            width: parent.width - 2 * control._thickInset
            height: control._segmentHeight

            readonly property real _step: VLCStyle.dp(5, VLCStyle.scale)
            readonly property int _count: Math.max(0, Math.floor(width / _step))

            // A number from the name of the media, to start the pattern from
            readonly property int _seed: {
                const name = String(Player.name)
                let hash = 7
                for (let i = 0; i < name.length; ++i)
                    hash = (hash * 31 + name.charCodeAt(i)) % 2147483647
                return hash
            }

            Repeater {
                model: waveform.visible ? waveform._count : 0

                Rectangle {
                    required property int index

                    // Some bars only a dot, most of them a part of the height
                    readonly property real _level: {
                        const n = Math.sin((index + 1) * 12.9898 + waveform._seed * 0.0001) * 43758.5453
                        const r = n - Math.floor(n)
                        return r < 0.18 ? 0.12 : 0.3 + 0.7 * r
                    }

                    x: index * waveform._step
                    width: VLCStyle.dp(2, VLCStyle.scale)
                    height: Math.max(width, waveform.height * 0.62 * _level)
                    y: (waveform.height - height) / 2
                    radius: width / 2
                    color: (x + waveform.x < control._thickPlayedEnd) ? theme.accent
                                                                      : Qt.alpha(theme.fg.secondary, 0.55)
                }
            }
        }

        Rectangle {
            id: progressRect
            x: control.thick ? control._thickInset : 0
            y: control._segmentY
            width: control.thick ? (control._thickPlayedEnd - x)
                                 : (control.visualPosition * parent.width)
            visible: !Player.hasChapters && !control.waveform
            color: control._playedColor
            height: control._segmentHeight
            radius: control.thick ? control._thickRadius : control._seekPointsRadius

            // We use dynamic mutability group because time interpolation
            // may induce rapid change:
            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: progressRect
                property: "mutabilityGroup"
                when: (progressRect.mutabilityGroup !== undefined)
                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                              : Item.StaticMutabilityGroup
            }
        }

        // The subtitle timeline (Figma, Controls "sub timeline", 3744:12361):
        // a mark along the foot of the bar for each time a subtitle is shown.
        // VLC does not give the interface the times of the subtitles, so they
        // are read from the .srt or .vtt file next to the media, the one VLC
        // loads with it by itself; other subtitles show no mark.
        Item {
            id: subtitleTimeline

            visible: control.thick && _segments.length > 0
            x: control._thickInset + control._thickRadius
            y: control._segmentY + control._segmentHeight - height - VLCStyle.dp(2, VLCStyle.scale)
            width: parent.width - 2 * x
            height: VLCStyle.dp(3, VLCStyle.scale)

            // The cues as parts of the bar, those less than two pixels apart
            // joined, moved by the subtitle delay
            readonly property var _segments: {
                const length = Player.length.toMilliseconds()
                const cues = control._cues
                if (!control.thick || length <= 0 || width <= 0 || cues.length < 2)
                    return []
                const delay = Player.subtitleDelayMS
                const pairs = []
                for (let i = 0; i + 1 < cues.length; i += 2) {
                    const start = Math.max(0, cues[i] + delay)
                    const end = Math.min(length, cues[i + 1] + delay)
                    if (end > start)
                        pairs.push([start, end])
                }
                pairs.sort((a, b) => a[0] - b[0])
                const gap = 2 * length / width
                const joined = []
                for (const pair of pairs) {
                    const last = joined[joined.length - 1]
                    if (last && pair[0] - last[1] < gap)
                        last[1] = Math.max(last[1], pair[1])
                    else
                        joined.push(pair.slice())
                }
                return joined.map((pair) => [pair[0] / length, pair[1] / length])
            }

            Repeater {
                model: subtitleTimeline._segments

                Rectangle {
                    required property var modelData

                    x: modelData[0] * subtitleTimeline.width
                    width: Math.max(VLCStyle.dp(2, VLCStyle.scale), (modelData[1] - modelData[0]) * subtitleTimeline.width)
                    height: subtitleTimeline.height
                    radius: height / 2
                    color: (x + subtitleTimeline.x < control._thickPlayedEnd) ? Qt.alpha(theme.fg.primary, 0.7)
                                                                              : Qt.alpha(theme.accent, 0.8)
                }
            }
        }

        Rectangle {
            id: bufferRect
            property int bufferAnimWidth: VLCStyle.dp(100, VLCStyle.scale)
            property int bufferAnimPosition: 0
            property int bufferFrames: 1000
            property alias animateLoading: loadingAnim.running
            property bool display: false
            property bool buffering: Player.buffering > 0 && Player.buffering < 1

            y: control._segmentY
            height: control._segmentHeight
            opacity: 0.4
            color: theme.fg.neutral //FIXME buffer color ?
            radius: control.thick ? control._thickRadius : control.barHeight

            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: bufferRect
                property: "mutabilityGroup"
                when: bufferRect.mutabilityGroup !== undefined
                value: bufferRect.buffering ? Item.DynamicMutabilityGroup
                                            : Item.StaticMutabilityGroup
            }

            Timer {
                id: bufferingTimer
                interval: VLCStyle.duration_humanMoment
                repeat: false
                running: false
                onTriggered: {
                    bufferRect.display = true
                }
            }

            onBufferingChanged: {
                if(buffering)
                {
                    bufferingTimer.start()
                }
                else
                {
                    bufferingTimer.stop()
                    bufferRect.display = false
                }
            }

            states: [
                State {
                    name: "hidden"
                    when: !control.visible
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "buffering not started"
                    when: control.visible && Player.buffering === 0
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: true
                        x: (bufferAnimPosition / bufferFrames) * (parent.width - bufferAnimWidth)
                        animateLoading: true
                    }
                },
                State {
                    name: "time to start playing known"
                    when: control.visible && bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: true
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "playing from buffer"
                    when: control.visible && !bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                }
            ]

            SequentialAnimation on bufferAnimPosition {
                id: loadingAnim
                running: bufferRect.animateLoading
                loops: Animation.Infinite
                PropertyAnimation {
                    from: 0.0
                    to: bufferRect.bufferFrames
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
                PropertyAnimation {
                    from: bufferRect.bufferFrames
                    to: 0.0
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
            }
        }
    }

    Rectangle {
        id: sliderHandle

        property int _size: control.barHeight * 3

        x: control.thick ? (control._thickPlayedEnd - width)
                         : ((control.visualPosition * control.availableWidth) - width / 2)
        y: (control.barHeight - height) / 2

        implicitWidth: control.thick ? control._thickHandleWidth : sliderHandle._size
        implicitHeight: control.thick ? control._segmentHeight : sliderHandle._size
        radius: control.thick ? control._thickRadius : VLCStyle.margin_small
        color: theme.fg.primary

        // We use dynamic mutability group because time interpolation
        // may induce rapid change:
        // TODO: Do not use `Binding` when minimum Qt is 6.12:
        Binding {
            target: sliderHandle
            property: "mutabilityGroup"
            when: (sliderHandle.mutabilityGroup !== undefined)
            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                          : Item.StaticMutabilityGroup
        }

        transitions: [
            Transition {
                to: "hidden"
                SequentialAnimation {
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: 0
                        duration: VLCStyle.duration_short; easing.type: Easing.OutSine
                    }
                    PropertyAction { target: sliderHandle; property: "visible"; value: false; }
                }
            },
            Transition {
                to: "visible"
                SequentialAnimation {
                    PropertyAction { target: sliderHandle; property: "visible"; value: true; }
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: sliderHandle._size
                        duration: VLCStyle.duration_short; easing.type: Easing.InSine
                    }
                }
            },
            Transition {
                to: "visibleLarge"
                SequentialAnimation {
                    PropertyAction { target: sliderHandle; property: "visible"; value: true; }
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: sliderHandle._size * (0.8 * control._hoveredScalingFactor)
                        duration: VLCStyle.duration_short; easing.type: Easing.InSine
                    }
                }
            }
        ]

        // The handle of the thick track is always there and never changes size.
        state: control.thick ? ""
                             : ((hoverHandler.hovered || control.visualFocus)
                                ? ((control._currentChapterHovered || (Player.hasChapters && fsm._state === fsm.fsmHeld)) ? "visibleLarge" : "visible")
                                : "hidden")
    }
}
