pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: shell

    property string kind: "screenshot"
    property string area: "region"
    property bool audio: false
    property string audioSource: "default"
    property var audioSources: {
        const sources = Pipewire.nodes.values.filter(node => node.audio !== null
            && !node.isSink && !node.isStream && node.name
            && !node.name.endsWith(".monitor")).map(node => ({
                label: node.description || node.nickname || node.name,
                name: node.name
            }));
        sources.sort((left, right) => left.label.localeCompare(right.label));
        return [{ label: "Default microphone", name: "default" }].concat(sources);
    }
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
            backend.command = [
                "bash",
                decodeURIComponent(Qt.resolvedUrl("capture.sh").toString().replace("file://", "")),
                shell.kind,
                shell.area,
                shell.audio ? "audio" : "silent",
                audioSourcePicker.currentValue || "default"
            ];
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
            visible: shell.recording && outline.region !== null
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
                        id: optionToggle
                        visible: shell.kind === "record"
                        text: "Include audio"
                        checked: shell.audio
                        onToggled: shell.audio = optionToggle.checked
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        spacing: 8
                        padding: 6
                        leftPadding: 0

                        contentItem: Text {
                            text: optionToggle.text
                            font: optionToggle.font
                            color: "#eeeeee"
                            leftPadding: optionToggle.indicator.width + optionToggle.spacing
                            verticalAlignment: Text.AlignVCenter
                        }

                        indicator: Rectangle {
                            x: optionToggle.leftPadding
                            y: (optionToggle.height - height) / 2
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 4
                            color: optionToggle.checked ? "#7ebae4" : "transparent"
                            border.color: optionToggle.visualFocus ? "#eeeeee" : "#7ebae4"
                            border.width: 2

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                visible: optionToggle.checked
                                color: "#0f0f0f"
                                font.pixelSize: 16
                            }
                        }
                    }
                    ComboBox {
                        id: audioSourcePicker
                        visible: shell.kind === "record" && shell.audio
                        Layout.preferredWidth: 240
                        model: shell.audioSources
                        textRole: "label"
                        valueRole: "name"
                        currentIndex: Math.max(0, shell.audioSources.findIndex(
                            source => source.name === shell.audioSource))
                        implicitHeight: 36
                        leftPadding: 12
                        rightPadding: 34
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        onActivated: shell.audioSource = currentValue

                        background: Rectangle {
                            radius: 6
                            color: audioSourcePicker.down ? "#64727d"
                                : audioSourcePicker.hovered ? "#26ffffff" : "#12ffffff"
                            border.color: audioSourcePicker.visualFocus
                                ? "#eeeeee" : "#1fffffff"
                            border.width: audioSourcePicker.visualFocus ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        contentItem: Text {
                            text: audioSourcePicker.displayText
                            font: audioSourcePicker.font
                            color: "#eeeeee"
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        indicator: Text {
                            x: audioSourcePicker.width - width - 12
                            y: (audioSourcePicker.height - height) / 2
                            text: "▾"
                            color: "#7ebae4"
                            font: audioSourcePicker.font
                        }

                        delegate: ItemDelegate {
                            id: sourceOption
                            required property int index
                            required property var modelData
                            width: audioSourcePicker.width
                            height: 34
                            padding: 10
                            highlighted: audioSourcePicker.highlightedIndex === index

                            background: Rectangle {
                                radius: 4
                                color: sourceOption.highlighted ? "#407ebae4"
                                    : sourceOption.hovered ? "#26ffffff" : "transparent"
                            }

                            contentItem: Text {
                                text: sourceOption.modelData.label
                                font: audioSourcePicker.font
                                color: "#eeeeee"
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }

                        popup: Popup {
                            y: audioSourcePicker.height + 4
                            width: audioSourcePicker.width
                            implicitHeight: Math.min(contentItem.implicitHeight + 8, 220)
                            padding: 4

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: audioSourcePicker.popup.visible
                                    ? audioSourcePicker.delegateModel : null
                                currentIndex: audioSourcePicker.highlightedIndex
                                ScrollIndicator.vertical: ScrollIndicator {}
                            }

                            background: Rectangle {
                                radius: 8
                                color: "#f20f0f0f"
                                border.color: "#407ebae4"
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
                    text: (shell.area === "region"
                            ? "Drag to select a region · " : "Focused screen · ")
                        + (shell.kind === "record"
                            ? (shell.audio ? "Audio: " + audioSourcePicker.currentText
                                : "No audio")
                            : "Saved + copied to clipboard")
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
