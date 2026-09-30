#!/usr/bin/env python3
"""Wait for a JPEG and publish its embedded EXIF thumbnail as a sidecar."""

from __future__ import annotations

import argparse
import fcntl
import pathlib
import subprocess
import struct
import time


def _embedded_thumbnail(jpeg_path: pathlib.Path) -> bytes | None:
    data = jpeg_path.read_bytes()
    if not data.startswith(b"\xff\xd8"):
        return None

    position = 2
    while position + 4 <= len(data):
        if data[position] != 0xFF:
            return None
        marker = data[position + 1]
        position += 2
        if marker in (0xD9, 0xDA):
            break
        if marker == 0x00 or 0xD0 <= marker <= 0xD7:
            continue

        segment_length = struct.unpack_from(">H", data, position)[0]
        if segment_length < 2 or position + segment_length > len(data):
            return None
        segment = data[position + 2 : position + segment_length]
        position += segment_length
        if marker != 0xE1 or not segment.startswith(b"Exif\x00\x00"):
            continue

        tiff = segment[6:]
        if len(tiff) < 8:
            return None
        byte_order = tiff[:2]
        if byte_order == b"II":
            endian = "<"
        elif byte_order == b"MM":
            endian = ">"
        else:
            return None

        def u16(offset: int) -> int:
            return struct.unpack_from(endian + "H", tiff, offset)[0]

        def u32(offset: int) -> int:
            return struct.unpack_from(endian + "I", tiff, offset)[0]

        if u16(2) != 42:
            return None
        ifd0_offset = u32(4)
        if ifd0_offset + 2 > len(tiff):
            return None
        ifd0_count = u16(ifd0_offset)
        ifd1_pointer_offset = ifd0_offset + 2 + ifd0_count * 12
        if ifd1_pointer_offset + 4 > len(tiff):
            return None
        ifd1_offset = u32(ifd1_pointer_offset)
        if not ifd1_offset or ifd1_offset + 2 > len(tiff):
            return None

        thumbnail_offset = 0
        thumbnail_length = 0
        ifd1_count = u16(ifd1_offset)
        for entry_index in range(ifd1_count):
            entry_offset = ifd1_offset + 2 + entry_index * 12
            if entry_offset + 12 > len(tiff):
                return None
            tag = u16(entry_offset)
            value = u32(entry_offset + 8)
            if tag == 0x0201:
                thumbnail_offset = value
            elif tag == 0x0202:
                thumbnail_length = value

        thumbnail_end = thumbnail_offset + thumbnail_length
        if (
            thumbnail_offset <= 0
            or thumbnail_length <= 0
            or thumbnail_end > len(tiff)
        ):
            return None
        thumbnail = tiff[thumbnail_offset:thumbnail_end]
        if not thumbnail.startswith(b"\xff\xd8"):
            return None
        return thumbnail

    return None


def _publish_preview(
    source: pathlib.Path, output_path: pathlib.Path | None = None
) -> bool:
    preview = output_path or pathlib.Path(str(source) + ".preview.jpg")
    if preview.is_file() and preview.stat().st_size > 0:
        return True
    thumbnail = _embedded_thumbnail(source)
    temporary = pathlib.Path(str(preview) + ".part")
    if thumbnail:
        temporary.write_bytes(thumbnail)
        temporary.replace(preview)
        return True

    # rpicam-vid MJPEG frames normally have no embedded EXIF thumbnail. Use
    # the GStreamer packages already installed for the WFB camera pipeline to
    # generate a small transfer preview without delaying the next exposure.
    try:
        subprocess.run(
            [
                "/usr/bin/gst-launch-1.0",
                "-q",
                "filesrc",
                f"location={source}",
                "!",
                "jpegparse",
                "!",
                "jpegdec",
                "!",
                "videoscale",
                "!",
                "video/x-raw,width=640,height=360,pixel-aspect-ratio=1/1",
                "!",
                "jpegenc",
                "quality=70",
                "!",
                "filesink",
                f"location={temporary}",
            ],
            check=True,
            timeout=10,
        )
        if temporary.is_file() and temporary.stat().st_size > 0:
            temporary.replace(preview)
            return True
    except (OSError, subprocess.SubprocessError):
        pass
    if temporary.exists():
        temporary.unlink()
    return False


def _watch_directory(directory: pathlib.Path, wait_seconds: float) -> int:
    directory.mkdir(parents=True, exist_ok=True)
    lock_path = directory / ".preview-worker.lock"
    with lock_path.open("a+b") as lock_file:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            # One worker already covers every JPEG in this session.
            return 0

        deadline = time.monotonic() + max(0.0, wait_seconds)
        while True:
            for source in directory.glob("image_*.jpg"):
                if source.name.endswith(".preview.jpg") or source.name.endswith(".part.jpg"):
                    continue
                try:
                    _publish_preview(source)
                except OSError:
                    pass
            if time.monotonic() >= deadline:
                return 0
            time.sleep(0.25)


def _wait_for_file(
    source: pathlib.Path, output_path: pathlib.Path | None, wait_seconds: float
) -> int:
    deadline = time.monotonic() + max(0.0, wait_seconds)
    while True:
        try:
            if source.is_file() and source.stat().st_size > 0:
                return 0 if _publish_preview(source, output_path) else 1
        except OSError:
            pass
        if time.monotonic() >= deadline:
            return 2
        time.sleep(0.25)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("jpeg_path", nargs="?", type=pathlib.Path)
    parser.add_argument("--watch-directory", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--wait-seconds", type=float, default=600.0)
    arguments = parser.parse_args()
    if arguments.watch_directory is not None:
        return _watch_directory(arguments.watch_directory, arguments.wait_seconds)
    if arguments.jpeg_path is None:
        parser.error("jpeg_path or --watch-directory is required")
    return _wait_for_file(arguments.jpeg_path, arguments.output, arguments.wait_seconds)


if __name__ == "__main__":
    raise SystemExit(main())
