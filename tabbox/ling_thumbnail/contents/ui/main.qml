import QtQuick
import QtQuick.Window
import QtQuick.Controls

import org.kde.kwin 3.0 as KWin
import org.kde.kirigami 2.20 as Kirigami

import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Lingmo window switcher (Alt+Tab): a frosted strip of live window previews. The
// selection ring glides between cards and the focused card lifts slightly.
KWin.TabBoxSwitcher {
    id: tabBox

    readonly property bool dark: LingmoUI.Theme.darkMode
    readonly property color accent: LingmoUI.Theme.highlightColor
    readonly property bool livePreviews: true

    Window {
        id: dialog
        visible: tabBox.visible
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        color: "transparent"

        // Card size follows the screen shape; cards shrink when many windows are open
        readonly property real screenRatio: tabBox.screenGeometry.width / tabBox.screenGeometry.height
        readonly property int padding: 18
        readonly property int maxWidth: tabBox.screenGeometry.width * 0.9
        readonly property int idealCardWidth: 240
        readonly property int cardWidth: Math.max(140, Math.min(idealCardWidth,
                                         (maxWidth - padding * 2) / Math.max(1, listView.count) - listView.spacing))
        readonly property int previewHeight: Math.round(cardWidth / screenRatio)
        readonly property int cardHeight: previewHeight + 44

        width: Math.min(maxWidth, listView.count * (cardWidth + listView.spacing) - listView.spacing + padding * 2)
        height: cardHeight + padding * 2

        x: tabBox.screenGeometry.x + (tabBox.screenGeometry.width - width) / 2
        y: tabBox.screenGeometry.y + (tabBox.screenGeometry.height - height) / 2

        LingmoUI.WindowHelper {
            id: windowHelper
        }

        LingmoUI.WindowBlur {
            view: dialog
            geometry: Qt.rect(dialog.x, dialog.y, dialog.width, dialog.height)
            windowRadius: panel.radius
            enabled: windowHelper.compositing
        }

        LingmoUI.WindowShadow {
            view: dialog
            geometry: Qt.rect(dialog.x, dialog.y, dialog.width, dialog.height)
            radius: panel.radius
        }

        // KWin may create the switcher already visible, so onVisibleChanged alone misses the first show
        function present() {
            listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
            appear.restart()
        }
        onVisibleChanged: if (visible) present()
        Component.onCompleted: if (visible) present()

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: 22
            // Frosted when the compositor blurs behind us, solid otherwise
            color: windowHelper.compositing
                   ? (tabBox.dark ? Qt.rgba(0.12, 0.12, 0.16, 0.72) : Qt.rgba(0.98, 0.98, 1.0, 0.72))
                   : (tabBox.dark ? "#1E1F29" : "#F6F6F8")
            border.width: 1
            border.color: tabBox.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)

            // Opens with a short fade and settle
            ParallelAnimation {
                id: appear
                NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
                NumberAnimation { target: panel; property: "scale"; from: 0.94; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: dialog.padding
                orientation: ListView.Horizontal
                spacing: 12
                model: tabBox.model
                currentIndex: tabBox.currentIndex
                clip: count * (dialog.cardWidth + spacing) > width
                interactive: false
                boundsBehavior: Flickable.StopAtBounds

                highlightFollowsCurrentItem: true
                highlightMoveDuration: 180
                highlightMoveVelocity: -1
                highlightResizeDuration: 0
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: width

                highlight: Rectangle {
                    radius: 16
                    color: Qt.rgba(tabBox.accent.r, tabBox.accent.g, tabBox.accent.b, tabBox.dark ? 0.22 : 0.14)
                    border.width: 2
                    border.color: tabBox.accent
                }

                delegate: Item {
                    id: card
                    readonly property bool isCurrent: ListView.isCurrentItem

                    width: dialog.cardWidth
                    height: dialog.cardHeight

                    MouseArea {
                        anchors.fill: parent
                        onClicked: tabBox.model.activate(index)
                    }

                    Item {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 8
                        scale: card.isCurrent ? 1.0 : 0.95
                        opacity: card.isCurrent ? 1.0 : 0.85

                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 180 } }

                        Rectangle {
                            id: previewFrame
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: dialog.previewHeight - 8
                            radius: 10
                            clip: true
                            color: tabBox.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)

                            // Stand-in when there's no live preview (no compositing)
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) * 0.45
                                height: width
                                source: model.icon
                            }

                            // Live previews need the compositor (without it they stay empty)
                            Loader {
                                id: preview
                                anchors.fill: parent
                                anchors.margins: 4
                                active: tabBox.livePreviews && windowHelper.compositing
                                sourceComponent: KWin.WindowThumbnail {
                                    wId: windowId
                                }
                            }
                        }

                        // App badge overlapping the preview's bottom edge (the preview's
                        // stand-in already is the icon when there's no live preview)
                        Kirigami.Icon {
                            visible: preview.active
                            anchors.horizontalCenter: previewFrame.horizontalCenter
                            anchors.verticalCenter: previewFrame.bottom
                            width: 36
                            height: 36
                            source: model.icon
                        }

                        Label {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 18
                            text: model.caption
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.weight: card.isCurrent ? Font.DemiBold : Font.Normal
                            color: tabBox.dark ? "#F2F2F5" : "#1C1C22"
                        }
                    }
                }
            }
        }
    }
}
