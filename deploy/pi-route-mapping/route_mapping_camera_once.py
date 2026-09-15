#!/usr/bin/env python3
"""Capture one real Pi-camera JPEG into volatile storage for QGC transfer.

This helper is invoked over SSH with sudo. A capture token makes the operation
idempotent: retrying the same token returns the already-captured temporary JPEG
instead of operating the camera twice. QGC calls ``ack`` only after it has
validated and committed the downloaded JPEG, at which point the Pi copy is
deleted.
"""

from __future__ import annotations

import argparse
import fcntl
import os
import pathlib
import pwd
import re
import subprocess
import sys
import time


RUNTIME_ROOT = pathlib.Path("/run/shreeon-route-mapping")
PHOTO_ROOT = RUNTIME_ROOT / "photos"
LOCK_FILE = RUNTIME_ROOT / "camera.lock"

CAPTURE_USER = "shreeon"
CAMERA_SERVICE = "wfb-camera.service"
CAMERA_COMMAND = "/usr/local/bin/rpicam-still"

MAX_FILE_AGE_SECONDS = 600
TOKEN_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,80}$")


def validate_token(token: str) -> str:
    if not TOKEN_PATTERN.fullmatch(token):
        raise ValueError("Invalid capture token")
    return token


def ensure_runtime_directories() -> pwd.struct_passwd:
    account = pwd.getpwnam(CAPTURE_USER)
    RUNTIME_ROOT.mkdir(parents=True, exist_ok=True)
    PHOTO_ROOT.mkdir(parents=True, exist_ok=True)
    os.chown(PHOTO_ROOT, account.pw_uid, account.pw_gid)
    os.chmod(PHOTO_ROOT, 0o700)
    return account


def remove_file(path: pathlib.Path) -> None:
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def cleanup_old_files() -> None:
    cutoff = time.time() - MAX_FILE_AGE_SECONDS
    for path in PHOTO_ROOT.iterdir():
        if not path.is_file():
            continue
        try:
            if path.stat().st_mtime < cutoff:
                path.unlink()
        except FileNotFoundError:
            pass


def is_valid_jpeg(path: pathlib.Path) -> bool:
    try:
        if path.stat().st_size < 4:
            return False
        with path.open("rb") as image:
            start = image.read(2)
            image.seek(-2, os.SEEK_END)
            end = image.read(2)
        return start == b"\xff\xd8" and end == b"\xff\xd9"
    except (OSError, ValueError):
        return False


def systemctl_is_active(service: str) -> bool:
    result = subprocess.run(
        ["systemctl", "is-active", "--quiet", service],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def run_systemctl(action: str, service: str) -> None:
    result = subprocess.run(
        ["systemctl", action, service],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        timeout=20,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"systemctl {action} {service} failed: {result.stderr.strip()}"
        )


def capture_photo(token: str) -> pathlib.Path:
    token = validate_token(token)
    account = ensure_runtime_directories()
    final_path = PHOTO_ROOT / f"{token}.jpg"
    temporary_path = PHOTO_ROOT / f"{token}.part"

    with LOCK_FILE.open("a+") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        cleanup_old_files()

        # A QGC retry with the same token must not operate the camera twice.
        if is_valid_jpeg(final_path):
            return final_path

        remove_file(final_path)
        remove_file(temporary_path)
        video_was_active = systemctl_is_active(CAMERA_SERVICE)

        try:
            if video_was_active:
                run_systemctl("stop", CAMERA_SERVICE)

            command = [
                "/usr/sbin/runuser",
                "-u",
                CAPTURE_USER,
                "--",
                "/usr/bin/env",
                f"XDG_RUNTIME_DIR=/run/user/{account.pw_uid}",
                CAMERA_COMMAND,
                "--timeout",
                "2000",
                "--nopreview",
                "--autofocus-mode",
                "auto",
                "--width",
                "4608",
                "--height",
                "2592",
                "--quality",
                "95",
                "--encoding",
                "jpg",
                "--output",
                str(temporary_path),
            ]
            result = subprocess.run(
                command,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
                timeout=35,
                check=False,
            )
            if result.returncode != 0:
                raise RuntimeError(f"rpicam-still failed: {result.stderr.strip()}")
            if not is_valid_jpeg(temporary_path):
                raise RuntimeError("rpicam-still did not produce a valid JPEG")

            os.replace(temporary_path, final_path)
            os.chown(final_path, account.pw_uid, account.pw_gid)
            os.chmod(final_path, 0o600)
            return final_path
        finally:
            remove_file(temporary_path)
            if video_was_active:
                try:
                    run_systemctl("start", CAMERA_SERVICE)
                except Exception as error:  # Preserve a valid capture on restart failure.
                    print(
                        f"Warning: could not restart {CAMERA_SERVICE}: {error}",
                        file=sys.stderr,
                    )


def acknowledge_photo(token: str) -> None:
    token = validate_token(token)
    ensure_runtime_directories()
    final_path = PHOTO_ROOT / f"{token}.jpg"
    temporary_path = PHOTO_ROOT / f"{token}.part"

    with LOCK_FILE.open("a+") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        remove_file(final_path)
        remove_file(temporary_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("operation", choices=("capture", "ack"))
    parser.add_argument("token")
    arguments = parser.parse_args()

    if os.geteuid() != 0:
        print("This helper must be executed through sudo", file=sys.stderr)
        return 2

    try:
        if arguments.operation == "capture":
            # QGC deliberately expects stdout to contain only this exact path.
            print(capture_photo(arguments.token))
        else:
            acknowledge_photo(arguments.token)
            print("OK")
        return 0
    except Exception as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
