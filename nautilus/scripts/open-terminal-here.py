#!/usr/bin/env python3
import os
import subprocess
from urllib.parse import unquote_to_bytes, urlsplit


def fail(message: str) -> None:
    subprocess.run(["notify-send", "Open Terminal Here", message], check=False)
    raise SystemExit(1)


selected = os.environ.get("NAUTILUS_SCRIPT_SELECTED_URIS", "").splitlines()
uri = selected[0] if selected else os.environ.get("NAUTILUS_SCRIPT_CURRENT_URI", "")
parsed = urlsplit(uri)

if parsed.scheme != "file" or parsed.netloc not in ("", "localhost"):
    fail("Only local folders can be opened in a terminal.")
if parsed.query or parsed.fragment:
    fail("The folder has an unsupported URI.")

path = os.fsdecode(unquote_to_bytes(parsed.path))

if not os.path.exists(path):
    fail("The selected path no longer exists.")
if not os.path.isdir(path):
    path = os.path.dirname(path)

try:
    subprocess.Popen(
        ["alacritty", "--working-directory", path],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
except OSError as error:
    fail(f"Could not open Alacritty: {error}")
