pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

Scope {
    id: shell
    property bool forcedOpen: false
    property int desktopEntriesRevision: 0
    readonly property var pinnedApps: ["helium", "Alacritty", "emacs", "spotify", "org.gnome.Nautilus"]
    readonly property var dockItems: {
        shell.desktopEntriesRevision;
        const items = pinnedApps.map(appId => ({ appId: appId, pinned: true, toplevel: null }));
        for (const window of ToplevelManager.toplevels.values) {
            if (!pinnedApps.some(appId => matchesApp(window, appId)))
                items.push({ appId: window.appId, pinned: false, toplevel: window });
        }
        return items;
    }

    function matchesApp(window, appId): bool {
        if ((window.appId || "").toLowerCase() === appId.toLowerCase()) return true;
        const desktop = DesktopEntries.heuristicLookup(window.appId);
        const pinned = DesktopEntries.heuristicLookup(appId);
        return desktop !== null && pinned !== null && desktop.id === pinned.id;
    }

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
            readonly property bool expanded: shell.forcedOpen || dock.hoverExpanded
            property var hoveredEntry: null
            property string chooserAppId: ""
            onExpandedChanged: { if (!expanded) dock.chooserAppId = ""; }

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
                readonly property var entry: dock.expanded && !dock.chooserAppId ? dock.hoveredEntry : null
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

            PopupWindow {
                id: chooser
                readonly property int appIndex: shell.dockItems.findIndex(item => item.appId === dock.chooserAppId)
                readonly property var appWindows: {
                    shell.desktopEntriesRevision;
                    return dock.chooserAppId
                        ? ToplevelManager.toplevels.values.filter(window => shell.matchesApp(window, dock.chooserAppId))
                        : [];
                }
                property var windowDetails: []

                function collectWindows(node, workspace) {
                    const currentWorkspace = node.type === "workspace" ? node.name : workspace;
                    let result = [];
                    if (node.type === "con" && (node.app_id || node.window_properties)) {
                        result.push({
                            appId: node.app_id || node.window_properties.class || "",
                            title: node.name || "",
                            workspace: currentWorkspace || "Workspace unknown",
                            urgent: !!node.urgent
                        });
                    }
                    for (const child of (node.nodes || []).concat(node.floating_nodes || [])) {
                        result = result.concat(collectWindows(child, currentWorkspace));
                    }
                    return result;
                }

                function detailsFor(window) {
                    const matches = windowDetails.filter(item =>
                        item.appId.toLowerCase() === window.appId.toLowerCase() && item.title === window.title);
                    // Foreign toplevels have no Sway container ID. Never guess between identical titles.
                    return matches.length === 1 ? matches[0] : null;
                }

                onVisibleChanged: {
                    windowDetails = [];
                    if (visible) treeQuery.running = true;
                }
                onAppWindowsChanged: { if (dock.chooserAppId && appWindows.length < 2) dock.chooserAppId = ""; }
                onAppIndexChanged: { if (visible) anchor.updateAnchor(); }
                visible: dock.expanded && appIndex >= 0 && appWindows.length > 1
                color: "transparent"
                implicitWidth: 320
                implicitHeight: Math.min(chooserList.contentHeight + 16, Math.max(64, dock.height - 120))

                anchor {
                    window: dock
                    edges: Edges.Top | Edges.Right
                    gravity: Edges.Bottom | Edges.Right
                    adjustment: PopupAdjustment.SlideY
                    rect.width: 1
                    rect.height: 1
                    onAnchoring: {
                        if (chooser.appIndex < 0) return;
                        // Use the row position, not a delegate that a model reset can destroy.
                        const iconCenterY = chooser.appIndex * (windows.rowHeight + windows.spacing) - windows.contentY + 20;
                        const center = dock.contentItem.mapFromItem(windows, 0, iconCenterY);
                        chooser.anchor.rect.x = dock.width - 5;
                        chooser.anchor.rect.y = Math.round(center.y - chooser.height / 2);
                    }
                }

                Process {
                    id: treeQuery
                    command: ["swaymsg", "-r", "-t", "get_tree"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                chooser.windowDetails = chooser.collectWindows(JSON.parse(text), "");
                            } catch (error) {
                                chooser.windowDetails = [];
                            }
                        }
                    }
                }

                Timer {
                    id: detailsRefresh
                    interval: 80
                    onTriggered: {
                        if (!chooser.visible) return;
                        if (treeQuery.running) restart();
                        else treeQuery.running = true;
                    }
                }

                Process {
                    // Subscribe only while open: no polling or idle background process.
                    running: chooser.visible
                    command: ["swaymsg", "-m", "-t", "subscribe", '["window","workspace"]']
                    stdout: SplitParser {
                        onRead: data => { detailsRefresh.restart(); }
                    }
                }

                HoverHandler {
                    id: chooserHover
                    onHoveredChanged: {
                        if (hovered) hideDelay.stop();
                        else hideDelay.restart();
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "#1b1b1b"
                    border.color: "#26ffffff"

                    ListView {
                        id: chooserList
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: chooser.appWindows
                        delegate: Button {
                            id: windowChoice
                            required property var modelData
                            width: ListView.view.width
                            readonly property var details: chooser.detailsFor(modelData)
                            readonly property var desktopEntry: {
                                shell.desktopEntriesRevision;
                                return DesktopEntries.heuristicLookup(modelData.appId);
                            }
                            readonly property string iconSource: desktopEntry && desktopEntry.icon
                                ? Quickshell.iconPath(desktopEntry.icon, true) : ""
                            readonly property string statusText: (details ? "Workspace " + details.workspace : "Workspace unknown")
                                + (modelData.activated ? " · Focused" : "")
                                + (details && details.urgent ? " · Urgent" : "")
                            height: 56
                            padding: 8
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            Accessible.name: (modelData.title || "Window") + " — " + statusText
                            onClicked: {
                                modelData.activate();
                                dock.chooserAppId = "";
                            }
                            background: Rectangle {
                                radius: 6
                                color: windowChoice.hovered ? "#26ffffff"
                                    : windowChoice.modelData.activated ? "#407ebae4" : "transparent"
                            }
                            contentItem: Item {
                                Image {
                                    id: choiceIcon
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28
                                    height: 28
                                    source: windowChoice.iconSource
                                    sourceSize.width: 28
                                    sourceSize.height: 28
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: choiceIcon
                                    visible: !choiceIcon.visible
                                    text: (windowChoice.desktopEntry ? windowChoice.desktopEntry.name : windowChoice.modelData.appId).charAt(0).toUpperCase()
                                    color: "#7ebae4"
                                    font.pixelSize: 18
                                }
                                Column {
                                    anchors.left: choiceIcon.right
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    Text {
                                        width: parent.width
                                        text: windowChoice.modelData.title || "Window"
                                        color: "#eeeeee"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: windowChoice.statusText
                                        color: windowChoice.details && windowChoice.details.urgent ? "#e5b567" : "#9a9a9a"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                        ScrollIndicator.vertical: ScrollIndicator {}
                    }
                }

                Connections {
                    target: windows
                    enabled: chooser.visible
                    function onContentYChanged(): void { chooser.anchor.updateAnchor(); }
                }

                Connections {
                    target: panel
                    enabled: chooser.visible
                    function onYChanged(): void { chooser.anchor.updateAnchor(); }
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
                    onTriggered: {
                        if (hover.hovered || chooserHover.hovered) return;
                        dock.chooserAppId = "";
                        dock.hoverExpanded = false;
                    }
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
                        model: shell.dockItems
                        readonly property int rowHeight: 48

                        delegate: Button {
                            id: entry
                            required property var modelData
                            readonly property var desktopEntry: {
                                // Lookup methods do not expose binding dependencies themselves.
                                shell.desktopEntriesRevision;
                                return DesktopEntries.heuristicLookup(modelData.appId);
                            }
                            readonly property var appWindows: {
                                shell.desktopEntriesRevision;
                                return modelData.pinned
                                    ? ToplevelManager.toplevels.values.filter(window => shell.matchesApp(window, modelData.appId))
                                    : (modelData.toplevel ? [modelData.toplevel] : []);
                            }
                            readonly property bool active: appWindows.some(window => window.activated)
                            readonly property string appName: desktopEntry ? desktopEntry.name : (modelData.appId || "Application")
                            readonly property string iconSource: desktopEntry && desktopEntry.icon ? Quickshell.iconPath(desktopEntry.icon, true) : ""

                            width: ListView.view.width
                            height: windows.rowHeight
                            padding: 0
                            hoverEnabled: true
                            focusPolicy: Qt.NoFocus
                            Accessible.name: appName + (appWindows.length ? ": " + appWindows[0].title : "")
                            onClicked: {
                                if (appWindows.length > 1) {
                                    dock.chooserAppId = dock.chooserAppId === modelData.appId ? "" : modelData.appId;
                                } else if (appWindows.length) {
                                    dock.chooserAppId = "";
                                    appWindows[0].activate();
                                } else if (desktopEntry) {
                                    dock.chooserAppId = "";
                                    desktopEntry.execute();
                                }
                            }

                            readonly property var tooltipIcon: appIcon
                            onHoveredChanged: {
                                if (hovered) dock.hoveredEntry = entry;
                                else dock.clearHoveredEntry(entry);
                            }
                            Component.onDestruction: {
                                dock.clearHoveredEntry(entry);
                            }

                            background: Rectangle {
                                radius: 8
                                color: entry.down ? "#527ebae4"
                                    : entry.hovered ? "#26ffffff"
                                    : entry.active ? "#407ebae4" : "transparent"
                                border.color: entry.active ? "#7ebae4" : "transparent"
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
                                    visible: entry.appWindows.length > 0
                                    width: entry.active ? 14 : 4
                                    height: 3
                                    radius: 2
                                    color: entry.active ? "#7ebae4" : "#bfbfbf"
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
