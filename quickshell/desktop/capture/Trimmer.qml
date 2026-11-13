import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Scope {
    id: shell

    property string file: ""
    property real duration: 0
    property string error: ""
    property string operation: "probe"
    property bool received: false
    property bool cancelled: false
    readonly property real startTime: limits.first.value
    readonly property real endTime: limits.second.value
    readonly property bool valid: isFinite(startTime) && isFinite(endTime)
        && startTime >= 0 && startTime < endTime && endTime <= duration

    function formatTime(seconds) {
        const milliseconds = Math.max(0, Math.round(seconds * 1000));
        const minutes = Math.floor(milliseconds / 60000);
        const remainder = Math.floor(milliseconds / 1000) % 60;
        return String(minutes).padStart(2, "0") + ":"
            + String(remainder).padStart(2, "0") + "."
            + String(milliseconds % 1000).padStart(3, "0");
    }

    function togglePlayback() {
        if (duration <= 0 || worker.running)
            return;
        if (player.playbackState === MediaPlayer.PlayingState)
            player.pause();
        else {
            if (player.position < startTime * 1000 || player.position >= endTime * 1000)
                player.position = shell.startTime * 1000;
            player.play();
        }
    }

    function run(mode) {
        error = "";
        operation = mode;
        received = false;
        cancelled = false;
        let args = ["python3", decodeURIComponent(Qt.resolvedUrl("trim.py").toString().replace("file://", "")), mode, file];
        if (mode === "trim")
            args = args.concat([String(startTime), String(endTime)]);
        worker.command = args;
        worker.running = true;
    }

    function close() {
        window.visible = false;
        player.stop();
        player.source = "";
        cancelled = true;
        if (worker.running)
            worker.signal(15);
    }

    IpcHandler {
        target: "trimmer"
        function open(path: string): void {
            if (worker.running)
                return;
            shell.file = path;
            shell.duration = 0;
            player.stop();
            player.source = "";
            limits.setValues(0, 0);
            window.visible = true;
            shell.run("probe");
        }
    }

    Process {
        id: worker
        stdout: SplitParser {
            onRead: line => {
                shell.received = true;
                if (shell.cancelled)
                    return;
                try {
                    const result = JSON.parse(line);
                    if (result.error) {
                        shell.error = result.error;
                    } else if (shell.operation === "probe") {
                        shell.duration = result.duration;
                        limits.setValues(0, result.duration);
                        player.source = result.url;
                        player.pause();
                    } else {
                        Quickshell.execDetached(["bash", decodeURIComponent(Qt.resolvedUrl("notify-capture.sh").toString().replace("file://", "")), "record", result.file]);
                        shell.close();
                    }
                } catch (error) {
                    shell.error = "Could not read trim result: " + error;
                }
            }
        }
        onExited: (code) => {
            if (!shell.cancelled && !shell.received)
                shell.error = "Media helper exited without a result (" + code + ").";
        }
    }

    MediaPlayer {
        id: player
        videoOutput: preview
        audioOutput: AudioOutput { }
        onPositionChanged: {
            if (playbackState === MediaPlayer.PlayingState && position >= shell.endTime * 1000) {
                pause();
                position = shell.endTime * 1000;
            }
        }
        onErrorOccurred: (error, message) => {
            if (window.visible)
                shell.error = "Preview: " + message;
        }
    }

    component TrimButton: Button {
        id: control
        property bool primary: false
        padding: 10
        horizontalPadding: 16
        font.pixelSize: 12
        opacity: enabled ? 1 : 0.45
        background: Rectangle {
            radius: 6
            color: control.primary
                ? (control.down ? "#558fb9" : control.hovered ? "#9acced" : "#7ebae4")
                : (control.down ? "#383838" : control.hovered ? "#303030" : "#242424")
            border.color: control.visualFocus ? "#7ebae4" : "transparent"
        }
        contentItem: Text {
            text: control.text
            font: control.font
            color: control.primary ? "#181818" : "#eeeeee"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    FloatingWindow {
        id: window
        visible: false
        title: "Trim recording"
        implicitWidth: 840
        implicitHeight: 660
        color: "#181818"
        onClosed: shell.close()

        Shortcut {
            sequence: "Space"
            context: Qt.WindowShortcut
            enabled: window.visible && shell.duration > 0 && !worker.running
            onActivated: shell.togglePlayback()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            focus: true
            Keys.onEscapePressed: shell.close()

            Text {
                text: "Trim recording"
                color: "#eeeeee"
                font.pixelSize: 18
            }
            Text {
                Layout.fillWidth: true
                text: shell.file
                elide: Text.ElideMiddle
                color: "#aaaaaa"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 320
                color: "#000000"
                VideoOutput {
                    id: preview
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                }
            }
            RowLayout {
                TrimButton {
                    text: player.playbackState === MediaPlayer.PlayingState ? "Pause" : "Play"
                    enabled: shell.duration > 0 && !worker.running
                    onClicked: shell.togglePlayback()
                }
                Text {
                    text: shell.formatTime(player.position / 1000) + " / " + shell.formatTime(shell.duration)
                    color: "#eeeeee"
                }
            }
            RangeSlider {
                id: limits
                Layout.fillWidth: true
                enabled: shell.duration > 0 && !worker.running
                from: 0
                to: shell.duration
                implicitHeight: 32
                readonly property real trackLeft: leftPadding + first.handle.width / 2
                readonly property real trackWidth: Math.max(1, availableWidth - first.handle.width)

                function seekAt(x) {
                    player.pause();
                    player.position = Math.max(0, Math.min(1, (x - trackLeft) / trackWidth))
                        * shell.duration * 1000;
                }

                // Scrubbing must not let RangeSlider move the nearest trim handle.
                MouseArea {
                    anchors.fill: parent
                    z: 3
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => {
                        const startX = limits.first.handle.x + limits.first.handle.width / 2;
                        const endX = limits.second.handle.x + limits.second.handle.width / 2;
                        if (Math.abs(mouse.x - startX) <= 10 || Math.abs(mouse.x - endX) <= 10) {
                            mouse.accepted = false;
                            return;
                        }
                        limits.seekAt(mouse.x);
                    }
                    onPositionChanged: mouse => {
                        if (pressed)
                            limits.seekAt(mouse.x);
                    }
                }
                Rectangle {
                    z: 2
                    x: limits.trackLeft + Math.max(0, Math.min(1,
                        shell.duration > 0 ? player.position / (shell.duration * 1000) : 0))
                        * limits.trackWidth - width / 2
                    y: limits.topPadding
                    width: 2
                    height: limits.availableHeight
                    radius: 1
                    color: "#eeeeee"
                }
                background: Rectangle {
                    x: limits.trackLeft
                    y: limits.topPadding + (limits.availableHeight - height) / 2
                    width: limits.trackWidth
                    height: 6
                    radius: 3
                    color: "#383838"
                    Rectangle {
                        x: limits.first.visualPosition * parent.width
                        width: (limits.second.visualPosition - limits.first.visualPosition) * parent.width
                        height: parent.height
                        radius: 3
                        color: "#7ebae4"
                    }
                }
                first.handle: Rectangle {
                    x: limits.leftPadding + limits.first.visualPosition * (limits.availableWidth - width)
                    y: limits.topPadding + (limits.availableHeight - height) / 2
                    implicitWidth: 14
                    implicitHeight: 28
                    radius: 4
                    color: limits.first.pressed ? "#eeeeee" : "#7ebae4"
                    border.color: limits.visualFocus ? "#eeeeee" : "#181818"
                    border.width: 2
                }
                second.handle: Rectangle {
                    x: limits.leftPadding + limits.second.visualPosition * (limits.availableWidth - width)
                    y: limits.topPadding + (limits.availableHeight - height) / 2
                    implicitWidth: 14
                    implicitHeight: 28
                    radius: 4
                    color: limits.second.pressed ? "#eeeeee" : "#7ebae4"
                    border.color: limits.visualFocus ? "#eeeeee" : "#181818"
                    border.width: 2
                }
            }
            RowLayout {
                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    text: "Start: " + shell.formatTime(shell.startTime)
                    color: "#eeeeee"
                }
                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "Selected: " + shell.formatTime(shell.endTime - shell.startTime)
                    color: "#7ebae4"
                }
                Text {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    horizontalAlignment: Text.AlignRight
                    text: "End: " + shell.formatTime(shell.endTime)
                    color: "#eeeeee"
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Fast lossless cut: boundaries may snap to keyframes. Original stays unchanged."
                color: "#aaaaaa"
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: shell.error !== ""
                text: shell.error
                color: "#eb4d4b"
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            RowLayout {
                Text {
                    Layout.fillWidth: true
                    text: worker.running ? (shell.operation === "probe" ? "Loading…" : "Saving…") : ""
                    color: "#aaaaaa"
                }
                TrimButton { text: "Cancel"; onClicked: shell.close() }
                TrimButton {
                    text: "Save trimmed copy"
                    primary: true
                    enabled: shell.valid && !worker.running
                    onClicked: {
                        player.pause();
                        shell.run("trim");
                    }
                }
            }
        }
    }
}
