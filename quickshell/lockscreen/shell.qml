import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtMultimedia

ShellRoot {
    id: shell

    property string pendingPassword: ""
    property bool firstResponse: false
    property bool waitingForPam: false
    property bool failed: false
    property bool unlocked: false
    property string status: "Enter your password"
    property string videoPath: ""
    readonly property bool busy: unlocked || waitingForPam
    readonly property color accent: unlocked ? "#2ecc71" : failed ? "#f53c3c" : "#7ebae4"

    signal clearInputs()
    signal typed()
    signal rejected()

    Component.onCompleted: Quickshell.watchFiles = false

    IpcHandler {
        target: "lock"
        function isSecure(): bool {
            return lock.secure && !shell.unlocked;
        }
    }

    function submit(password) {
        if (busy || (!password && !pam.active))
            return;
        failed = false;
        waitingForPam = true;
        status = "Checking…";
        if (pam.active && pam.responseRequired) {
            pam.respond(password);
        } else {
            pendingPassword = password;
            firstResponse = true;
            if (!pam.start()) {
                pendingPassword = "";
                firstResponse = false;
                waitingForPam = false;
                failed = true;
                status = "Could not start authentication";
                rejected();
            }
        }
        clearInputs();
    }

    PamContext {
        id: pam
        config: "quickshell-lockscreen"
        onPamMessage: {
            if (responseRequired) {
                if (shell.firstResponse && !responseVisible) {
                    shell.firstResponse = false;
                    const password = shell.pendingPassword;
                    shell.pendingPassword = "";
                    shell.waitingForPam = true;
                    respond(password);
                } else {
                    shell.firstResponse = false;
                    shell.pendingPassword = "";
                    shell.waitingForPam = false;
                    shell.status = message || "Authentication response required";
                }
            } else if (message) {
                shell.status = message;
            }
        }
        onCompleted: function (result) {
            shell.pendingPassword = "";
            shell.firstResponse = false;
            shell.waitingForPam = false;
            shell.clearInputs();
            if (result === PamResult.Success) {
                shell.unlocked = true;
                shell.status = "Unlocked";
                finish.start();
            } else {
                shell.failed = true;
                shell.status = result === PamResult.Error ? "Authentication unavailable" : "Incorrect password";
                shell.rejected();
            }
        }
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    Timer {
        id: finish
        interval: 450
        onTriggered: {
            lock.locked = false;
            Qt.callLater(Qt.quit);
        }
    }

    Process {
        command: ["bash", "-c", "find -H \"$HOME/Wallpapers\" -type f -iname '*.mp4' -readable -print0 2>/dev/null | shuf -z -n 1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: shell.videoPath = text.endsWith("\u0000") ? text.slice(0, -1) : ""
        }
    }

    // The launcher only returns to swayidle after the compositor confirms the lock.
    Process {
        id: ready
        command: ["touch", Quickshell.env("QUICKSHELL_LOCK_READY")]
        onExited: function (code) {
            if (code !== 0)
                console.error("Could not signal lock readiness; the launcher will report a timeout.");
        }
    }

    WlSessionLock {
        id: lock
        locked: true
        onSecureChanged: {
            if (secure && Quickshell.env("QUICKSHELL_LOCK_READY"))
                ready.running = true;
        }

        WlSessionLockSurface {
            color: "#253b4c"

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: "#253b4c" }
                    GradientStop { position: 1; color: "#151923" }
                }
            }

            Loader {
                anchors.fill: parent
                active: lock.secure && shell.videoPath !== ""
                sourceComponent: Item {
                    MediaPlayer {
                        id: player
                        source: {
                            const path = shell.videoPath;
                            return path ? "file://" + encodeURIComponent(path).replace(/%2F/gi, "/") : "";
                        }
                        videoOutput: video
                        loops: MediaPlayer.Infinite
                        onErrorOccurred: function (error, errorString) {
                            console.warn("Lockscreen video playback failed:", error, errorString);
                        }
                        onSourceChanged: {
                            if (source && lock.secure)
                                play();
                        }
                    }
                    VideoOutput {
                        id: video
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                        property bool hasFrame: false
                        visible: player.error === MediaPlayer.NoError
                        opacity: hasFrame ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                        Connections {
                            target: video.videoSink
                            enabled: !video.hasFrame
                            function onVideoFrameChanged() {
                                if (video.videoSink.videoSize.width > 0 && video.videoSink.videoSize.height > 0)
                                    video.hasFrame = true;
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "#66000000"
            }

            Flickable {
                id: content
                anchors.fill: parent
                contentWidth: width
                contentHeight: Math.max(height, clock.height + clock.gap + card.height + 24)
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                opacity: shell.unlocked ? 0 : 1
                scale: shell.unlocked ? 1.04 : 1
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.InCubic } }
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.InCubic } }

                Column {
                    id: clock
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(360, Math.max(0, parent.width - 48))
                    readonly property real gap: Math.max(12, Math.min(48, content.height * 0.06))
                    y: Math.max(12, (parent.height - height - card.height - gap) / 2)
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(systemClock.date, "HH:mm")
                        color: "#eeeeee"
                        font.pixelSize: Math.max(24, Math.min(88, content.height * 0.14, clock.width * 0.24))
                        font.weight: Font.Light
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(systemClock.date, "dddd, MMMM d")
                        color: "#bfffffff"
                        width: clock.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.pixelSize: Math.max(12, Math.min(20, content.height * 0.04))
                    }
                }

                Item {
                    id: card
                    width: clock.width
                    height: feedback.y + feedback.height + 24
                    anchors.top: clock.bottom
                    anchors.topMargin: clock.gap
                    anchors.horizontalCenter: parent.horizontalCenter
                    transform: Translate { id: shake }

                    Rectangle {
                        id: indicator
                        anchors.top: parent.top
                        anchors.topMargin: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(112, parent.width)
                        height: width
                        radius: width / 2
                        color: "#d90f0f0f"
                        border.width: 4
                        border.color: shell.accent
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        Rectangle {
                            id: ripple
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: parent.radius
                            color: "transparent"
                            border.width: 2
                            border.color: shell.accent
                            opacity: 0
                        }

                        Text {
                            anchors.centerIn: parent
                            text: shell.unlocked ? "✓" : shell.failed ? "!" : shell.waitingForPam ? "…" : ""
                            color: shell.accent
                            font.pixelSize: shell.unlocked ? 24 : 32
                        }
                    }

                    ParallelAnimation {
                        id: pulse
                        NumberAnimation { target: ripple; property: "scale"; from: 1; to: 1.14; duration: 320; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ripple; property: "opacity"; from: 0.7; to: 0; duration: 320 }
                    }

                    SequentialAnimation {
                        id: errorShake
                        NumberAnimation { target: shake; property: "x"; to: -12; duration: 50 }
                        NumberAnimation { target: shake; property: "x"; to: 12; duration: 70 }
                        NumberAnimation { target: shake; property: "x"; to: -8; duration: 70 }
                        NumberAnimation { target: shake; property: "x"; to: 8; duration: 70 }
                        NumberAnimation { target: shake; property: "x"; to: 0; duration: 70 }
                    }

                    Connections {
                        target: shell
                        function onTyped() { pulse.restart(); }
                        function onRejected() { errorShake.restart(); }
                        function onClearInputs() { password.clear(); }
                    }

                    TextField {
                        id: password
                        readonly property bool showResponse: pam.active && pam.responseRequired && pam.responseVisible
                        anchors.top: indicator.bottom
                        anchors.topMargin: showResponse ? 16 : 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(0, parent.width - 48)
                        height: showResponse ? 48 : 0
                        opacity: showResponse ? 1 : 0
                        focus: true
                        enabled: !shell.busy
                        echoMode: showResponse ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        Component.onCompleted: forceActiveFocus()
                        onEnabledChanged: {
                            if (enabled)
                                forceActiveFocus();
                        }
                        onTextEdited: {
                            if (shell.failed) {
                                shell.failed = false;
                                shell.status = "Enter your password";
                            }
                            shell.typed();
                        }
                        onAccepted: shell.submit(text)
                        Keys.onEscapePressed: {
                            clear();
                            pulse.stop();
                            ripple.opacity = 0;
                            if (shell.failed) {
                                shell.failed = false;
                                shell.status = "Enter your password";
                            }
                        }
                    }

                    Text {
                        id: feedback
                        anchors.top: password.bottom
                        anchors.topMargin: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.max(0, parent.width - 24)
                        text: shell.status
                        textFormat: Text.PlainText
                        color: shell.failed ? shell.accent : "#bfffffff"
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
