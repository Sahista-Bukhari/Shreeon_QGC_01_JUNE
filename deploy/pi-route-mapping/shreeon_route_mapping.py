#!/usr/bin/env python3
"""Bridge PX4 MAVLink through WFB and save full-resolution mapping photos."""

from __future__ import annotations

import argparse
import dataclasses
import json
import logging
import os
import pathlib
import pwd
import queue
import selectors
import signal
import socket
import struct
import subprocess
import sys
import termios
import threading
import time
from collections import deque
from collections.abc import Callable
from datetime import datetime


LOGGER = logging.getLogger("shreeon-route-mapping")

MAVLINK_V1_MAGIC = 0xFE
MAVLINK_V2_MAGIC = 0xFD
MAVLINK_IFLAG_SIGNED = 0x01
MAVLINK_MSG_ID_COMMAND_LONG = 76
MAVLINK_MSG_ID_CAMERA_TRIGGER = 112
MAV_CMD_IMAGE_START_CAPTURE = 2000
CRC_EXTRA = {
    MAVLINK_MSG_ID_COMMAND_LONG: 152,
    MAVLINK_MSG_ID_CAMERA_TRIGGER: 174,
}


@dataclasses.dataclass(frozen=True)
class MavlinkMessage:
    message_id: int
    system_id: int
    component_id: int
    payload: bytes


@dataclasses.dataclass(frozen=True)
class CaptureRequest:
    source: str
    sequence: int | None = None
    gcs_sequence: int | None = None
    session_directory: pathlib.Path | None = None
    planned_path: pathlib.Path | None = None
    thumbnail_path: pathlib.Path | None = None
    trigger_monotonic: float = dataclasses.field(default_factory=time.monotonic)


class MjpegFrameSource:
    """Keep rpicam-vid running and retain frames around each trigger time."""

    def __init__(
        self,
        capture_user: str,
        camera_command: str,
        width: int,
        height: int,
        framerate: float,
        quality: int,
        buffer_count: int,
        startup_timeout_sec: float,
    ) -> None:
        self._capture_user = capture_user
        self._camera_command = camera_command
        self._width = width
        self._height = height
        self._framerate = framerate
        self._quality = quality
        self._buffer_count = buffer_count
        self._startup_timeout_sec = startup_timeout_sec
        self._condition = threading.Condition()
        self._frames: deque[tuple[float, bytes]] = deque(
            maxlen=max(4, min(32, int(max(1.0, framerate) * 3)))
        )
        self._process: subprocess.Popen[bytes] | None = None
        self._reader_thread: threading.Thread | None = None
        self._stderr_thread: threading.Thread | None = None

    @property
    def running(self) -> bool:
        process = self._process
        return process is not None and process.poll() is None

    def start(self) -> None:
        if self.running:
            return
        self.stop()
        with self._condition:
            self._frames.clear()

        capture_account = pwd.getpwnam(self._capture_user)
        command = [
            "/usr/bin/env",
            f"XDG_RUNTIME_DIR=/run/user/{capture_account.pw_uid}",
            self._camera_command,
            "--timeout",
            "0",
            "--nopreview",
            "--buffer-count",
            str(self._buffer_count),
            "--width",
            str(self._width),
            "--height",
            str(self._height),
            "--framerate",
            str(self._framerate),
            "--codec",
            "mjpeg",
            "--quality",
            str(self._quality),
            "--output",
            "-",
        ]
        if os.geteuid() != capture_account.pw_uid:
            command = [
                "/usr/sbin/runuser",
                "-u",
                self._capture_user,
                "--",
                *command,
            ]
        LOGGER.info(
            "Starting persistent mapping camera: %dx%d %.2f fps MJPEG",
            self._width,
            self._height,
            self._framerate,
        )
        self._process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
            start_new_session=True,
        )
        self._reader_thread = threading.Thread(
            target=self._read_frames,
            name="mapping-mjpeg-reader",
            daemon=True,
        )
        self._stderr_thread = threading.Thread(
            target=self._read_stderr,
            name="mapping-camera-log",
            daemon=True,
        )
        self._reader_thread.start()
        self._stderr_thread.start()
        # Do not acknowledge VIDEO_PAUSE until the camera is producing frames.
        try:
            self.frame_after(time.monotonic() - 1.0, self._startup_timeout_sec)
        except Exception:
            self.stop()
            raise

    def stop(self) -> None:
        process = self._process
        self._process = None
        if process is None:
            return
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=2)
        with self._condition:
            self._condition.notify_all()
        if process.stdout is not None:
            process.stdout.close()
        if process.stderr is not None:
            process.stderr.close()
        LOGGER.info("Persistent mapping camera stopped")

    def frame_after(self, trigger_monotonic: float, timeout_sec: float) -> tuple[bytes, float]:
        deadline = time.monotonic() + max(0.1, timeout_sec)
        with self._condition:
            while True:
                for frame_time, frame in self._frames:
                    if frame_time >= trigger_monotonic:
                        return frame, frame_time
                process = self._process
                if process is None or process.poll() is not None:
                    raise RuntimeError("rpicam-vid stopped before a frame was captured")
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError("Timed out waiting for an rpicam-vid frame")
                self._condition.wait(timeout=remaining)

    def _read_frames(self) -> None:
        process = self._process
        if process is None or process.stdout is None:
            return
        buffer = bytearray()
        try:
            while process.poll() is None:
                chunk = process.stdout.read(65536)
                if not chunk:
                    break
                buffer.extend(chunk)
                while True:
                    start = buffer.find(b"\xff\xd8")
                    if start < 0:
                        if len(buffer) > 1:
                            del buffer[:-1]
                        break
                    if start:
                        del buffer[:start]
                    end = buffer.find(b"\xff\xd9", 2)
                    if end < 0:
                        break
                    frame = bytes(buffer[: end + 2])
                    del buffer[: end + 2]
                    frame_time = time.monotonic()
                    with self._condition:
                        self._frames.append((frame_time, frame))
                        self._condition.notify_all()
        except (OSError, ValueError):
            LOGGER.exception("Persistent mapping camera output failed")
        finally:
            with self._condition:
                self._condition.notify_all()

    def _read_stderr(self) -> None:
        process = self._process
        if process is None or process.stderr is None:
            return
        try:
            for raw_line in iter(process.stderr.readline, b""):
                line = raw_line.decode("utf-8", errors="replace").strip()
                if line:
                    LOGGER.info("rpicam-vid: %s", line)
        except (OSError, ValueError):
            return


def x25_crc(data: bytes, crc: int = 0xFFFF) -> int:
    for value in data:
        temporary = value ^ (crc & 0xFF)
        temporary ^= (temporary << 4) & 0xFF
        crc = (
            (crc >> 8)
            ^ (temporary << 8)
            ^ (temporary << 3)
            ^ (temporary >> 4)
        ) & 0xFFFF
    return crc


class MavlinkParser:
    """Incremental parser for the two messages used by the capture service."""

    def __init__(self) -> None:
        self._buffer = bytearray()

    def feed(self, data: bytes) -> list[MavlinkMessage]:
        self._buffer.extend(data)
        messages: list[MavlinkMessage] = []

        while self._buffer:
            magic_index = next(
                (
                    index
                    for index, value in enumerate(self._buffer)
                    if value in (MAVLINK_V1_MAGIC, MAVLINK_V2_MAGIC)
                ),
                None,
            )
            if magic_index is None:
                self._buffer.clear()
                break
            if magic_index:
                del self._buffer[:magic_index]

            magic = self._buffer[0]
            minimum_header = 6 if magic == MAVLINK_V1_MAGIC else 10
            if len(self._buffer) < minimum_header:
                break

            payload_length = self._buffer[1]
            if magic == MAVLINK_V1_MAGIC:
                header_length = 6
                signature_length = 0
                message_id = self._buffer[5]
                system_id = self._buffer[3]
                component_id = self._buffer[4]
            else:
                header_length = 10
                signature_length = (
                    13 if self._buffer[2] & MAVLINK_IFLAG_SIGNED else 0
                )
                message_id = (
                    self._buffer[7]
                    | (self._buffer[8] << 8)
                    | (self._buffer[9] << 16)
                )
                system_id = self._buffer[5]
                component_id = self._buffer[6]

            frame_length = header_length + payload_length + 2 + signature_length
            if len(self._buffer) < frame_length:
                break

            frame = bytes(self._buffer[:frame_length])
            del self._buffer[:frame_length]

            checksum_offset = header_length + payload_length
            expected_crc = struct.unpack_from("<H", frame, checksum_offset)[0]
            crc_data = frame[1:checksum_offset]
            calculated_crc = x25_crc(crc_data)
            crc_extra = CRC_EXTRA.get(message_id)
            if crc_extra is not None:
                calculated_crc = x25_crc(bytes((crc_extra,)), calculated_crc)

            if calculated_crc != expected_crc:
                continue

            payload = frame[header_length:checksum_offset]
            messages.append(
                MavlinkMessage(message_id, system_id, component_id, payload)
            )

        return messages


class CaptureWorker(threading.Thread):
    def __init__(
        self,
        photo_root: pathlib.Path,
        capture_user: str,
        camera_service: str,
        camera_command: str,
        thumbnail_command: str,
        mapping_width: int,
        mapping_height: int,
        mapping_framerate: float,
        mapping_quality: int,
        mapping_buffer_count: int,
        frame_wait_sec: float,
        video_release_delay_sec: float,
    ) -> None:
        super().__init__(name="photo-capture", daemon=True)
        # A mapping mission can easily contain hundreds of photographs. The
        # queue is unbounded, while the persistent video source keeps normal
        # trigger handling faster than the 6 m / 9 m flight interval.
        self._requests: queue.Queue[CaptureRequest | None] = queue.Queue()
        self._thumbnail_requests: queue.Queue[
            tuple[pathlib.Path, pathlib.Path] | None
        ] = queue.Queue()
        self._thumbnail_thread = threading.Thread(
            target=self._thumbnail_loop,
            name="mapping-thumbnail",
            daemon=True,
        )
        self._thumbnail_processing_allowed = threading.Event()
        self._thumbnail_processing_allowed.set()
        self._photo_root = photo_root
        self._capture_user = capture_user
        self._camera_service = camera_service
        self._thumbnail_command = thumbnail_command
        self._frame_wait_sec = frame_wait_sec
        self._video_release_delay_sec = video_release_delay_sec
        self._frame_source = MjpegFrameSource(
            capture_user,
            camera_command,
            mapping_width,
            mapping_height,
            mapping_framerate,
            mapping_quality,
            mapping_buffer_count,
            max(10.0, frame_wait_sec),
        )
        self._session_video_paused = False
        self._counter = 0
        self._session_directory: pathlib.Path | None = None
        self._gcs_requests: set[tuple[str, int]] = set()
        self._gcs_planned_paths: dict[tuple[str, int], pathlib.Path] = {}
        self._gcs_thumbnail_paths: dict[tuple[str, int], pathlib.Path] = {}
        self._request_lock = threading.Lock()
        self._capture_active = False
        photo_root.mkdir(parents=True, exist_ok=True)

    def set_session_video_paused(self, paused: bool) -> None:
        self._session_video_paused = paused

    def start_mapping_video(self) -> None:
        # JPEG decoding competes with the camera for contiguous buffers on the
        # 512 MB aircraft Pi. Keep thumbnails queued until the mapping stream
        # has released the sensor; QGC can fetch the authoritative JPEG while
        # a thumbnail is pending.
        self._thumbnail_processing_allowed.clear()
        self._frame_source.start()

    def stop_mapping_video(self) -> None:
        self._frame_source.stop()

    def resume_thumbnail_processing(self) -> None:
        self._thumbnail_processing_allowed.set()

    @property
    def mapping_video_running(self) -> bool:
        return self._frame_source.running

    @property
    def session_directory(self) -> pathlib.Path | None:
        with self._request_lock:
            return self._session_directory

    def begin_session(self) -> pathlib.Path:
        with self._request_lock:
            if self._session_directory is None:
                self._session_directory = self._create_session_directory(
                    self._photo_root
                )
            return self._session_directory

    def start_new_session(self) -> pathlib.Path:
        with self._request_lock:
            self._session_directory = self._create_session_directory(
                self._photo_root
            )
            return self._session_directory

    def close_session(self) -> None:
        with self._request_lock:
            if self._session_directory is not None:
                LOGGER.info("Photo session closed: %s", self._session_directory)
            self._session_directory = None

    def cancel_pending(self) -> int:
        """Discard exposures which have not started; never cancel the active write."""
        cancelled: list[CaptureRequest] = []
        with self._requests.mutex:
            retained = []
            for request in self._requests.queue:
                if isinstance(request, CaptureRequest):
                    cancelled.append(request)
                else:
                    retained.append(request)
            self._requests.queue.clear()
            self._requests.queue.extend(retained)
            self._requests.not_full.notify_all()

        with self._request_lock:
            for request in cancelled:
                if request.gcs_sequence is None or request.session_directory is None:
                    continue
                key = (str(request.session_directory), request.gcs_sequence)
                self._gcs_requests.discard(key)
                self._gcs_planned_paths.pop(key, None)
                self._gcs_thumbnail_paths.pop(key, None)
        if cancelled:
            LOGGER.info("Cancelled %d pending camera captures", len(cancelled))
        return len(cancelled)

    def wait_until_idle(self, timeout_sec: float) -> bool:
        deadline = time.monotonic() + max(0.0, timeout_sec)
        while time.monotonic() < deadline:
            with self._request_lock:
                if not self._capture_active:
                    return True
            time.sleep(0.05)
        with self._request_lock:
            return not self._capture_active

    def wait_until_drained(self, timeout_sec: float) -> bool:
        """Wait for accepted captures to finish without waiting for thumbnails."""
        deadline = time.monotonic() + max(0.0, timeout_sec)
        while time.monotonic() < deadline:
            with self._requests.mutex:
                capture_queue_empty = not any(
                    isinstance(request, CaptureRequest)
                    for request in self._requests.queue
                )
            with self._request_lock:
                capture_active = self._capture_active
            if capture_queue_empty and not capture_active:
                return True
            time.sleep(0.05)
        return False

    def _plan_gcs_capture_path(
        self, session_directory: pathlib.Path, gcs_sequence: int
    ) -> pathlib.Path:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
        return session_directory / (
            f"image_{gcs_sequence:04d}_gcs_{gcs_sequence:04d}_{timestamp}.jpg"
        )

    def _plan_gcs_thumbnail_path(
        self, session_directory: pathlib.Path, gcs_sequence: int
    ) -> pathlib.Path:
        return session_directory / f"image_{gcs_sequence:04d}_thumb.jpg"

    def request(
        self, request: CaptureRequest
    ) -> tuple[bool, pathlib.Path | None, pathlib.Path | None]:
        if request.session_directory is None:
            request = dataclasses.replace(
                request, session_directory=self.begin_session()
            )

        planned_path: pathlib.Path | None = None
        request_key: tuple[str, int] | None = None
        if request.gcs_sequence is not None:
            request_key = (str(request.session_directory), request.gcs_sequence)
            with self._request_lock:
                if request_key in self._gcs_requests:
                    LOGGER.info(
                        "Ignoring duplicate GCS capture session=%s sequence=%d",
                        request.session_directory,
                        request.gcs_sequence,
                    )
                    return (
                        True,
                        self._gcs_planned_paths[request_key],
                        self._gcs_thumbnail_paths[request_key],
                    )
                planned_path = self._plan_gcs_capture_path(
                    request.session_directory, request.gcs_sequence
                )
                thumbnail_path = self._plan_gcs_thumbnail_path(
                    request.session_directory, request.gcs_sequence
                )
                self._gcs_requests.add(request_key)
                self._gcs_planned_paths[request_key] = planned_path
                self._gcs_thumbnail_paths[request_key] = thumbnail_path
            request = dataclasses.replace(
                request,
                planned_path=planned_path,
                thumbnail_path=thumbnail_path,
            )

        try:
            self._requests.put_nowait(request)
            LOGGER.info(
                "Queued photo from %s (sequence=%s gcs_sequence=%s path=%s)",
                request.source,
                request.sequence,
                request.gcs_sequence,
                planned_path,
            )
            return True, planned_path, request.thumbnail_path
        except queue.Full:
            if request_key is not None:
                with self._request_lock:
                    self._gcs_requests.discard(request_key)
                    self._gcs_planned_paths.pop(request_key, None)
                    self._gcs_thumbnail_paths.pop(request_key, None)
            LOGGER.error("Photo queue is full; dropping trigger from %s", request.source)
            return False, None, None

    def stop(self) -> None:
        self._thumbnail_processing_allowed.set()
        try:
            self._requests.put_nowait(None)
        except queue.Full:
            LOGGER.warning("Photo queue is busy; stopping after queued captures")

    def run(self) -> None:
        self._thumbnail_thread.start()
        while True:
            request = self._requests.get()
            if request is None:
                self._thumbnail_requests.put(None)
                self._thumbnail_thread.join(timeout=15)
                return
            with self._request_lock:
                self._capture_active = True
            try:
                self._capture(request)
            except Exception:
                if request.gcs_sequence is not None:
                    request_key = (
                        str(request.session_directory),
                        request.gcs_sequence,
                    )
                    # If the JPEG was atomically renamed before a later
                    # metadata error, the capture itself succeeded. Preserve
                    # the idempotency key so an ACK retry cannot create a
                    # second image for the same QGC trigger.
                    jpeg_saved = False
                    if request.planned_path is not None:
                        try:
                            jpeg_saved = (
                                request.planned_path.is_file()
                                and request.planned_path.stat().st_size > 0
                            )
                        except OSError:
                            jpeg_saved = False
                    if not jpeg_saved:
                        with self._request_lock:
                            self._gcs_requests.discard(request_key)
                            self._gcs_planned_paths.pop(request_key, None)
                            self._gcs_thumbnail_paths.pop(request_key, None)
                LOGGER.exception("Full-resolution capture failed")
            finally:
                with self._request_lock:
                    self._capture_active = False

    def _thumbnail_loop(self) -> None:
        while True:
            thumbnail_request = self._thumbnail_requests.get()
            if thumbnail_request is None:
                return
            filename, thumbnail_path = thumbnail_request
            self._thumbnail_processing_allowed.wait()
            thumbnail_command = [
                self._thumbnail_command,
                str(filename),
                "--output",
                str(thumbnail_path),
                "--wait-seconds",
                "0",
            ]
            try:
                subprocess.run(thumbnail_command, check=True, timeout=20)
                LOGGER.info(
                    "Saved thumbnail %s (%d bytes)",
                    thumbnail_path,
                    thumbnail_path.stat().st_size,
                )
            except (OSError, subprocess.SubprocessError):
                LOGGER.exception("Could not generate %s", thumbnail_path)

    def _create_session_directory(self, photo_root: pathlib.Path) -> pathlib.Path:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        session_directory = photo_root / f"mission_{timestamp}"
        collision_index = 1
        while session_directory.exists():
            session_directory = photo_root / (
                f"mission_{timestamp}_{collision_index:02d}"
            )
            collision_index += 1
        session_directory.mkdir(parents=True, exist_ok=True)
        account = pwd.getpwnam(self._capture_user)
        os.chown(session_directory, account.pw_uid, account.pw_gid)
        LOGGER.info("Photo session: %s", session_directory)
        return session_directory

    def _capture(self, request: CaptureRequest) -> None:
        self._counter += 1
        session_directory = request.session_directory
        if session_directory is None:
            raise RuntimeError("Capture request has no photo session")
        if request.planned_path is not None:
            filename = request.planned_path
            name_parts = filename.stem.split("_")
            timestamp = (
                "_".join(name_parts[4:])
                if len(name_parts) > 4
                else datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
            )
        elif request.gcs_sequence is not None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
            trigger_sequence = f"gcs_{request.gcs_sequence:04d}"
            filename = session_directory / (
                f"image_{request.gcs_sequence:04d}_{trigger_sequence}_{timestamp}.jpg"
            )
        else:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
            trigger_sequence = (
                f"px4_{request.sequence:06d}"
                if request.sequence is not None
                else f"local_{self._counter:06d}"
            )
            filename = session_directory / (
                f"image_{self._counter:06d}_{trigger_sequence}_{timestamp}.jpg"
            )
        temporary_filename = filename.with_suffix(".part.jpg")
        capture_started = time.monotonic()

        manage_video_per_shot = not self._session_video_paused
        video_was_active = False
        if manage_video_per_shot:
            video_was_active = (
                subprocess.run(
                    ["systemctl", "is-active", "--quiet", self._camera_service],
                    check=False,
                ).returncode
                == 0
            )

        try:
            if manage_video_per_shot and video_was_active:
                subprocess.run(
                    ["systemctl", "stop", self._camera_service], check=True
                )
                time.sleep(self._video_release_delay_sec)
            if manage_video_per_shot:
                self._thumbnail_processing_allowed.clear()
                self._frame_source.start()

            frame, frame_time = self._frame_source.frame_after(
                request.trigger_monotonic,
                self._frame_wait_sec,
            )
            if not frame.startswith(b"\xff\xd8") or not frame.endswith(b"\xff\xd9"):
                raise RuntimeError("rpicam-vid returned an invalid MJPEG frame")
            temporary_filename.write_bytes(frame)
            temporary_filename.replace(filename)
            capture_elapsed = time.monotonic() - capture_started
            trigger_to_frame = frame_time - request.trigger_monotonic
            LOGGER.info(
                "Saved rpicam-vid frame %s (%d bytes) in %.3f s "
                "(trigger-to-frame=%.3f s gcs_sequence=%s)",
                filename,
                filename.stat().st_size,
                capture_elapsed,
                trigger_to_frame,
                request.gcs_sequence,
            )
            if trigger_to_frame > 1.0:
                LOGGER.warning(
                    "Late mapping frame gcs_sequence=%s arrived %.3f s after trigger",
                    request.gcs_sequence,
                    trigger_to_frame,
                )
            if request.thumbnail_path is not None:
                self._thumbnail_requests.put((filename, request.thumbnail_path))
            sidecar = filename.with_suffix(".json")
            sidecar.write_text(
                json.dumps(
                    {
                        "source": request.source,
                        "session_directory": str(session_directory),
                        "gcs_sequence": request.gcs_sequence,
                        "px4_sequence": request.sequence,
                        "filename": filename.name,
                        "captured_at": timestamp,
                        "trigger_to_frame_seconds": round(trigger_to_frame, 6),
                        "capture_backend": "persistent-rpicam-vid-mjpeg",
                    },
                    indent=2,
                ),
                encoding="utf-8",
            )
        finally:
            if temporary_filename.exists():
                temporary_filename.unlink()
            if manage_video_per_shot:
                self._frame_source.stop()
                if video_was_active:
                    subprocess.run(
                        ["systemctl", "start", self._camera_service], check=False
                    )
                self._thumbnail_processing_allowed.set()


def open_serial(device: str, baud: int) -> int:
    speed = getattr(termios, f"B{baud}", None)
    if speed is None:
        raise ValueError(f"Unsupported UART baud: {baud}")

    descriptor = os.open(
        device,
        os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK,
    )
    attributes = termios.tcgetattr(descriptor)
    attributes[0] = 0
    attributes[1] = 0
    attributes[2] = termios.CS8 | termios.CREAD | termios.CLOCAL
    attributes[3] = 0
    attributes[4] = speed
    attributes[5] = speed
    attributes[6][termios.VMIN] = 0
    attributes[6][termios.VTIME] = 0
    termios.tcsetattr(descriptor, termios.TCSANOW, attributes)
    termios.tcflush(descriptor, termios.TCIOFLUSH)
    return descriptor


class RouteMappingService:
    def __init__(self, arguments: argparse.Namespace) -> None:
        self._arguments = arguments
        self._selector = selectors.DefaultSelector()
        self._serial_descriptor: int | None = None
        self._serial_parser = MavlinkParser()
        self._wfb_parser = MavlinkParser()
        self._stop_requested = False
        self._last_serial_retry = 0.0
        self._seen_camera_triggers: dict[tuple[int, int, int], float] = {}
        self._suppress_next_camera_trigger_until = 0.0
        self._ignore_uart_camera_trigger = os.environ.get("QGC_LED", "0") == "1"
        # VIDEO_PAUSE starts a QGC-led Route Mapping session. During that
        # session the service captures only explicit, sequenced CAPTURE
        # commands from QGC. This prevents the same MAVLink CAMERA_TRIGGER from
        # also being captured independently on the Pi UART path.
        self._gcs_controls_captures = False
        self._gcs_session_token: str | None = None
        self._session_lease_deadline = 0.0

        self._wfb_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._wfb_socket.bind(("127.0.0.1", 0))
        self._wfb_socket.connect((arguments.wfb_host, arguments.wfb_port))
        self._wfb_socket.setblocking(False)
        self._selector.register(self._wfb_socket, selectors.EVENT_READ, self._read_wfb)

        self._manual_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self._manual_socket.bind((arguments.manual_host, arguments.manual_port))
        self._manual_socket.setblocking(False)
        self._selector.register(
            self._manual_socket, selectors.EVENT_READ, self._read_manual
        )

        self._capture_worker = CaptureWorker(
            pathlib.Path(arguments.photo_root),
            arguments.capture_user,
            arguments.camera_service,
            arguments.camera_command,
            arguments.thumbnail_command,
            arguments.mapping_width,
            arguments.mapping_height,
            arguments.mapping_framerate,
            arguments.mapping_quality,
            arguments.mapping_buffer_count,
            arguments.frame_wait_sec,
            arguments.video_release_delay_sec,
        )

    def _camera_service_active(self) -> bool:
        return (
            subprocess.run(
                ["systemctl", "is-active", "--quiet", self._arguments.camera_service],
                check=False,
            ).returncode
            == 0
        )

    def _camera_service_streaming(self) -> bool:
        """Confirm systemd plus both processes which produce the RTP stream."""
        if not self._camera_service_active():
            return False
        main_pid_result = subprocess.run(
            [
                "systemctl",
                "show",
                "--property=MainPID",
                "--value",
                self._arguments.camera_service,
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        try:
            main_pid = int(main_pid_result.stdout.strip())
        except ValueError:
            return False
        if main_pid <= 0:
            return False

        children_result = subprocess.run(
            ["pgrep", "-P", str(main_pid), "-a"],
            check=False,
            capture_output=True,
            text=True,
        )
        child_commands = children_result.stdout
        return "rpicam-vid" in child_commands and "gst-launch-1.0" in child_commands

    def _start_live_video_verified(self, timeout_sec: float = 10.0) -> bool:
        action = "restart" if self._camera_service_active() else "start"
        subprocess.run(
            ["systemctl", action, self._arguments.camera_service], check=False
        )
        deadline = time.monotonic() + max(1.0, timeout_sec)
        healthy_since: float | None = None
        while time.monotonic() < deadline:
            if self._camera_service_streaming():
                if healthy_since is None:
                    healthy_since = time.monotonic()
                elif time.monotonic() - healthy_since >= 1.0:
                    return True
            else:
                healthy_since = None
            time.sleep(0.25)
        return self._camera_service_streaming()

    def _refresh_session_lease(self, session_token: str | None) -> bool:
        if not self._gcs_controls_captures:
            return False
        if (
            self._gcs_session_token is not None
            and session_token != self._gcs_session_token
        ):
            return False
        if self._gcs_session_token is not None:
            self._session_lease_deadline = (
                time.monotonic() + self._arguments.session_lease_sec
            )
        return True

    def _camera_state(self) -> str:
        if self._gcs_controls_captures:
            if self._capture_worker.mapping_video_running:
                return "MAPPING"
            return "ERROR"
        return "LIVE" if self._camera_service_streaming() else "ERROR"

    def _status_response(self) -> bytes:
        session_directory = self._capture_worker.session_directory
        session_text = str(session_directory) if session_directory is not None else "NONE"
        token_text = self._gcs_session_token or "NONE"
        wfb_state = "active" if self._camera_service_streaming() else "inactive"
        mapping_state = (
            "active" if self._capture_worker.mapping_video_running else "stopped"
        )
        return (
            f"STATE {self._camera_state()} session={session_text} "
            f"token={token_text} wfb={wfb_state} mapping={mapping_state}\n"
        ).encode()

    def pause_live_video(self, session_token: str | None = None) -> pathlib.Path:
        # VIDEO_PAUSE can be retried when its UDP acknowledgement is lost.
        # Reuse the active QGC session instead of creating another directory or
        # touching the camera pipeline a second time.
        if self._gcs_controls_captures:
            if (
                self._gcs_session_token is not None
                and session_token != self._gcs_session_token
            ):
                raise RuntimeError("another QGC mapping session owns the camera")
            session_directory = self._capture_worker.session_directory
            if (
                session_directory is not None
                and self._capture_worker.mapping_video_running
            ):
                self._refresh_session_lease(session_token)
                LOGGER.info(
                    "Mapping camera already paused for QGC session: %s",
                    session_directory,
                )
                return session_directory

        # VIDEO_PAUSE is the arm/start boundary for a mapping flight. Creating
        # the folder here (rather than in the daemon constructor) keeps its
        # timestamp and lifetime aligned with the actual mission.
        session_directory = self._capture_worker.start_new_session()
        self._gcs_controls_captures = True
        self._gcs_session_token = session_token
        self._session_lease_deadline = 0.0
        try:
            if self._camera_service_active():
                subprocess.run(
                    ["systemctl", "stop", self._arguments.camera_service], check=True
                )
                time.sleep(self._arguments.video_release_delay_sec)
            self._capture_worker.start_mapping_video()
            self._capture_worker.set_session_video_paused(True)
        except Exception:
            self._gcs_controls_captures = False
            self._gcs_session_token = None
            self._session_lease_deadline = 0.0
            self._capture_worker.stop_mapping_video()
            self._start_live_video_verified()
            self._capture_worker.resume_thumbnail_processing()
            self._capture_worker.close_session()
            raise
        self._refresh_session_lease(session_token)
        LOGGER.info(
            "WFB video paused; persistent rpicam-vid mapping session ready: %s",
            session_directory,
        )
        return session_directory

    def resume_live_video(self, session_token: str | None = None) -> bool:
        # QGC discovers an active vehicle during application startup. Older
        # builds sent VIDEO_RESUME from that reset path even though no mapping
        # session existed. Treat the command as a strict no-op so startup can
        # never cancel a standalone capture or churn the camera service.
        if not self._gcs_controls_captures:
            # Tokenized clients are explicitly asking for the safe LIVE state.
            # Legacy unsolicited resumes remain no-ops for compatibility.
            if session_token is None:
                LOGGER.info("Ignoring VIDEO_RESUME: no QGC mapping session is active")
                return self._camera_service_streaming()
            if self._camera_service_streaming():
                return True
            return self._start_live_video_verified()

        if (
            self._gcs_session_token is not None
            and session_token != self._gcs_session_token
        ):
            LOGGER.warning("Rejecting VIDEO_RESUME for a non-owner session token")
            return False

        # CAPTURE acknowledgements mean the Pi accepted those exposures. Give
        # that bounded queue time to finish before reclaiming the sensor, but
        # never let a broken capture block live-video recovery indefinitely.
        if not self._capture_worker.wait_until_drained(10.0):
            cancelled = self._capture_worker.cancel_pending()
            LOGGER.warning(
                "Mapping capture queue did not drain before video resume; "
                "cancelled %d pending exposure(s)",
                cancelled,
            )
            if not self._capture_worker.wait_until_idle(5.0):
                LOGGER.warning("Active camera exposure did not finish before video resume")
        self._capture_worker.stop_mapping_video()
        self._capture_worker.set_session_video_paused(False)
        self._capture_worker.resume_thumbnail_processing()
        if not self._start_live_video_verified():
            LOGGER.error("Could not verify that %s restarted", self._arguments.camera_service)
            # Retain ownership/session state so VIDEO_RESUME and the watchdog
            # can retry instead of losing the only recovery handle.
            return False
        self._gcs_controls_captures = False
        self._gcs_session_token = None
        self._session_lease_deadline = 0.0
        self._capture_worker.close_session()
        LOGGER.info("Live video resumed after mapping still session")
        return True

    def _check_session_lease(self) -> None:
        if (
            not self._gcs_controls_captures
            or self._gcs_session_token is None
            or self._session_lease_deadline <= 0.0
            or time.monotonic() < self._session_lease_deadline
        ):
            return
        LOGGER.warning(
            "QGC mapping-session lease expired; restoring live video automatically"
        )
        if not self.resume_live_video(self._gcs_session_token):
            # Retry recovery without waiting for another command from a QGC
            # which may have crashed or disconnected.
            self._session_lease_deadline = time.monotonic() + 5.0

    def request_stop(self, _signum: int, _frame: object) -> None:
        self._stop_requested = True

    def request_manual_capture(self, _signum: int, _frame: object) -> None:
        self._capture_worker.request(CaptureRequest("signal"))

    def run(self) -> int:
        # The daemon keeps session ownership only in memory. If it was killed
        # during a mapping session, reconcile the real camera to the safe LIVE
        # state before accepting any new commands.
        if not self._camera_service_streaming() and not self._start_live_video_verified():
            LOGGER.error(
                "Route Mapping daemon started but %s could not be restored",
                self._arguments.camera_service,
            )
        self._capture_worker.start()
        self._try_open_serial()
        LOGGER.info(
            "Manual trigger socket: udp://%s:%d",
            self._arguments.manual_host,
            self._arguments.manual_port,
        )

        while not self._stop_requested:
            if self._serial_descriptor is None:
                self._try_open_serial()
            for key, _events in self._selector.select(timeout=1.0):
                callback: Callable[[], None] = key.data
                try:
                    callback()
                except Exception:
                    LOGGER.exception("I/O callback failed")
            self._discard_old_trigger_ids()
            self._check_session_lease()

        self._capture_worker.cancel_pending()
        self._capture_worker.stop()
        self._capture_worker.join(timeout=35)
        self._capture_worker.stop_mapping_video()
        if not self._start_live_video_verified():
            LOGGER.error(
                "Could not verify %s during daemon shutdown",
                self._arguments.camera_service,
            )
        self._close_serial()
        self._selector.close()
        self._manual_socket.close()
        self._wfb_socket.close()
        return 0

    def _try_open_serial(self) -> None:
        now = time.monotonic()
        if now - self._last_serial_retry < 5:
            return
        self._last_serial_retry = now
        try:
            descriptor = open_serial(
                self._arguments.serial_device, self._arguments.serial_baud
            )
            self._serial_descriptor = descriptor
            self._selector.register(descriptor, selectors.EVENT_READ, self._read_serial)
            LOGGER.info(
                "Opened %s at %d baud",
                self._arguments.serial_device,
                self._arguments.serial_baud,
            )
        except (OSError, ValueError) as error:
            LOGGER.warning("UART unavailable: %s", error)

    def _close_serial(self) -> None:
        if self._serial_descriptor is None:
            return
        try:
            self._selector.unregister(self._serial_descriptor)
        except Exception:
            pass
        os.close(self._serial_descriptor)
        self._serial_descriptor = None

    def _read_serial(self) -> None:
        if self._serial_descriptor is None:
            return
        try:
            data = os.read(self._serial_descriptor, 65535)
        except BlockingIOError:
            return
        except OSError as error:
            LOGGER.warning("UART read failed: %s", error)
            self._close_serial()
            return
        if not data:
            return
        try:
            self._wfb_socket.send(data)
        except OSError as error:
            LOGGER.warning("WFB MAVLink send failed: %s", error)
        self._handle_messages(self._serial_parser.feed(data), from_flight_controller=True)

    def _read_wfb(self) -> None:
        try:
            data = self._wfb_socket.recv(65535)
        except BlockingIOError:
            return
        if not data:
            return
        if self._serial_descriptor is not None:
            try:
                os.write(self._serial_descriptor, data)
            except OSError as error:
                LOGGER.warning("UART write failed: %s", error)
                self._close_serial()
        self._handle_messages(self._wfb_parser.feed(data), from_flight_controller=False)

    def _read_manual(self) -> None:
        data, address = self._manual_socket.recvfrom(1024)
        text = data.decode("utf-8", errors="ignore").strip()
        parts = text.split()
        fields = {
            key.lower(): value
            for part in parts[1:]
            if "=" in part
            for key, value in [part.split("=", 1)]
        }
        session_token = fields.get("session")
        if not parts:
            response = b"ERROR empty command\n"
        elif parts[0].upper() == "CAPTURE":
            gcs_sequence = None
            if len(parts) >= 2:
                try:
                    # Accept the final field so one rollout remains compatible
                    # with the previous CAPTURE <token> <sequence> client.
                    gcs_sequence = int(parts[-1])
                except ValueError:
                    self._manual_socket.sendto(b"ERROR invalid sequence\n", address)
                    return
            if gcs_sequence is not None:
                session_directory = self._capture_worker.session_directory
                if session_directory is None:
                    self._manual_socket.sendto(
                        b"ERROR no active session; send VIDEO_PAUSE first\n",
                        address,
                    )
                    return
                queued, planned_path, thumbnail_path = self._capture_worker.request(
                    CaptureRequest(
                        "gcs-udp",
                        gcs_sequence=gcs_sequence,
                        session_directory=session_directory,
                    )
                )
            else:
                queued, planned_path, thumbnail_path = self._capture_worker.request(
                    CaptureRequest("manual-udp")
                )
            if queued:
                if gcs_sequence is not None:
                    if planned_path is not None:
                        response_text = (
                            f"QUEUED seq={gcs_sequence} path={planned_path}"
                        )
                        if thumbnail_path is not None:
                            response_text += f" thumb={thumbnail_path}"
                        response = (response_text + "\n").encode()
                    else:
                        LOGGER.warning(
                            "GCS capture queued without planned path (sequence=%d)",
                            gcs_sequence,
                        )
                        response = f"QUEUED seq={gcs_sequence}\n".encode()
                else:
                    response = b"QUEUED\n"
            else:
                response = b"BUSY\n"
        elif parts[0].upper() == "STATUS":
            if session_token is None:
                # Preserve the legacy wire format so the Pi package can be
                # deployed before every GCS has been upgraded.
                session_directory = self._capture_worker.session_directory
                response = (
                    f"SESSION {session_directory}\n".encode()
                    if session_directory is not None
                    else b"SESSION NONE\n"
                )
            else:
                response = self._status_response()
        elif parts[0].upper() == "VIDEO_PAUSE":
            try:
                session_directory = self.pause_live_video(session_token)
                if session_token is None:
                    response = f"OK session={session_directory}\n".encode()
                else:
                    response = (
                        f"OK state=MAPPING session={session_directory} "
                        f"token={self._gcs_session_token or 'NONE'}\n"
                    ).encode()
            except Exception as error:
                LOGGER.exception("VIDEO_PAUSE failed")
                response = f"ERROR {error}\n".encode()
        elif parts[0].upper() == "VIDEO_RESUME":
            if self.resume_live_video(session_token):
                response = b"OK state=LIVE wfb=active\n"
            else:
                response = b"ERROR live-video-resume-failed\n"
        elif parts[0].upper() == "KEEPALIVE":
            if self._refresh_session_lease(session_token):
                response = b"OK state=MAPPING\n"
            else:
                response = b"ERROR no-matching-session\n"
        else:
            response = b"ERROR use VIDEO_PAUSE, CAPTURE [seq], STATUS, KEEPALIVE, VIDEO_RESUME\n"
        self._manual_socket.sendto(response, address)

    def _handle_messages(
        self,
        messages: list[MavlinkMessage],
        *,
        from_flight_controller: bool,
    ) -> None:
        for message in messages:
            if (
                from_flight_controller
                and message.message_id == MAVLINK_MSG_ID_CAMERA_TRIGGER
                and len(message.payload) >= 12
            ):
                if self._ignore_uart_camera_trigger or self._gcs_controls_captures:
                    continue
                _time_usec, sequence = struct.unpack_from("<QI", message.payload)
                now = time.monotonic()
                if now <= self._suppress_next_camera_trigger_until:
                    self._suppress_next_camera_trigger_until = 0.0
                    LOGGER.info("Matched PX4 confirmation for one-shot command")
                    continue
                trigger_id = (message.system_id, message.component_id, sequence)
                if trigger_id in self._seen_camera_triggers:
                    continue
                self._seen_camera_triggers[trigger_id] = now
                self._capture_worker.request(
                    CaptureRequest("mavlink-camera-trigger", sequence)
                )
            elif (
                not from_flight_controller
                and message.message_id == MAVLINK_MSG_ID_COMMAND_LONG
                and len(message.payload) >= 33
            ):
                values = struct.unpack_from("<7fHBBB", message.payload)
                command = values[7]
                image_count = int(round(values[2]))
                if command == MAV_CMD_IMAGE_START_CAPTURE and image_count == 1:
                    if self._gcs_controls_captures:
                        continue
                    if self._capture_worker.request(
                        CaptureRequest("mavlink-one-shot-command")
                    )[0]:
                        self._suppress_next_camera_trigger_until = (
                            time.monotonic() + 10
                        )

    def _discard_old_trigger_ids(self) -> None:
        cutoff = time.monotonic() - 3600
        self._seen_camera_triggers = {
            key: timestamp
            for key, timestamp in self._seen_camera_triggers.items()
            if timestamp >= cutoff
        }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial-device", default="/dev/ttyAMA0")
    parser.add_argument("--serial-baud", type=int, default=57600)
    parser.add_argument("--wfb-host", default="127.0.0.1")
    parser.add_argument("--wfb-port", type=int, default=14550)
    parser.add_argument("--manual-host", default="0.0.0.0")
    parser.add_argument("--manual-port", type=int, default=14551)
    parser.add_argument("--photo-root", default="/home/shreeon/mapping_photos")
    parser.add_argument("--capture-user", default="shreeon")
    parser.add_argument("--camera-service", default="wfb-camera.service")
    parser.add_argument("--camera-command", default="/usr/local/bin/rpicam-vid")
    parser.add_argument(
        "--thumbnail-command", default="/home/shreeon/extract_jpeg_thumbnail.py"
    )
    parser.add_argument("--mapping-width", type=int, default=1920)
    parser.add_argument("--mapping-height", type=int, default=1080)
    parser.add_argument("--mapping-framerate", type=float, default=5.0)
    parser.add_argument("--mapping-quality", type=int, default=85)
    parser.add_argument("--mapping-buffer-count", type=int, default=2)
    parser.add_argument("--frame-wait-sec", type=float, default=3.0)
    parser.add_argument(
        "--session-lease-sec",
        type=float,
        default=45.0,
        help="Restore live video if a tokenized QGC session stops sending heartbeats",
    )
    parser.add_argument(
        "--video-release-delay-sec",
        type=float,
        default=2.0,
        help="Wait after stopping wfb-camera before starting mapping rpicam-vid",
    )
    return parser.parse_args()


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    arguments = parse_arguments()
    service = RouteMappingService(arguments)
    signal.signal(signal.SIGTERM, service.request_stop)
    signal.signal(signal.SIGINT, service.request_stop)
    signal.signal(signal.SIGUSR1, service.request_manual_capture)
    return service.run()


if __name__ == "__main__":
    sys.exit(main())
