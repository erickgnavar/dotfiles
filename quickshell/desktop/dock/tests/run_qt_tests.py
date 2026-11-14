"""Run the dock's production animation bindings in a headless Qt Quick scene."""

import os
import shutil
import subprocess
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent


def block(source, marker):
    start = source.index(marker)
    opening = source.index("{", start)
    depth = 1
    for end in range(opening + 1, len(source)):
        depth += (source[end] == "{") - (source[end] == "}")
        if not depth:
            return source[start : end + 1]
    raise ValueError(f"Unclosed QML block: {marker}")


def main():
    runner = shutil.which("qmltestrunner")
    if not runner:
        raise SystemExit("Missing qmltestrunner; run in quickshell/qml-check.nix.")

    source = (HERE.parent / "Dock.qml").read_text()
    panel = block(source, "Rectangle {\n                    id: panel")
    # Execute production bindings, not copies of the animation settings. Isolate
    # only the visual motion: PanelWindow and input masks require a compositor.
    declarations = []
    for name in ("x", "width", "opacity"):
        declarations.append(
            next(
                line.strip()
                for line in panel.splitlines()
                if line.strip().startswith(f"{name}:")
            )
        )
    for name in ("x", "opacity"):
        declarations.append(block(panel, f"Behavior on {name}"))

    fixture = (
        "import QtQuick\nItem {\n"
        "id: dock\nproperty bool expanded: false\n"
        "property alias panel: panel\nRectangle {\nid: panel\n"
        + "\n".join(declarations)
        + "\n}\n}\n"
    )
    with tempfile.TemporaryDirectory(prefix="dock-qt-tests-") as directory:
        target = Path(directory)
        (target / "DockAnimation.qml").write_text(fixture)
        shutil.copyfile(HERE / "tst_animation.qml.in", target / "tst_animation.qml")
        env = os.environ.copy()
        env.setdefault("QT_QPA_PLATFORM", "offscreen")
        env.setdefault("QT_QUICK_BACKEND", "software")
        return subprocess.run(
            [runner, "-input", str(target)], env=env, timeout=30
        ).returncode


if __name__ == "__main__":
    raise SystemExit(main())
