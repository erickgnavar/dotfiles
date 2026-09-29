import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

ShellRoot {
    id: shell

    property string directory: Quickshell.env("HOME") + "/Wallpapers"
    property string selectedPath: ""
    property bool selectedVideo: false
    property string selectedThumbnail: ""
    property string selectedPreview: ""
    property string scanError: ""

    function fileUrl(path) {
        return path ? "file://" + encodeURIComponent(path).replace(/%2F/gi, "/") : "";
    }

    function open() {
        if (panel.visible) {
            list.forceActiveFocus();
            return;
        }
        wallpapers.clear();
        shell.selectedPath = "";
        shell.selectedThumbnail = "";
        shell.selectedPreview = "";
        shell.scanError = "";
        scanner.running = true;
        panel.visible = true;
        list.forceActiveFocus();
    }

    function close() {
        panel.visible = false;
        videoDelay.stop();
        player.stop();
        player.source = "";
        scanner.running = false;
    }

    function select(index) {
        if (wallpapers.count === 0 || index < 0 || index >= wallpapers.count)
            return;
        list.currentIndex = index;
        const entry = wallpapers.get(index);
        shell.selectedPath = entry.path;
        shell.selectedVideo = entry.video;
        shell.selectedThumbnail = entry.thumbnail;
        shell.selectedPreview = entry.preview || entry.thumbnail;
        videoDelay.stop();
        if (player.source) {
            player.stop();
            player.source = "";
        }
        if (entry.video)
            videoDelay.start();
    }

    IpcHandler {
        target: "picker"
        function toggle(): void {
            if (panel.visible)
                shell.close();
            else
                shell.open();
        }
    }

    ListModel {
        id: wallpapers
    }

    Process {
        id: scanner
        command: ["python3", Qt.resolvedUrl("scan.py").toString().replace("file://", ""), shell.directory]
        stdout: SplitParser {
            onRead: function (line) {
                if (!panel.visible)
                    return;
                try {
                    const entry = JSON.parse(line);
                    if (entry.error) {
                        shell.scanError = entry.error;
                    } else if (entry.video !== undefined) {
                        wallpapers.append(entry);
                        if (wallpapers.count === 1)
                            shell.select(0);
                    } else {
                        for (let i = 0; i < wallpapers.count; i++) {
                            if (wallpapers.get(i).path === entry.path) {
                                if (entry.thumbnail !== undefined) {
                                    wallpapers.setProperty(i, "thumbnail", entry.thumbnail);
                                    wallpapers.setProperty(i, "small", entry.small);
                                    if (shell.selectedPath === entry.path)
                                        shell.selectedThumbnail = entry.thumbnail;
                                    if (!wallpapers.get(i).preview) {
                                        wallpapers.setProperty(i, "preview", entry.thumbnail);
                                        if (shell.selectedPath === entry.path)
                                            shell.selectedPreview = entry.thumbnail;
                                    }
                                }
                                if (entry.preview !== undefined) {
                                    wallpapers.setProperty(i, "preview", entry.preview);
                                    if (shell.selectedPath === entry.path)
                                        shell.selectedPreview = entry.preview;
                                }
                                break;
                            }
                        }
                    }
                } catch (error) {
                    console.warn("Wallpaper scan:", error);
                }
            }
        }
    }

    Process {
        id: apply
        onExited: function (code) {
            if (code !== 0)
                console.warn("Could not apply wallpaper (exit " + code + ")");
        }
    }

    Timer {
        id: videoDelay
        interval: 600
        onTriggered: {
            if (panel.visible && shell.selectedVideo) {
                player.source = shell.fileUrl(shell.selectedPath);
                player.play();
            }
        }
    }

    MediaPlayer {
        id: player
        videoOutput: videoOutput
        loops: MediaPlayer.Infinite
    }

    PanelWindow {
        id: panel
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        visible: false
        onVisibleChanged: {
            if (visible)
                Qt.callLater(function () {
                    list.forceActiveFocus();
                });
        }

        Shortcut {
            sequence: "Ctrl+N"
            enabled: panel.visible
            onActivated: shell.select((list.currentIndex + 1) % wallpapers.count)
        }
        Shortcut {
            sequence: "Ctrl+P"
            enabled: panel.visible
            onActivated: shell.select((list.currentIndex - 1 + wallpapers.count) % wallpapers.count)
        }

        FocusScope {
            id: keyboard
            anchors.fill: parent
            focus: true
            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Escape)
                    shell.close();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (shell.selectedPath && !apply.running) {
                        apply.command = ["bash", Qt.resolvedUrl("apply.sh").toString().replace("file://", ""), shell.selectedPath];
                        apply.running = true;
                        shell.close();
                    }
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_N)) {
                    shell.select((list.currentIndex + 1) % wallpapers.count);
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_P)) {
                    shell.select((list.currentIndex - 1 + wallpapers.count) % wallpapers.count);
                } else
                    return;
                event.accepted = true;
            }

            Rectangle {
                anchors.fill: parent
                color: "#99000000"
                MouseArea {
                    anchors.fill: parent
                    onClicked: shell.close()
                }
            }

            Rectangle {
                width: Math.min(1200, parent.width - 48)
                height: Math.min(760, parent.height - 48)
                anchors.centerIn: parent
                radius: 12
                color: "#f20f0f0f"
                border.color: "#1fffffff"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 16

                        ListView {
                            id: list
                            focus: true
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0 && currentIndex < wallpapers.count && shell.selectedPath !== wallpapers.get(currentIndex).path)
                                    shell.select(currentIndex);
                            }
                            Layout.preferredWidth: 120
                            Layout.fillHeight: true
                            clip: true
                            spacing: 12
                            model: wallpapers
                            highlightMoveDuration: 0
                            delegate: Rectangle {
                                required property string path
                                required property string thumbnail
                                required property bool small
                                required property int index
                                width: list.width
                                height: 90
                                radius: 6
                                color: index === list.currentIndex ? "#64727d" : "#26ffffff"

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: shell.fileUrl(thumbnail)
                                    sourceSize.width: 200
                                    sourceSize.height: 120
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: !small
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        shell.select(index);
                                        list.forceActiveFocus();
                                    }
                                    onDoubleClicked: {
                                        shell.select(index);
                                        if (!apply.running) {
                                            apply.command = ["bash", Qt.resolvedUrl("apply.sh").toString().replace("file://", ""), path];
                                            apply.running = true;
                                            shell.close();
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Image {
                                anchors.fill: parent
                                source: shell.fileUrl(shell.selectedPreview)
                                sourceSize.width: 1200
                                sourceSize.height: 760
                                cache: false
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: player.playbackState !== MediaPlayer.PlayingState
                            }
                            VideoOutput {
                                id: videoOutput
                                anchors.fill: parent
                                fillMode: VideoOutput.PreserveAspectFit
                                visible: player.playbackState === MediaPlayer.PlayingState
                            }
                            Label {
                                id: message
                                anchors.centerIn: parent
                                visible: !shell.selectedPath
                                text: shell.scanError || "No wallpapers found"
                                color: "#eeeeee"
                            }
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Arrow keys to navigate · Enter to select · Escape to cancel"
                        color: "#aaaaaa"
                    }
                }
            }
        }
    }
}
