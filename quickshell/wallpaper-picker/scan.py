#!/usr/bin/env python3
"""Stream wallpaper entries and cached thumbnails to Quickshell."""

import hashlib
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

IMAGES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tif", ".tiff", ".avif"}
VIDEOS = {".mp4", ".mkv", ".webm", ".mov", ".avi"}


def emit(entry):
    print(json.dumps(entry), flush=True)


def small_thumbnail_path(path, cache):
    key = hashlib.sha256(
        (str(path) + str(path.stat().st_mtime_ns) + ":small-v1").encode()
    )
    return cache / (key.hexdigest() + ".png")


def thumbnail(path, target, video, source):
    if not target.is_file():
        temporary = target.with_suffix(".tmp.png")
        command = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"]
        if video and source is None:
            command += ["-ss", "1"]
        command += [
            "-i",
            str(source or path),
            "-vf",
            "scale=200:120:force_original_aspect_ratio=decrease",
            "-frames:v",
            "1",
            str(temporary),
        ]
        result = subprocess.run(
            command,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode != 0:
            temporary.unlink(missing_ok=True)
            return None
        temporary.replace(target)
    return str(target)


def video_preview(path, target):
    temporary = target.with_suffix(".tmp.png")
    result = subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-ss",
            "1",
            "-i",
            str(path),
            "-frames:v",
            "1",
            str(temporary),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        temporary.unlink(missing_ok=True)
        return None
    temporary.replace(target)
    return str(target)


def main(directory):
    cache = (
        Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
        / "wallpaper-picker"
    )
    pending = []
    previews = []
    try:
        entries = sorted(
            Path(directory).iterdir(), key=lambda path: path.name.casefold()
        )
    except OSError as error:
        emit({"error": str(error)})
        return

    for path in entries:
        if not path.is_file():
            continue
        path = path.resolve()
        suffix = path.suffix.lower()
        if suffix in IMAGES:
            cached = small_thumbnail_path(path, cache)
            ready = cached.is_file()
            emit(
                {
                    "path": str(path),
                    "thumbnail": str(cached) if ready else str(path),
                    "video": False,
                    "small": ready,
                    "preview": str(path),
                }
            )
            if not ready:
                pending.append((path, cached, False, None))
        elif suffix in VIDEOS:
            cached = small_thumbnail_path(path, cache)
            ready = cached.is_file()
            key = hashlib.sha256(
                (str(path) + ":full-resolution-v1").encode()
            ).hexdigest()
            old = cache / (key + ".png")
            old_ready = (
                old.is_file() and old.stat().st_mtime_ns >= path.stat().st_mtime_ns
            )
            emit(
                {
                    "path": str(path),
                    "thumbnail": str(cached)
                    if ready
                    else str(old)
                    if old_ready
                    else "",
                    "preview": str(old) if old_ready else str(cached) if ready else "",
                    "video": True,
                    "small": ready,
                }
            )
            if not ready:
                pending.append((path, cached, True, old if old_ready else None))
            if not old_ready:
                previews.append((path, old))

    if pending or previews:
        cache.mkdir(parents=True, exist_ok=True)
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = {
                pool.submit(thumbnail, path, target, video, source): (path, "thumbnail")
                for path, target, video, source in pending
            }
            futures.update(
                {
                    pool.submit(video_preview, path, target): (path, "preview")
                    for path, target in previews
                }
            )
            for future in as_completed(futures):
                result = future.result()
                if result:
                    path, role = futures[future]
                    update = {"path": str(path), role: result}
                    if role == "thumbnail":
                        update["small"] = True
                    emit(update)


if __name__ == "__main__":
    main(sys.argv[1])
