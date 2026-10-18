import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: shell

    property string kind: "screenshot"
    property string area: "region"
    property bool annotate: false
    property bool recording: false
    property bool stopping: false
    property var recordingRegion: null

    component CaptureButton: Button {
        id: control
        property bool selected: false
        property bool primary: false

        hoverEnabled: true
        padding: 10
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        opacity: enabled ? 1 : 0.5

        background: Rectangle {
            implicitWidth: 80
            implicitHeight: 36
            radius: 6
            color: control.down ? "#64727d"
                : control.primary ? (control.hovered ? "#9bcbec" : "#7ebae4")
                : control.selected ? (control.hovered ? "#527ebae4" : "#407ebae4")
                : control.hovered ? "#26ffffff" : "transparent"
            border.color: control.selected ? "#7ebae4" : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 9
                color: "transparent"
                border.color: "#eeeeee"
                border.width: 2
                visible: control.visualFocus
            }
        }

        contentItem: Text {
            text: control.text
            font: control.font
            color: control.primary ? "#0f0f0f" : "#eeeeee"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    function toggle() {
        if (!backend.running && !captureDelay.running)
            toolbar.visible = !toolbar.visible;
    }

    function capture() {
        if (backend.running || captureDelay.running)
            return;
        toolbar.visible = false;
        recordingRegion = null;
        captureDelay.start();
    }

    function stop() {
        if (!recording || stopping)
            return;
        stopping = true;
        backend.write("stop\n");
    }

    IpcHandler {
        target: "capture"
        function toggle(): void { shell.toggle(); }
        function stop(): void { shell.stop(); }
    }

    // Let the toolbar disappear before capturing or opening the region selector.
    Timer {
        id: captureDelay
        interval: 250
        onTriggered: {
            backend.command = ["bash", decodeURIComponent(Qt.resolvedUrl("capture.sh").toString().replace("file://", "")), shell.kind, shell.area, shell.annotate ? "annotate" : "plain"];
            backend.running = true;
        }
    }

    Process {
        id: backend
        stdinEnabled: true
        stdout: SplitParser {
            onRead: function (line) {
                const region = /^REGION (-?\d+),(-?\d+) (\d+)x(\d+)$/.exec(line);
                if (region) {
                    shell.recordingRegion = {
                        x: Number(region[1]), y: Number(region[2]),
                        width: Number(region[3]), height: Number(region[4])
                    };
                } else if (line === "RECORDING") {
                    shell.recording = true;
                }
            }
        }
        onExited: function (code) {
            shell.recording = false;
            shell.recordingRegion = null;
            shell.stopping = false;
            if (code !== 0)
                toolbar.visible = true;
        }
    }

    // Draw in compositor coordinates on each output, including regions spanning outputs.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: outline
            required property var modelData
            readonly property var region: shell.recordingRegion

            screen: modelData
            visible: shell.recording && region !== null
                && region.x - 2 < screen.x + screen.width
                && region.x + region.width + 2 > screen.x
                && region.y - 2 < screen.y + screen.height
                && region.y + region.height + 2 > screen.y
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Item {
                anchors.fill: parent
                clip: true

                Rectangle {
                    // Keep the entire stroke outside the recorded rectangle.
                    x: outline.region ? outline.region.x - outline.screen.x - 2 : 0
                    y: outline.region ? outline.region.y - outline.screen.y - 2 : 0
                    width: outline.region ? outline.region.width + 4 : 0
                    height: outline.region ? outline.region.height + 4 : 0
                    color: "transparent"
                    border.color: "#eb4d4b"
                    border.width: 2
                }
            }
        }
    }

    PanelWindow {
        id: toolbar
        visible: false
        anchors.bottom: true
        margins.bottom: 48
        implicitWidth: content.implicitWidth + 32
        implicitHeight: content.implicitHeight + 32
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: "#f20f0f0f"
            border.color: "#1fffffff"

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "CAPTURE"
                        color: "#7ebae4"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Enter ↵ · Esc"
                        color: "#bfbfbf"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                    CaptureButton {
                        text: "×"
                        implicitWidth: 36
                        opacity: hovered || visualFocus ? 1 : 0.65
                        onClicked: toolbar.visible = false
                        ToolTip.visible: hovered
                        ToolTip.text: "Close"
                        Accessible.name: "Close capture toolbar"
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Rectangle {
                        implicitWidth: modeButtons.implicitWidth + 8
                        implicitHeight: modeButtons.implicitHeight + 8
                        radius: 10
                        color: "#12ffffff"
                        border.color: "#1fffffff"

                        RowLayout {
                            id: modeButtons
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2
                            CaptureButton {
                                text: "Screenshot"
                                selected: shell.kind === "screenshot"
                                onClicked: shell.kind = "screenshot"
                            }
                            CaptureButton {
                                text: "Record"
                                selected: shell.kind === "record"
                                onClicked: shell.kind = "record"
                            }
                        }
                    }
                    Rectangle {
                        implicitWidth: areaButtons.implicitWidth + 8
                        implicitHeight: areaButtons.implicitHeight + 8
                        radius: 10
                        color: "#12ffffff"
                        border.color: "#1fffffff"

                        RowLayout {
                            id: areaButtons
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2
                            CaptureButton {
                                text: "Screen"
                                selected: shell.area === "screen"
                                onClicked: shell.area = "screen"
                            }
                            CaptureButton {
                                text: "Region"
                                selected: shell.area === "region"
                                onClicked: shell.area = "region"
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: "#1fffffff"
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    CheckBox {
                        id: annotateToggle
                        text: "Annotate in Swappy"
                        enabled: shell.kind === "screenshot"
                        checked: shell.annotate
                        onToggled: shell.annotate = annotateToggle.checked
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        spacing: 8
                        padding: 6
                        leftPadding: 0
                        opacity: enabled ? 1 : 0.4

                        contentItem: Text {
                            text: annotateToggle.text
                            font: annotateToggle.font
                            color: "#eeeeee"
                            leftPadding: annotateToggle.indicator.width + annotateToggle.spacing
                            verticalAlignment: Text.AlignVCenter
                        }

                        indicator: Rectangle {
                            x: annotateToggle.leftPadding
                            y: (annotateToggle.height - height) / 2
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 4
                            color: annotateToggle.checked ? "#7ebae4" : "transparent"
                            border.color: annotateToggle.visualFocus ? "#eeeeee" : "#7ebae4"
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                visible: annotateToggle.checked
                                color: "#0f0f0f"
                                font.pixelSize: 16
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    CaptureButton {
                        text: shell.kind === "record" ? "Start recording" : "Take screenshot"
                        primary: true
                        onClicked: shell.capture()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: (shell.area === "region" ? "Drag to select a region · " : "Focused screen · ")
                        + (shell.kind === "record" ? "No audio" : "Saved + copied to clipboard")
                    color: "#bfbfbf"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
            }
        }

        Shortcut {
            sequence: "Escape"
            enabled: toolbar.visible
            onActivated: toolbar.visible = false
        }
        Shortcut {
            sequence: "Return"
            enabled: toolbar.visible
            onActivated: shell.capture()
        }
    }
}
