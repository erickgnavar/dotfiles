pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Scope {
    id: shell

    property string directory: Quickshell.env("HOME") + "/Wallpapers"
    property string selectedPath: ""
    property bool selectedVideo: false
    property string selectedThumbnail: ""
    property string selectedPreview: ""
    property string scanError: ""
    property bool closeAfterApply: false
    property var wallpaperIndices: new Map()
    property int scanGeneration: 0

    function fileUrl(path) {
        return path ? "file://" + encodeURIComponent(path).replace(/%2F/gi, "/") : "";
    }

    function open() {
        if (panel.visible) {
            list.forceActiveFocus();
            return;
        }
        shell.scanGeneration++;
        shell.wallpaperIndices = new Map();
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
        framePrepareDelay.stop();
        prepareFrame.running = false;
    }

    function applyWallpaper(path, frame0) {
        if (!path || apply.running)
            return;
        if (frame0) {
            framePrepareDelay.stop();
            prepareFrame.running = false;
        }
        apply.command = ["bash", Qt.resolvedUrl("apply.sh").toString().replace("file://", "")];
        if (frame0)
            apply.command.push("--frame0");
        apply.command.push(path);
        shell.closeAfterApply = frame0;
        apply.running = true;
        if (!frame0)
            shell.close();
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
        framePrepareDelay.stop();
        prepareFrame.running = false;
        if (entry.video)
            framePrepareDelay.start();
        videoDelay.stop();
        if (player.source) {
            player.stop();
            player.source = "";
        }
        if (entry.video)
            videoDelay.start();
    }

    function updateWallpaper(entry) {
        if (!panel.visible || entry.generation !== shell.scanGeneration)
            return;
        if (entry.error) {
            shell.scanError = entry.error;
        } else if (entry.video !== undefined) {
            const index = wallpapers.count;
            // Generation is transport metadata, not a model role.
            delete entry.generation;
            wallpapers.append(entry);
            shell.wallpaperIndices.set(entry.path, index);
            if (wallpapers.count === 1)
                shell.select(0);
        } else {
            const index = shell.wallpaperIndices.get(entry.path);
            if (index === undefined)
                return;
            if (entry.thumbnail !== undefined) {
                wallpapers.setProperty(index, "thumbnail", entry.thumbnail);
                wallpapers.setProperty(index, "small", entry.small);
                if (shell.selectedPath === entry.path)
                    shell.selectedThumbnail = entry.thumbnail;
                if (!wallpapers.get(index).preview) {
                    wallpapers.setProperty(index, "preview", entry.thumbnail);
                    if (shell.selectedPath === entry.path)
                        shell.selectedPreview = entry.thumbnail;
                }
            }
            if (entry.preview !== undefined) {
                wallpapers.setProperty(index, "preview", entry.preview);
                if (shell.selectedPath === entry.path)
                    shell.selectedPreview = entry.preview;
            }
        }
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
        command: ["python3", Qt.resolvedUrl("scan.py").toString().replace("file://", ""), shell.directory, String(shell.scanGeneration)]
        stdout: SplitParser {
            onRead: function (line) {
                if (!panel.visible)
                    return;
                try {
                    shell.updateWallpaper(JSON.parse(line));
                } catch (error) {
                    console.warn("Wallpaper scan:", error);
                }
            }
        }
    }

    Process {
        id: prepareFrame
        onExited: function (code) {
            if (code !== 0)
                console.warn("Could not prepare video frame (exit " + code + ")");
        }
    }

    Process {
        id: apply
        onExited: function (code) {
            if (code === 0 && shell.closeAfterApply) {
                shell.closeAfterApply = false;
                shell.close();
            } else if (code !== 0) {
                shell.closeAfterApply = false;
                console.warn("Could not apply wallpaper (exit " + code + ")");
            }
        }
    }

    Timer {
        id: framePrepareDelay
        interval: 400
        onTriggered: {
            if (panel.visible && shell.selectedVideo) {
                prepareFrame.command = ["bash", Qt.resolvedUrl("extract-frame.sh").toString().replace("file://", ""), shell.selectedPath];
                prepareFrame.running = true;
            }
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
        videoOutput: wallpaperVideo
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
                    if (shell.selectedPath)
                        shell.applyWallpaper(shell.selectedPath, false);
                } else if (event.key === Qt.Key_F && shell.selectedVideo) {
                    shell.applyWallpaper(shell.selectedPath, true);
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
                                id: wallpaperEntry
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
                                    source: shell.fileUrl(wallpaperEntry.thumbnail)
                                    sourceSize.width: 200
                                    sourceSize.height: 120
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: !wallpaperEntry.small
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        shell.select(wallpaperEntry.index);
                                        list.forceActiveFocus();
                                    }
                                    onDoubleClicked: {
                                        shell.select(wallpaperEntry.index);
                                        shell.applyWallpaper(wallpaperEntry.path, false);
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
                                id: wallpaperVideo
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

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        Button {
                            id: frameButton
                            visible: shell.selectedVideo
                            text: "Use image from video"
                            padding: 8
                            enabled: !apply.running
                            onClicked: shell.applyWallpaper(shell.selectedPath, true)

                            background: Rectangle {
                                implicitWidth: 110
                                implicitHeight: 32
                                radius: 6
                                color: frameButton.down
                                    ? "#64727d"
                                    : frameButton.hovered ? "#3dffffff" : "#26ffffff"
                                border.color: "#1fffffff"
                            }

                            contentItem: Text {
                                text: frameButton.text
                                color: "#eeeeee"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Label {
                            text: shell.selectedVideo
                                ? "F: use image from video · Enter: use video · Escape to cancel"
                                : "Arrow keys to navigate · Enter to select · Escape to cancel"
                            color: "#aaaaaa"
                        }
                    }
                }
            }
        }
    }
}
