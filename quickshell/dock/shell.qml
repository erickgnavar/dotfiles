//@ pragma IconTheme Papirus-Dark

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

ShellRoot {
    id: shell
    property bool forcedOpen: false
    property int desktopEntriesRevision: 0

    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void { shell.desktopEntriesRevision++; }
    }

    IpcHandler {
        target: "dock"
        function toggle(): void { shell.forcedOpen = !shell.forcedOpen; }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dock
            required property var modelData
            property bool hoverExpanded: false
            readonly property bool expanded: shell.forcedOpen || hoverExpanded
            property var hoveredEntry: null

            function clearHoveredEntry(entry): void {
                if (hoveredEntry === entry) hoveredEntry = null;
            }

            screen: modelData
            visible: true
            anchors.left: true
            anchors.top: true
            anchors.bottom: true
            implicitWidth: expanded ? 76 : 3
            mask: Region {
                width: 3
                height: dock.height
                Region {
                    y: panel.y
                    width: dock.expanded ? dock.width : 0
                    height: panel.height
                }
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "dock"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Timer {
                id: tooltipDelay
                readonly property var entry: dock.expanded ? dock.hoveredEntry : null
                interval: 100
                onEntryChanged: {
                    tooltip.visible = false;
                    if (entry) restart();
                    else stop();
                }
                onTriggered: tooltip.visible = entry !== null
            }

            PopupWindow {
                id: tooltip
                visible: false
                color: "transparent"
                mask: Region {}
                implicitWidth: tooltipLabel.implicitWidth + 20
                implicitHeight: tooltipLabel.implicitHeight + 12

                anchor {
                    window: dock
                    edges: Edges.Top | Edges.Right
                    gravity: Edges.Bottom | Edges.Right
                    adjustment: PopupAdjustment.SlideY
                    rect.width: 1
                    rect.height: 1
                    onAnchoring: {
                        if (!tooltipDelay.entry) return;
                        const icon = tooltipDelay.entry.tooltipIcon;
                        const center = dock.contentItem.mapFromItem(icon, 0, icon.height / 2);
                        tooltip.anchor.rect.x = dock.width - 5;
                        tooltip.anchor.rect.y = Math.round(center.y - tooltip.height / 2);
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "#1b1b1b"
                    border.color: "#26ffffff"

                    Text {
                        id: tooltipLabel
                        anchors.centerIn: parent
                        text: tooltipDelay.entry ? tooltipDelay.entry.appName : ""
                        color: "#eeeeee"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                }

                Connections {
                    target: windows
                    enabled: tooltip.visible
                    function onContentYChanged(): void { tooltip.anchor.updateAnchor(); }
                }
            }

            // The full-height edge and visible dock receive input; everything else passes through.
            Item {
                anchors.fill: parent

                HoverHandler {
                    id: hover
                    onHoveredChanged: {
                        if (hovered) {
                            hideDelay.stop();
                            revealDelay.start();
                        } else {
                            revealDelay.stop();
                            hideDelay.start();
                        }
                    }
                }

                Timer {
                    id: revealDelay
                    interval: 100
                    onTriggered: dock.hoverExpanded = true
                }

                Timer {
                    id: hideDelay
                    interval: 350
                    onTriggered: dock.hoverExpanded = false
                }

                Rectangle {
                    id: panel
                    x: dock.expanded ? 8 : -60
                    y: (parent.height - height) / 2
                    width: 60
                    height: Math.min(Math.max(64, windows.contentHeight + 16), Math.max(64, dock.height - 120))
                    radius: 12
                    color: "#1b1b1b"
                    border.color: "#26ffffff"
                    opacity: dock.expanded ? 1 : 0

                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    ListView {
                        id: windows
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: ToplevelManager.toplevels

                        delegate: Button {
                            id: entry
                            required property var modelData
                            readonly property var desktopEntry: {
                                // Lookup methods do not expose binding dependencies themselves.
                                shell.desktopEntriesRevision;
                                return DesktopEntries.heuristicLookup(modelData.appId);
                            }
                            readonly property string appName: desktopEntry ? desktopEntry.name : (modelData.appId || "Application")
                            readonly property string iconSource: desktopEntry && desktopEntry.icon ? Quickshell.iconPath(desktopEntry.icon, true) : ""

                            width: ListView.view.width
                            height: 48
                            padding: 0
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            Accessible.name: appName + ": " + modelData.title
                            onClicked: modelData.activate()

                            readonly property var tooltipIcon: appIcon
                            onHoveredChanged: {
                                if (hovered) dock.hoveredEntry = entry;
                                else dock.clearHoveredEntry(entry);
                            }
                            Component.onDestruction: dock.clearHoveredEntry(entry)

                            background: Rectangle {
                                radius: 8
                                color: entry.down ? "#527ebae4"
                                    : entry.hovered ? "#26ffffff"
                                    : entry.modelData.activated ? "#407ebae4" : "transparent"
                                border.color: entry.modelData.activated ? "#7ebae4" : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            contentItem: Item {
                                Image {
                                    id: appIcon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 5
                                    width: 30
                                    height: 30
                                    source: entry.iconSource
                                    sourceSize.width: 30
                                    sourceSize.height: 30
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.fill: appIcon
                                    visible: !appIcon.visible
                                    text: entry.appName.charAt(0).toUpperCase()
                                    color: "#eeeeee"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
                                    width: entry.modelData.activated ? 14 : 4
                                    height: 3
                                    radius: 2
                                    color: entry.modelData.activated ? "#7ebae4" : "#bfbfbf"
                                }
                            }
                        }

                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                }
            }
        }
    }
}
