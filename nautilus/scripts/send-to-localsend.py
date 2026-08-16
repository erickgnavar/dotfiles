#!/usr/bin/env python3
import os
import subprocess
from urllib.parse import unquote_to_bytes, urlsplit


def fail(message: str) -> None:
    subprocess.run(
        ["notify-send", "LocalSend", message],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    raise SystemExit(1)


selected_uris = os.environ.get("NAUTILUS_SCRIPT_SELECTED_URIS", "")
if not selected_uris:
    fail("No files or folders were selected.")

paths: list[str] = []
for uri in selected_uris.splitlines():
    parsed = urlsplit(uri)
    if parsed.scheme != "file" or parsed.netloc not in ("", "localhost"):
        fail("Only local files and folders can be sent.")
    if parsed.query or parsed.fragment:
        fail("A selected file has an unsupported URI.")

    path = os.fsdecode(unquote_to_bytes(parsed.path))
    if not os.path.exists(path):
        fail(f"The selected path no longer exists: {path}")
    paths.append(path)

if not paths:
    fail("No local files or folders were selected.")

try:
    subprocess.Popen(
        ["localsend_app", *paths],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
except OSError as error:
    fail(f"Could not open LocalSend: {error}")
