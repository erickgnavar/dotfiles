#!/usr/bin/env python3
"""Bounded FFmpeg stream-copy trimming; stdout is one JSON result."""

import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile


def run(command, timeout):
    process = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True
    )
    try:
        stdout, stderr = process.communicate(timeout=timeout)
        if process.returncode:
            raise ValueError(
                stderr.decode(errors="replace")[-2000:] or "Media command failed"
            )
        return stdout
    finally:
        # Also covers cancellation and timeout; reap before deleting temporary output.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        process.stdout.close()
        process.stderr.close()


def probe(file):
    data = json.loads(
        run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration:stream=codec_type",
                "-of",
                "json",
                str(file),
            ],
            15,
        )
    )
    duration = float(data["format"]["duration"])
    if not math.isfinite(duration) or duration <= 0:
        raise ValueError("Video has no usable duration")
    if not any(stream.get("codec_type") == "video" for stream in data["streams"]):
        raise ValueError("File contains no video")
    return duration


def trim(file, start, end, duration):
    if not all(math.isfinite(value) for value in (start, end)):
        raise ValueError("Times must be finite numbers")
    if not 0 <= start < end <= duration:
        raise ValueError("Choose 0 <= start < end <= duration")
    fd, name = tempfile.mkstemp(
        prefix=f"{file.stem}-trimmed-", suffix=".mp4", dir=file.parent
    )
    os.close(fd)
    output = Path(name)
    success = False
    try:
        run(
            [
                "ffmpeg",
                "-nostdin",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-ss",
                str(start),
                "-i",
                str(file),
                "-t",
                str(end - start),
                "-map",
                "0:v:0",
                "-map",
                "0:a?",
                "-c",
                "copy",
                "-avoid_negative_ts",
                "make_zero",
                "-movflags",
                "+faststart",
                str(output),
            ],
            300,
        )
        if not output.stat().st_size:
            raise ValueError("FFmpeg produced an empty file")
        success = True
        return str(output)
    finally:
        if not success:
            output.unlink(missing_ok=True)


def cancel(_signal, _frame):
    raise KeyboardInterrupt


def main():
    signal.signal(signal.SIGTERM, cancel)
    try:
        mode, name, *times = sys.argv[1:]
        file = Path(name).resolve(strict=True)
        duration = probe(file)
        if mode == "probe" and not times:
            result = {"duration": duration, "url": file.as_uri()}
        elif mode == "trim" and len(times) == 2:
            result = {"file": trim(file, float(times[0]), float(times[1]), duration)}
        else:
            raise ValueError("Expected probe FILE or trim FILE START END")
        print(json.dumps(result), flush=True)
        return 0
    except KeyboardInterrupt:
        return 130
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        subprocess.TimeoutExpired,
    ) as error:
        print(json.dumps({"error": str(error)}), flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
