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

import org.kde.kwin 3.0 as KWin
import org.kde.kirigami 2.20 as Kirigami

import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Lingmo "Flip" window switcher (Alt+Tab): windows stacked like the pages of a
// book bound on the left. The current window is the front page; every switch
// turns it over and it goes to the back of the stack.
KWin.TabBoxSwitcher {
    id: tabBox

    readonly property bool dark: LingmoUI.Theme.darkMode
    readonly property bool livePreviews: true
    // Pages drawn behind the front one
    readonly property int visiblePages: 5

    Window {
        id: dialog
        visible: tabBox.visible
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        color: "transparent"

        x: tabBox.screenGeometry.x
        y: tabBox.screenGeometry.y
        width: tabBox.screenGeometry.width
        height: tabBox.screenGeometry.height

        LingmoUI.WindowHelper {
            id: windowHelper
        }

        // Page size: a large, screen-shaped card
        readonly property real pageWidth: Math.min(width * 0.46, 960)
        readonly property real pageHeight: pageWidth * height / Math.max(1, width)

        // Dim the desktop so the stack stands out
        // Explicit sizes: anchors.fill on the window's content item stays 0x0 here
        Rectangle {
            id: backdrop
            width: dialog.width
            height: dialog.height
            color: "black"
            opacity: dialog.visible ? 0.45 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        function present() {
            stack.opacity = 0
            stack.scale = 0.9
            appear.restart()
        }
        onVisibleChanged: if (visible) present()
        Component.onCompleted: if (visible) present()

        Item {
            id: stack
            width: dialog.width
            height: dialog.height

            // Set by the front page
            property string frontCaption
            property var frontIcon

            ParallelAnimation {
                id: appear
                NumberAnimation { target: stack; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
                NumberAnimation { target: stack; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }

            Repeater {
                id: pages
                model: tabBox.model

                delegate: Item {
                    id: page

                    // Place in the stack: 0 = front page, 1.. = behind it
                    readonly property int slot: (index - tabBox.currentIndex + pages.count) % Math.max(1, pages.count)
                    property real depth: slot
                    // 0..1 while the page is turned over (it just left the front)
                    property real turn: 0

                    width: dialog.pageWidth
                    height: dialog.pageHeight
                    // Pages step up and to the right, getting smaller, like a fanned book
                    x: (dialog.width - width) / 2 + depth * width * 0.07 - turn * width * 0.25
                    y: (dialog.height - height) / 2 - depth * height * 0.06
                    z: pages.count - depth + (turn > 0 ? pages.count : 0)
                    scale: 1 - Math.min(depth, tabBox.visiblePages) * 0.07
                    opacity: depth > tabBox.visiblePages ? 0
                             : (1 - turn) * (1 - Math.max(0, depth - tabBox.visiblePages + 1))
                    visible: opacity > 0

                    transform: Rotation {
                        // Bound on the left edge: pages behind lean away, the
                        // turned page swings over the spine
                        origin.x: 0
                        origin.y: page.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: -Math.min(page.depth, tabBox.visiblePages) * 7 - page.turn * 110
                    }

                    // Moving one step back through the stack glides; wrapping from the
                    // front to the back turns the page instead
                    Behavior on depth {
                        enabled: !turnOver.running
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    onSlotChanged: {
                        if (slot === pages.count - 1 && depth === 0 && pages.count > 1) {
                            turnOver.restart()
                        } else if (!turnOver.running) {
                            depth = slot
                        }
                    }
                    Component.onCompleted: depth = slot

                    Binding { target: stack; property: "frontCaption"; value: model.caption; when: page.slot === 0 }
                    Binding { target: stack; property: "frontIcon"; value: model.icon; when: page.slot === 0 }

                    SequentialAnimation {
                        id: turnOver
                        NumberAnimation { target: page; property: "turn"; from: 0; to: 1; duration: 260; easing.type: Easing.InCubic }
                        ScriptAction { script: { page.depth = page.slot; page.turn = 0 } }
                    }

                    // The page itself
                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: 14
                        color: tabBox.dark ? "#282A36" : "#F6F6F8"
                        border.width: page.slot === 0 ? 2 : 1
                        border.color: page.slot === 0 ? LingmoUI.Theme.highlightColor
                                                      : (tabBox.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12))
                        clip: true

                        // Stand-in when there's no live preview
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) * 0.3
                            height: width
                            source: model.icon
                        }

                        Loader {
                            anchors.fill: parent
                            anchors.margins: 3
                            active: tabBox.livePreviews && windowHelper.compositing
                            sourceComponent: KWin.WindowThumbnail {
                                wId: windowId
                            }
                        }

                        // Pages further back fade into shade
                        Rectangle {
                            anchors.fill: parent
                            radius: card.radius
                            color: "black"
                            opacity: Math.min(page.depth, tabBox.visiblePages) * 0.09
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: tabBox.model.activate(index)
                    }
                }
            }

            // Name of the front page's window
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (dialog.height + dialog.pageHeight) / 2 + 36
                width: captionRow.implicitWidth + 32
                height: captionRow.implicitHeight + 16
                radius: height / 2
                color: tabBox.dark ? Qt.rgba(0.16, 0.16, 0.21, 0.92) : Qt.rgba(1, 1, 1, 0.92)
                visible: pages.count > 0

                Row {
                    id: captionRow
                    anchors.centerIn: parent
                    spacing: 10

                    Kirigami.Icon {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        source: stack.frontIcon || ""
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: stack.frontCaption
                        font.weight: Font.DemiBold
                        color: tabBox.dark ? "#F2F2F5" : "#1C1C22"
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, dialog.width * 0.5)
                    }
                }
            }
        }
    }
}
