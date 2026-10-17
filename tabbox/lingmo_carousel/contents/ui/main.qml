/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * Author:     devalexandre <alexandre@dev2learn.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects

import org.kde.kwin 3.0 as KWin
import org.kde.kirigami 2.20 as Kirigami

import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Lingmo "Carousel" window switcher (Alt+Tab), cover-flow style: the selected
// window flat and large in the middle; the previous windows stacked on the left
// and the next ones on the right, turned towards the middle like the pages of an
// open book. All cards stand on one baseline over a glossy floor that reflects
// them. Tab / Shift+Tab slide the row by one place and the list wraps around.
//
// The row is a "track" of places ..., -1, 0, 1, 2, ... where place k shows window
// k mod count. `pos` is the (animated) place in the middle, so sliding is just
// animating one number. A fixed set of slots covers the places around `pos`; a
// slot only changes window while it is off at the far edge, invisible.
KWin.TabBoxSwitcher {
    id: tabBox

    readonly property bool dark: LingmoUI.Theme.darkMode
    readonly property color accent: LingmoUI.Theme.highlightColor
    readonly property string fontFamily: LingmoUI.Theme.fontFamily || "Inter"
    readonly property bool livePreviews: true

    // Neighbours shown per side at most
    readonly property int maxSide: 3
    // Turn of the side cards, in degrees
    readonly property real tilt: 55
    // Slide time
    readonly property int slideDuration: 220

    // A window's face: live preview over its icon (the icon is what shows without
    // compositing, or for a minimized window KWin keeps no picture of)
    component Face: Rectangle {
        id: face
        property Item win: null
        property bool live: false

        radius: 10
        clip: true
        color: tabBox.dark ? "#2C2C2D" : "#FFFFFF"

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.34
            height: width
            source: face.win ? face.win.icon : ""
        }

        Loader {
            anchors.fill: parent
            active: face.live && face.win !== null
            sourceComponent: KWin.WindowThumbnail {
                wId: face.win ? face.win.wid : ""
            }
        }
    }

    Window {
        id: dialog
        visible: tabBox.visible
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        color: "transparent"

        // Covers the screen: the desktop behind is dimmed so the cards stand out
        x: tabBox.screenGeometry.x
        y: tabBox.screenGeometry.y
        width: tabBox.screenGeometry.width
        height: tabBox.screenGeometry.height

        readonly property bool compositing: windowHelper.compositing
        readonly property int count: windows.count
        // With 2 windows only the other one is shown, on the right, as "next"
        readonly property int leftSlots: Math.min(tabBox.maxSide, Math.floor(Math.max(0, count - 1) / 2))
        readonly property int rightSlots: Math.min(tabBox.maxSide, Math.max(0, count - 1 - leftSlots))

        // Card: screen-shaped, about a quarter of the screen wide
        readonly property real screenRatio: width / Math.max(1, height)
        readonly property real cardWidth: Math.round(Math.min(width * 0.27, 760, height * 0.36 * screenRatio))
        readonly property real cardHeight: Math.round(cardWidth / screenRatio)
        // Cards stand on this line; the floor with the reflections is below it
        readonly property real baseline: Math.round(height * 0.5 + cardHeight * 0.32)
        readonly property real reflectionHeight: Math.round(cardHeight * 0.4)

        // Backdrop colour; the floor is nearly opaque so the reflections can fade into it
        readonly property color shade: tabBox.dark ? "#0B0C10" : "#E6E7EE"
        function shadeAlpha(alpha) {
            return Qt.rgba(shade.r, shade.g, shade.b, alpha)
        }

        LingmoUI.WindowHelper {
            id: windowHelper
        }

        // Window data by index, for the slots (the model has no index accessor in QML)
        Repeater {
            id: windows
            model: tabBox.model
            delegate: Item {
                visible: false
                readonly property string caption: model.caption || ""
                readonly property var icon: model.icon
                readonly property var wid: model.windowId
                readonly property bool minimized: model.minimized === true
            }
            onItemAdded: track.revision++
            onItemRemoved: track.revision++
            onCountChanged: track.snap()
        }

        // KWin may create the switcher already visible, so onVisibleChanged alone misses the first show
        function present() {
            track.snap()
            appear.restart()
        }
        onVisibleChanged: if (visible) present()
        Component.onCompleted: if (visible) present()

        // Explicit sizes: anchors.fill on the window's content item can stay 0x0 here
        Item {
            id: stage
            width: dialog.width
            height: dialog.height

            ParallelAnimation {
                id: appear
                NumberAnimation { target: stage; property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
                NumberAnimation { target: row; property: "scale"; from: 0.94; to: 1; duration: 240; easing.type: Easing.OutCubic }
            }

            // Dims the desktop: light at the top, a near-solid "floor" from the baseline down
            Rectangle {
                id: backdrop
                width: stage.width
                height: stage.height
                readonly property real topAlpha: dialog.compositing ? (tabBox.dark ? 0.62 : 0.55) : 1
                readonly property real floorAlpha: dialog.compositing ? 0.90 : 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: dialog.shadeAlpha(backdrop.topAlpha) }
                    GradientStop { position: dialog.baseline / Math.max(1, stage.height); color: dialog.shadeAlpha(backdrop.floorAlpha) }
                    GradientStop { position: 1.0; color: dialog.shadeAlpha(backdrop.floorAlpha) }
                }
            }

            // Mouse wheel steps through the windows (touchpads send small deltas)
            WheelHandler {
                property real acc: 0
                onWheel: (event) => {
                    const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                    acc += delta
                    while (Math.abs(acc) >= 120) {
                        track.step(acc > 0 ? -1 : 1)
                        acc -= acc > 0 ? 120 : -120
                    }
                }
            }

            QtObject {
                id: track

                // Place on the track that sits in the middle (animated) and where it's heading
                property real pos: 0
                property real target: 0
                property int lastIndex: 0
                // Set by a click or the wheel so the row slides that way
                property int pendingDelta: 0
                property int revision: 0

                readonly property NumberAnimation slide: NumberAnimation {
                    target: track
                    property: "pos"
                    duration: tabBox.slideDuration
                    easing.type: Easing.OutCubic
                }

                function wrap(i) {
                    const n = Math.max(1, dialog.count)
                    return ((i % n) + n) % n
                }

                function snap() {
                    slide.stop()
                    lastIndex = Math.max(0, tabBox.currentIndex)
                    pos = lastIndex
                    target = lastIndex
                    pendingDelta = 0
                }

                function step(delta) {
                    if (dialog.count < 2)
                        return
                    pendingDelta = delta
                    tabBox.currentIndex = wrap(tabBox.currentIndex + delta)
                }

                function follow() {
                    const n = dialog.count
                    const index = tabBox.currentIndex
                    if (!dialog.visible || n < 1 || index < 0) {
                        snap()
                        return
                    }
                    let delta = pendingDelta
                    if (delta === 0 || wrap(lastIndex + delta) !== index) {
                        // Shortest way round; with two windows always forwards
                        delta = wrap(index - lastIndex)
                        if (delta > n / 2)
                            delta -= n
                    }
                    pendingDelta = 0
                    lastIndex = index
                    if (delta === 0)
                        return
                    target += delta
                    slide.to = target
                    slide.restart()
                }

                // Where a card `d` places from the middle goes (d is fractional while sliding)
                function offsetAt(d) {
                    const a = Math.abs(d)
                    const w = dialog.cardWidth
                    const o = a <= 1 ? a * w * 0.84 : w * 0.84 + (a - 1) * w * 0.22
                    return d < 0 ? -o : o
                }
                function scaleAt(d) {
                    return 1 - 0.12 * Math.min(1, Math.abs(d))
                }
                // Turns while passing through the middle; inner edge away from us
                function angleAt(d) {
                    return -Math.max(-1, Math.min(1, d)) * tabBox.tilt
                }
                // Fades out past the last neighbour shown on that side
                function edgeFade(d) {
                    return d < 0 ? Math.max(0, Math.min(1, dialog.leftSlots + 1 + d))
                                 : Math.max(0, Math.min(1, dialog.rightSlots + 1 - d))
                }
            }

            Connections {
                target: tabBox
                function onCurrentIndexChanged() { track.follow() }
            }

            // Cards and their reflections share one geometry
            Item {
                id: row
                width: stage.width
                height: stage.height
                transformOrigin: Item.Center

                // Reflections on the floor (under the cards' bottom edges)
                Item {
                    id: floor
                    y: dialog.baseline
                    width: row.width
                    height: dialog.reflectionHeight
                    clip: true

                    Repeater {
                        model: slots.count
                        delegate: Item {
                            id: mirror
                            readonly property Item card: slots.itemAt(index)

                            visible: card !== null && card.visible
                            x: card ? card.x : 0
                            y: -dialog.cardHeight
                            width: dialog.cardWidth
                            height: dialog.cardHeight
                            z: card ? card.z : 0
                            opacity: card ? 0.32 * card.opacity : 0

                            transform: [
                                Scale {
                                    origin.x: mirror.width / 2
                                    origin.y: mirror.height
                                    xScale: mirror.card ? track.scaleAt(mirror.card.d) : 1
                                    yScale: -xScale
                                },
                                Rotation {
                                    origin.x: mirror.width / 2
                                    origin.y: mirror.height
                                    axis { x: 0; y: 1; z: 0 }
                                    angle: mirror.card ? track.angleAt(mirror.card.d) : 0
                                }
                            ]

                            Face {
                                width: mirror.width
                                height: mirror.height
                                win: mirror.card ? mirror.card.win : null
                                live: mirror.card ? mirror.card.live : false
                            }
                        }
                    }

                    // The reflections fade out downwards: one light mask pass over the
                    // whole floor strip (all cards share the baseline)
                    layer.enabled: visible
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: floorMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }

                Rectangle {
                    id: floorMask
                    width: floor.width
                    height: floor.height
                    visible: false
                    layer.enabled: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "white" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Repeater {
                    id: slots
                    // Up to 3 per side, plus one entering at each end while sliding
                    model: 2 * tabBox.maxSide + 3

                    delegate: Item {
                        id: slot

                        readonly property int span: slots.count
                        // The track place in [pos - span/2, pos + span/2) equal to index mod span
                        readonly property int place: index + span * Math.ceil((track.pos - span / 2 - index) / span)
                        readonly property real d: place - track.pos
                        readonly property real a: Math.abs(d)
                        readonly property int windowIndex: track.wrap(place)
                        readonly property Item win: {
                            track.revision
                            return dialog.count > 0 ? windows.itemAt(windowIndex) : null
                        }
                        readonly property bool live: tabBox.livePreviews && dialog.compositing && visible

                        visible: win !== null && opacity > 0.01
                        opacity: track.edgeFade(d)
                        width: dialog.cardWidth
                        height: dialog.cardHeight
                        x: Math.round((row.width - width) / 2 + track.offsetAt(d))
                        y: dialog.baseline - height
                        // Nearer the middle is on top
                        z: 100 - Math.round(a * 10)

                        transform: [
                            Scale {
                                origin.x: slot.width / 2
                                origin.y: slot.height
                                xScale: track.scaleAt(slot.d)
                                yScale: track.scaleAt(slot.d)
                            },
                            Rotation {
                                // About the bottom edge's middle, so every card stays on the baseline
                                origin.x: slot.width / 2
                                origin.y: slot.height
                                axis { x: 0; y: 1; z: 0 }
                                angle: track.angleAt(slot.d)
                            }
                        ]
                        Face {
                            id: face
                            width: slot.width
                            height: slot.height
                            win: slot.win
                            live: slot.live
                        }

                        // Cards further away are in shade
                        Rectangle {
                            width: slot.width
                            height: slot.height
                            radius: face.radius
                            color: "black"
                            opacity: Math.min(0.5, slot.a <= 1 ? slot.a * 0.18 : 0.18 + (slot.a - 1) * 0.10)
                            visible: opacity > 0
                        }

                        // Minimized badge
                        Rectangle {
                            visible: slot.win !== null && slot.win.minimized
                            x: slot.width - width - 12
                            y: 12
                            width: 32
                            height: 32
                            radius: 16
                            color: tabBox.dark ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(1, 1, 1, 0.88)

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                source: "window-minimize-symbolic"
                                color: tabBox.dark ? "#FFFFFF" : "#323238"
                                isMask: true
                            }
                        }

                        // Outline: accent on the selected card, a hairline on the others
                        Rectangle {
                            width: slot.width
                            height: slot.height
                            radius: face.radius
                            color: "transparent"
                            border.width: slot.a < 0.5 ? 3 : 1
                            border.color: slot.a < 0.5 ? tabBox.accent
                                                       : (tabBox.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12))
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: slot.visible
                            onClicked: {
                                const delta = Math.round(slot.d)
                                if (delta === 0)
                                    tabBox.model.activate(slot.windowIndex)
                                else
                                    track.step(delta)
                            }
                        }
                    }
                }
            }

            // Selected window's icon and title, under the middle card over the floor
            Item {
                id: caption
                x: Math.round((stage.width - width) / 2)
                y: dialog.baseline + 26
                width: Math.min(stage.width - 64, dialog.cardWidth * 1.6)
                height: 64

                readonly property Item win: {
                    track.revision
                    return dialog.count > 0 && tabBox.currentIndex >= 0 ? windows.itemAt(tabBox.currentIndex) : null
                }
                onWinChanged: if (dialog.visible) captionFade.restart()

                NumberAnimation {
                    id: captionFade
                    target: captionPill
                    property: "opacity"
                    from: 0.2
                    to: 1
                    duration: tabBox.slideDuration
                    easing.type: Easing.OutCubic
                }

                Rectangle {
                    id: captionPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: captionRow.width + 36
                    height: 48
                    radius: 24
                    color: tabBox.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.75)
                    border.width: 1
                    border.color: tabBox.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
                    visible: caption.win !== null

                    Row {
                        id: captionRow
                        anchors.centerIn: parent
                        spacing: 10

                        Kirigami.Icon {
                            width: 28
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            source: caption.win ? caption.win.icon : ""
                        }

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, caption.width - 80)
                            text: caption.win ? caption.win.caption : ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.family: tabBox.fontFamily
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: tabBox.dark ? "#FFFFFF" : "#1D1D22"
                        }
                    }
                }

                // Where we are in the list
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: captionPill.bottom
                    anchors.topMargin: 12
                    spacing: 6
                    visible: dialog.count > 1 && dialog.count <= 16

                    Repeater {
                        model: dialog.count
                        Rectangle {
                            readonly property bool current: index === tabBox.currentIndex
                            width: current ? 16 : 6
                            height: 6
                            radius: 3
                            color: current ? tabBox.accent
                                           : (tabBox.dark ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(0, 0, 0, 0.22))
                            Behavior on width { NumberAnimation { duration: tabBox.slideDuration; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
}
