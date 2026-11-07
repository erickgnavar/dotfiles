#!/usr/bin/env python3
import os
import subprocess
from urllib.parse import unquote_to_bytes, urlsplit


def fail(message: str) -> None:
    subprocess.run(["notify-send", "Copy Full Paths", message], check=False)
    raise SystemExit(1)


selected = os.environ.get("NAUTILUS_SCRIPT_SELECTED_URIS", "").splitlines()
if not selected:
    fail("No files or folders were selected.")

paths: list[str] = []
for uri in selected:
    parsed = urlsplit(uri)
    if parsed.scheme != "file" or parsed.netloc not in ("", "localhost"):
        fail("Only local files and folders have full local paths.")
    if parsed.query or parsed.fragment:
        fail("A selected file has an unsupported URI.")
    paths.append(os.fsdecode(unquote_to_bytes(parsed.path)))

try:
    subprocess.run(
        ["wl-copy", "--type", "text/plain;charset=utf-8"],
        input=os.fsencode("\n".join(paths)),
        check=True,
    )
except (OSError, subprocess.CalledProcessError) as error:
    fail(f"Could not copy paths: {error}")
