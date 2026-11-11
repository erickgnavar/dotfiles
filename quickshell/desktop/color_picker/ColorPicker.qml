import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: picker

    property bool picking: false
    property string pointFile: ""
    readonly property string patchFile: pointFile === ""
        ? "" : pointFile.replace(/\/[^/]+$/, "/patch.png")
    readonly property int patchSize: 32
    readonly property int magnification: 8

    function fileUrl(path) {
        return path ? "file://" + encodeURIComponent(path).replace(/%2F/gi, "/") : "";
    }

    function shellQuote(value) {
        return "'" + value.replace(/'/g, "'\\''") + "'";
    }

    // Invoked by copy-color.sh over IPC; the file receives the picked
    // position, and the magnifier patch is rendered next to it.
    function pick(file) {
        pointFile = file;
        picking = true;
    }

    // Cancelling touches the file so the calling script stops polling with
    // an empty selection.
    function cancel() {
        if (!picking)
            return;
        picking = false;
        // The click's writer already reset pointFile once it wrote the
        // point; touching is then pointless and would target an empty path.
        if (pointFile === "")
            return;
        writer.command = ["touch", pointFile];
        writer.running = true;
    }

    IpcHandler {
        target: "colorpicker"
        function pick(file: string): void { picker.pick(file); }
        // Lets the caller dismiss a stuck overlay (e.g. on timeout).
        function cancel(): void { picker.cancel(); }
    }

    // Writes the picked compositor coordinate pair, or nothing on cancel.
    Process {
        id: writer
        command: []
        onExited: picker.pointFile = ""
    }

    // One fullscreen overlay per output; the magnifier patch is captured in
    // compositor coordinates, exactly what grim on the shell side consumes.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData

            property int patchX: 0
            property int patchY: 0
            // Origin of the image currently displayed. patchX/patchY are the
            // origin of the grab in flight, which the cross must never use.
            property int shownX: 0
            property int shownY: 0
            property int pointX: 0
            property int pointY: 0
            property int revision: 0
            property string patchTarget: ""

            // Index of the picked pixel inside the displayed patch. Tracked
            // against the shown image so the cross never lies about where
            // the cursor is; clamped while the shown patch lags behind.
            readonly property int pixelX: Math.min(Math.max(
                screen.x + pointX - shownX, 0), picker.patchSize - 1)
            readonly property int pixelY: Math.min(Math.max(
                screen.y + pointY - shownY, 0), picker.patchSize - 1)

            screen: modelData
            visible: picker.picking
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus:
                picker.picking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: {
                refresh.watch = visible;
                if (!visible) {
                    revision = 0;
                    patchTarget = "";
                    patchX = 0;
                    patchY = 0;
                    shownX = 0;
                    shownY = 0;
                    pointX = 0;
                    pointY = 0;
                }
            }

            function refreshPatch() {
                // Always track the cursor so picks reflect where the user
                // actually clicks; only the grab waits for the previous one.
                if (!area.containsMouse)
                    return;
                const x = Math.round(area.mouseX);
                const y = Math.round(area.mouseY);
                pointX = x;
                pointY = y;
                if (grabber.running)
                    return;
                // Re-grab only when the shown patch no longer contains the
                // cursor; otherwise a grab finishing after the cursor stops
                // would leave a stale preview and a misaligned highlight.
                if (revision > 0
                    && screen.x + x >= shownX
                    && screen.x + x < shownX + picker.patchSize
                    && screen.y + y >= shownY
                    && screen.y + y < shownY + picker.patchSize)
                    return;
                const half = picker.patchSize / 2;
                const gx = screen.x + x;
                const gy = screen.y + y;
                // The grab box is in global compositor space, so clamp it
                // with the screen's global bounds, not window-local ones.
                patchX = Math.min(Math.max(gx - half, screen.x),
                    screen.x + screen.width - picker.patchSize);
                patchY = Math.min(Math.max(gy - half, screen.y),
                    screen.y + screen.height - picker.patchSize);
                // Qt cannot load "file.png?r=N" URLs; revision the filename
                // instead, one grab at a time.
                const target = picker.patchFile.replace(
                    /\.png$/, "-" + (revision + 1) + ".png");
                grabber.targetFile = target;
                // "grim -g" expects "<x>,<y> <width>x<height>".
                grabber.command = ["grim", "-g",
                    patchX + "," + patchY + " "
                        + picker.patchSize + "x" + picker.patchSize,
                    target];
                grabber.running = true;
            }

            Timer {
                id: refresh
                property bool watch: false
                interval: 25
                repeat: true
                running: watch && overlay.visible
                onTriggered: overlay.refreshPatch()
            }

            Process {
                id: grabber
                property string targetFile: ""
                onExited: function (code) {
                    // A grab finishing after hide must not leak its stale
                    // patch into the next pick.
                    if (!overlay.visible)
                        return;
                    if (code !== 0)
                        console.warn("magnifier grab failed with status", code);
                    overlay.revision++;
                    overlay.patchTarget = targetFile;
                    overlay.shownX = overlay.patchX;
                    overlay.shownY = overlay.patchY;
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                // A visible cursor is composited into grim's capture, and
                // the picked pixel is the cursor hotspot, so picks kept
                // returning the cursor's white outline. The magnifier's
                // red highlight marks the spot instead.
                cursorShape: Qt.BlankCursor
                onPositionChanged: refresh.watch = true

                onClicked: mouse => {
                    // Without a tracked position the point file would get a
                    // bogus constant value; treat a click before the first
                    // reported position as a cancellation.
                    if (!area.containsMouse) {
                        picker.cancel();
                        return;
                    }
                    // Pick exactly where the user clicked: pointX can lag
                    // one grab cycle behind the cursor.
                    const x = overlay.screen.x + Math.round(mouse.x);
                    const y = overlay.screen.y + Math.round(mouse.y);
                    // The overlay must stay up (with its blank cursor) while
                    // copy-color.sh captures the pixel, and is cancelled by
                    // the script afterwards. Stop the grabs so they do not
                    // race the read.
                    refresh.watch = false;
                    writer.command = ["sh", "-c", "printf '%s\\n' '" + x + " " + y
                        + "' > " + picker.shellQuote(picker.pointFile)];
                    writer.running = true;
                }
            }

            Rectangle {
                id: panel
                // Parked at the right edge — top corner by default — so it
                // does not chase the cursor. It flips to the bottom-right
                // corner only when the cursor's grab patch would reach it:
                // the magnifier must never capture itself.
                readonly property int gutter: 8
                // The grab patch extends patchSize / 2 around the cursor;
                // keep a comfortable margin beyond that before flipping.
                readonly property int reach: picker.patchSize / 2 + 24
                x: parent.width - width - gutter
                y: Math.round(area.mouseX) + reach >= x
                    && Math.round(area.mouseY) - reach <= gutter + height
                    ? parent.height - height - gutter
                    : gutter
                width: picker.magnification * picker.patchSize + 20
                height: picker.magnification * picker.patchSize + 44
                radius: 10
                color: "#f20f0f0f"
                border.color: "#1fffffff"
                visible: overlay.revision > 0

                Image {
                    id: patch
                    x: 10
                    y: 10
                    width: picker.patchSize * picker.magnification
                    height: width
                    smooth: false
                    fillMode: Image.Stretch
                    source: patchTarget ? picker.fileUrl(patchTarget) : ""

                    Rectangle { // highlight the exact picked pixel; the
                        // border sits outside it so the color stays clean.
                        x: overlay.pixelX * picker.magnification - 2
                        y: overlay.pixelY * picker.magnification - 2
                        width: picker.magnification + 4
                        height: picker.magnification + 4
                        color: "transparent"
                        border.color: "#eb4d4b"
                        border.width: 2
                    }
                }

                Text {
                    x: 10
                    y: patch.y + patch.height + 8
                    text: "Click: pick · Esc: cancel"
                    color: "#bfbfbf"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }
            }

            // Ring marking the pointer position. The compositor cursor is
            // hidden while picking, and the ring's center stays open so
            // grim never captures the marker over the picked pixel.
            Rectangle {
                x: Math.round(area.mouseX) - width / 2
                y: Math.round(area.mouseY) - height / 2
                width: 16
                height: 16
                radius: 8
                color: "transparent"
                border.color: "#eb4d4b"
                border.width: 2
            }

            Shortcut {
                sequence: "Escape"
                enabled: picker.picking
                onActivated: picker.cancel()
            }
        }
    }
}
