"""Execute production QML state/handlers with safe service doubles in Qt Quick Test."""

import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def block(source, marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 1
    for end in range(opening + 1, len(source)):
        depth += (source[end] == "{") - (source[end] == "}")
        if not depth:
            return source[start : end + 1]
    raise ValueError(f"Unclosed block: {marker}")


def property_declaration(source, name):
    match = re.search(
        rf"^    (?:readonly )?property \w+ {name}:.*"
        r"(?:\n(?:        .*|\s*))*",
        source,
        re.MULTILINE,
    )
    if not match:
        raise ValueError(f"Missing production property: {name}")
    return match.group().strip()


def process(name):
    return f"""
    property alias {name}: {name}
    QtObject {{
        id: {name}
        property bool running: false
        property var command: []
        property string written: ""
        property int lastSignal: 0
        property var target: null
        function write(text) {{ written += text; }}
        function signal(number) {{ lastSignal = number; }}
    }}
    """


def timer(name):
    return f"property alias {name}: {name}\nTimer {{ id: {name}; interval: 10000 }}"


def fixture(path, properties, functions, doubles, extra="", substitutions=None):
    source = (ROOT / path).read_text()
    body = "\n".join(property_declaration(source, name) for name in properties.split())
    body += "\n" + "\n".join(
        block(source, f"function {name}(") for name in functions.split()
    )
    for original, replacement in (substitutions or {}).items():
        body = body.replace(original, replacement)
    return (
        "import QtQuick\nimport QtQuick.Controls\nimport QtMultimedia\n"
        "Item {\nid: shell\n" + body + "\n" + doubles + "\n" + extra + "\n}\n"
    )


def generate(target):
    sources = {}
    sources["app_switcher/AppSwitcher.qml"] = fixture(
        "desktop/app_switcher/AppSwitcher.qml",
        "opened history applications selected desktopRevision",
        "orderedWindows buildApplications cycle findContainer step accept cancel handleBinding",
        process("focusRequest")
        + """
        property alias windows: toplevelsMock
        QtObject {
            id: toplevelsMock
            property var toplevels: ({values: []})
            property var activeToplevel: null
        }
        QtObject {
            id: entriesMock
            function heuristicLookup(appId) { return null; }
        }
        """,
        substitutions={
            "ToplevelManager": "toplevelsMock",
            "DesktopEntries": "entriesMock",
        },
    )
    capture = (ROOT / "desktop/capture/Capture.qml").read_text()
    sources["capture/Capture.qml"] = fixture(
        "desktop/capture/Capture.qml",
        "kind area audio audioSource recording stopping recordingRegion",
        "toggle capture stop",
        process("backend")
        + timer("captureDelay")
        + """
        property alias toolbar: toolbar
        QtObject { id: toolbar; property bool visible: false }
        """,
        extra=block(capture, "component CaptureButton:")
        + """
        property alias button: button
        CaptureButton { id: button; text: "Capture" }
        """,
    )
    sources["capture/Trimmer.qml"] = fixture(
        "desktop/capture/Trimmer.qml",
        "file duration error operation received cancelled startTime endTime valid",
        "formatTime togglePlayback run close",
        process("worker")
        + """
        property alias limits: limits
        RangeSlider { id: limits; from: 0; to: shell.duration }
        property alias player: player
        QtObject {
            id: player
            property int position: 0
            property int playbackState: MediaPlayer.StoppedState
            property string source: ""
            function play() { playbackState = MediaPlayer.PlayingState; }
            function pause() { playbackState = MediaPlayer.PausedState; }
            function stop() { playbackState = MediaPlayer.StoppedState; }
        }
        QtObject { id: window; property bool visible: true }
        """,
    )
    sources["color_picker/ColorPicker.qml"] = fixture(
        "desktop/color_picker/ColorPicker.qml",
        "picking pointFile patchFile patchSize magnification",
        "fileUrl shellQuote pick cancel",
        process("writer"),
    )
    sources["wallpaper_picker/WallpaperPicker.qml"] = fixture(
        "desktop/wallpaper_picker/WallpaperPicker.qml",
        "selectedPath selectedVideo selectedThumbnail selectedPreview scanError closeAfterApply",
        "fileUrl open close applyWallpaper select",
        process("scanner")
        + process("prepareFrame")
        + process("apply")
        + timer("videoDelay")
        + timer("framePrepareDelay")
        + """
        property alias wallpapers: wallpapers
        ListModel { id: wallpapers }
        property alias panel: panel
        QtObject { id: panel; property bool visible: false }
        property alias list: list
        Item { id: list; property int currentIndex: -1 }
        property alias player: player
        QtObject {
            id: player
            property string source: ""
            property int stops: 0
            function stop() { stops++; }
        }
        """,
    )
    sources["LockScreen.qml"] = fixture(
        "lockscreen/shell.qml",
        "pendingPassword firstResponse waitingForPam failed unlocked status videoPath busy accent",
        "submit",
        """
        signal clearInputs()
        signal rejected()
        property alias pam: pam
        QtObject {
            id: pam
            property bool active: false
            property bool responseRequired: false
            property bool startResult: true
            property int starts: 0
            property string response: ""
            function start() { starts++; return startResult; }
            function respond(password) { response = password; }
        }
        """,
    )
    # Load the real desktop composition, but resolve its imports to the safe
    # fixtures above. No Quickshell service or process is instantiated.
    desktop = (ROOT / "desktop/shell.qml").read_text()
    desktop = desktop.replace("import Quickshell", "import QtQuick")
    desktop = desktop.replace("ShellRoot {", "Item {")
    # Dock animation has its own runtime suite; this double checks composition only.
    sources["dock/Dock.qml"] = 'import QtQuick\nItem { objectName: "Dock" }\n'
    for path, text in sources.items():
        destination = target / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        if path != "dock/Dock.qml":
            text = text.replace(
                "id: shell\n", f'id: shell\nobjectName: "{destination.stem}"\n', 1
            )
        destination.write_text(text)
    (target / "Desktop.qml").write_text(desktop)
    shutil.copyfile(ROOT / "tests/tst_components.qml.in", target / "tst_components.qml")


def main():
    runner = shutil.which("qmltestrunner")
    if not runner:
        raise SystemExit("Missing qmltestrunner; run in quickshell/qml-check.nix.")
    with tempfile.TemporaryDirectory(prefix="quickshell-qt-tests-") as directory:
        target = Path(directory)
        generate(target)
        env = os.environ.copy()
        env.setdefault("QT_QPA_PLATFORM", "offscreen")
        env.setdefault("QT_QUICK_BACKEND", "software")
        return subprocess.run(
            [runner, "-input", str(target)], env=env, timeout=60
        ).returncode


if __name__ == "__main__":
    raise SystemExit(main())
