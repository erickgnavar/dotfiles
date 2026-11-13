pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: shell
    property bool opened: false
    property var history: []
    property var applications: []
    property int selected: 0
    property int desktopRevision: 0

    function orderedWindows(windows, history, active) {
        const recent = history.filter(window => windows.includes(window));
        const ordered = recent.concat(windows.filter(window => !recent.includes(window)));
        return active && windows.includes(active)
            ? [active].concat(ordered.filter(window => window !== active)) : ordered;
    }

    function buildApplications(windows, desktopId) {
        const apps = [];
        for (const window of windows) {
            const key = (desktopId(window.appId) || window.appId || "unknown").toLowerCase();
            if (!apps.some(item => item.key === key))
                apps.push({ key: key, appId: window.appId, window: window });
        }
        return apps;
    }

    function cycle(index, direction, count) {
        return count ? (index + direction + count) % count : 0;
    }

    function findContainer(tree, target) {
        const matches = [];
        function visit(node) {
            const properties = node.window_properties || {};
            const appId = node.app_id || properties.class || properties.instance || "";
            if ((node.app_id || node.window) && appId.toLowerCase() === target.appId.toLowerCase())
                matches.push(node);
            const children = (node.nodes || []).concat(node.floating_nodes || []);
            const focus = node.focus || [];
            const rank = id => {
                const index = focus.indexOf(id);
                return index < 0 ? children.length : index;
            };
            children.sort((a, b) => rank(a.id) - rank(b.id)).forEach(visit);
        }
        visit(tree);
        // Prefer the selected title; Sway's focus order resolves duplicates or title changes.
        const window = matches.find(node => (node.name || "") === target.title) || matches[0];
        return window ? window.id : 0;
    }

    function step(direction): void {
        if (!opened) {
            const windows = orderedWindows(ToplevelManager.toplevels.values,
                history, ToplevelManager.activeToplevel);
            applications = buildApplications(windows, appId => {
                const desktop = DesktopEntries.heuristicLookup(appId);
                return desktop ? desktop.id : "";
            });
            if (!applications.length) return;
            selected = cycle(0, direction, applications.length);
            opened = true;
        } else {
            selected = cycle(selected, direction, applications.length);
        }
    }

    function handleBinding(line) {
        let event;
        try { event = JSON.parse(line); } catch (_) { return; }
        const command = event.binding ? event.binding.command : "";
        if (command === "nop app-switcher-next") shell.step(1);
        else if (command === "nop app-switcher-previous") shell.step(-1);
        else if (command === "nop app-switcher-accept") shell.accept();
    }

    // One ordered stream preserves release events even before the overlay gains focus.
    Process {
        command: ["swaymsg", "-m", "-r", "-t", "subscribe", '["binding"]']
        running: true
        stdout: SplitParser {
            onRead: data => shell.handleBinding(data)
        }
    }

    // Native Sway focus does not depend on Qt having received a keypress in the overlay.
    Process {
        id: focusRequest
        property var target: null
        command: ["swaymsg", "-r", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                const target = focusRequest.target;
                focusRequest.target = null;
                if (!target) return;
                try {
                    const id = shell.findContainer(JSON.parse(text), target);
                    if (Number.isSafeInteger(id) && id > 0)
                        Quickshell.execDetached(["swaymsg", "[con_id=" + id + "]", "focus"]);
                    else
                        console.warn("App switcher: selected app no longer exists in Sway");
                } catch (error) {
                    console.warn("App switcher: failed to read Sway windows:", error);
                }
            }
        }
    }

    function accept(): void {
        if (!opened) return;
        const window = applications[selected].window;
        if (ToplevelManager.toplevels.values.includes(window)) {
            focusRequest.target = { appId: window.appId, title: window.title };
            focusRequest.running = true;
        }
        cancel();
    }

    function cancel(): void {
        opened = false;
        applications = [];
    }

    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged(): void {
            const active = ToplevelManager.activeToplevel;
            if (active) shell.history = shell.orderedWindows(
                ToplevelManager.toplevels.values, shell.history, active);
        }
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged(): void {
            shell.history = shell.history.filter(window => ToplevelManager.toplevels.values.includes(window));
            // Dismiss rather than retaining destroyed windows in the open snapshot.
            if (shell.opened) shell.cancel();
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void { shell.desktopRevision++; }
    }

    IpcHandler {
        target: "app-switcher"
        function next(): void { shell.step(1); }
        function previous(): void { shell.step(-1); }
    }

    PanelWindow {
        id: overlay
        visible: shell.opened
        implicitWidth: Math.min(32 + shell.applications.length * 112 + Math.max(0, shell.applications.length - 1) * 8,
            screen ? screen.width - 40 : 720)
        implicitHeight: 140
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "app-switcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: shell.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#1b1b1b"
            border.color: "#444444"

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) {
                        shell.step(-1);
                    } else if (event.key === Qt.Key_Right) {
                        shell.step(1);
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        shell.accept();
                    } else if (event.key === Qt.Key_Escape) {
                        shell.cancel();
                    }
                    event.accepted = true;
                }

                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) {
                        shell.accept();
                        event.accepted = true;
                    }
                }

                ListView {
                    id: apps
                    anchors.fill: parent
                    anchors.margins: 16
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    model: shell.applications
                    currentIndex: shell.selected
                    highlightMoveDuration: 0
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: width
                    highlightRangeMode: ListView.ApplyRange
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property var desktop: {
                            shell.desktopRevision;
                            return DesktopEntries.heuristicLookup(modelData.appId);
                        }
                        readonly property string appName: desktop ? desktop.name : (modelData.appId || "Application")
                        width: 112
                        height: apps.height
                        radius: 9
                        color: index === shell.selected ? "#407ebae4" : "transparent"
                        border.color: index === shell.selected ? "#7ebae4" : "transparent"

                        Image {
                            id: icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 12
                            width: 52
                            height: 52
                            sourceSize.width: 52
                            sourceSize.height: 52
                            source: Quickshell.iconPath(desktop && desktop.icon ? desktop.icon : "application-x-executable", true)
                        }
                        Text {
                            anchors.centerIn: icon
                            visible: icon.status !== Image.Ready
                            text: appName.charAt(0).toUpperCase()
                            color: "#eeeeee"
                            font.pixelSize: 28
                        }
                        Text {
                            x: 6
                            y: 76
                            width: parent.width - 12
                            text: appName
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            color: "#eeeeee"
                            font.pixelSize: 13
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { shell.selected = index; shell.accept(); }
                        }
                    }
                }
            }
        }
    }
}
