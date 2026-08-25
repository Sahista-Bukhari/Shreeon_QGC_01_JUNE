#!/usr/bin/env python3
"""Bridge PX4 MAVLink through WFB and save full-resolution mapping photos."""

from __future__ import annotations

import argparse
import dataclasses
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
        timeout_ms: int,
    ) -> None:
        super().__init__(name="photo-capture", daemon=True)
        self._requests: queue.Queue[CaptureRequest | None] = queue.Queue(maxsize=64)
        self._capture_user = capture_user
        self._camera_service = camera_service
        self._camera_command = camera_command
        self._timeout_ms = timeout_ms
        self._counter = 0
        self._session_directory = self._create_session_directory(photo_root)

    @property
    def session_directory(self) -> pathlib.Path:
        return self._session_directory

    def request(self, request: CaptureRequest) -> bool:
        try:
            self._requests.put_nowait(request)
            LOGGER.info(
                "Queued photo from %s (sequence=%s)",
                request.source,
                request.sequence,
            )
            return True
        except queue.Full:
            LOGGER.error("Photo queue is full; dropping trigger from %s", request.source)
            return False

    def stop(self) -> None:
        try:
            self._requests.put_nowait(None)
        except queue.Full:
            LOGGER.warning("Photo queue is busy; stopping after queued captures")

    def run(self) -> None:
        while True:
            request = self._requests.get()
            if request is None:
                return
            try:
                self._capture(request)
            except Exception:
                LOGGER.exception("Full-resolution capture failed")

    def _create_session_directory(self, photo_root: pathlib.Path) -> pathlib.Path:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        session_directory = photo_root / f"mission_{timestamp}"
        session_directory.mkdir(parents=True, exist_ok=True)
        account = pwd.getpwnam(self._capture_user)
        os.chown(session_directory, account.pw_uid, account.pw_gid)
        LOGGER.info("Photo session: %s", session_directory)
        return session_directory

    def _capture(self, request: CaptureRequest) -> None:
        self._counter += 1
        trigger_sequence = (
            f"px4_{request.sequence:06d}"
            if request.sequence is not None
            else f"local_{self._counter:06d}"
        )
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
        filename = self._session_directory / (
            f"image_{self._counter:06d}_{trigger_sequence}_{timestamp}.jpg"
        )
        temporary_filename = filename.with_suffix(".part.jpg")

        video_was_active = (
            subprocess.run(
                ["systemctl", "is-active", "--quiet", self._camera_service],
                check=False,
            ).returncode
            == 0
        )

        try:
            if video_was_active:
                subprocess.run(
                    ["systemctl", "stop", self._camera_service], check=True
                )

            command = [
                "/usr/sbin/runuser",
                "-u",
                self._capture_user,
                "--",
                "/usr/bin/env",
                "XDG_RUNTIME_DIR=/run/user/1000",
                self._camera_command,
                "--timeout",
                str(self._timeout_ms),
                "--nopreview",
                "--autofocus-mode",
                "auto",
                "--width",
                "4608",
                "--height",
                "2592",
                "--quality",
                "95",
                "--output",
                str(temporary_filename),
            ]
            subprocess.run(command, check=True, timeout=30)
            if not temporary_filename.is_file() or temporary_filename.stat().st_size == 0:
                raise RuntimeError("rpicam-still did not create a JPEG")
            temporary_filename.replace(filename)
            LOGGER.info("Saved %s (%d bytes)", filename, filename.stat().st_size)
        finally:
            if temporary_filename.exists():
                temporary_filename.unlink()
            if video_was_active:
                subprocess.run(
                    ["systemctl", "start", self._camera_service], check=False
                )


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
            arguments.capture_timeout_ms,
        )

    def request_stop(self, _signum: int, _frame: object) -> None:
        self._stop_requested = True

    def request_manual_capture(self, _signum: int, _frame: object) -> None:
        self._capture_worker.request(CaptureRequest("signal"))

    def run(self) -> int:
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

        self._capture_worker.stop()
        self._capture_worker.join(timeout=35)
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
        command = data.strip().upper()
        if command == b"CAPTURE":
            queued = self._capture_worker.request(CaptureRequest("manual-udp"))
            response = b"QUEUED\n" if queued else b"BUSY\n"
        elif command == b"STATUS":
            response = f"SESSION {self._capture_worker.session_directory}\n".encode()
        else:
            response = b"ERROR use CAPTURE or STATUS\n"
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
                    if self._capture_worker.request(
                        CaptureRequest("mavlink-one-shot-command")
                    ):
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
    parser.add_argument("--manual-host", default="127.0.0.1")
    parser.add_argument("--manual-port", type=int, default=14551)
    parser.add_argument("--photo-root", default="/home/shreeon/mapping_photos")
    parser.add_argument("--capture-user", default="shreeon")
    parser.add_argument("--camera-service", default="wfb-camera.service")
    parser.add_argument("--camera-command", default="/usr/local/bin/rpicam-still")
    parser.add_argument("--capture-timeout-ms", type=int, default=2000)
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
