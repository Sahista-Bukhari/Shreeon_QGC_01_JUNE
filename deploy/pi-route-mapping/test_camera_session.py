#!/usr/bin/env python3
"""Unit tests for reliable Route Mapping camera ownership recovery."""

from __future__ import annotations

import importlib.util
import pathlib
import sys
import time
import types
import unittest
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).with_name("shreeon_route_mapping.py")
SPEC = importlib.util.spec_from_file_location("shreeon_route_mapping", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
ROUTE_MAPPING = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = ROUTE_MAPPING
SPEC.loader.exec_module(ROUTE_MAPPING)


class FakeCaptureWorker:
    def __init__(self, *, mapping_running: bool = False) -> None:
        self.mapping_video_running = mapping_running
        self.session_directory = pathlib.Path("/home/shreeon/mapping_photos/mission_test")
        self.cancelled = False
        self.mapping_stopped = False
        self.video_paused = True
        self.thumbnails_resumed = False
        self.session_closed = False

    def cancel_pending(self) -> int:
        self.cancelled = True
        return 0

    def wait_until_idle(self, _timeout: float) -> bool:
        return True

    def wait_until_drained(self, _timeout: float) -> bool:
        return True

    def stop_mapping_video(self) -> None:
        self.mapping_stopped = True
        self.mapping_video_running = False

    def set_session_video_paused(self, paused: bool) -> None:
        self.video_paused = paused

    def resume_thumbnail_processing(self) -> None:
        self.thumbnails_resumed = True

    def close_session(self) -> None:
        self.session_closed = True
        self.session_directory = None


class FakeManualSocket:
    def __init__(self, command: bytes) -> None:
        self.command = command
        self.replies: list[bytes] = []

    def recvfrom(self, _size: int):
        return self.command, ("127.0.0.1", 12345)

    def sendto(self, response: bytes, _address) -> None:
        self.replies.append(response)


def make_service(*, mapping_running: bool = False):
    service = ROUTE_MAPPING.RouteMappingService.__new__(
        ROUTE_MAPPING.RouteMappingService
    )
    service._arguments = types.SimpleNamespace(
        camera_service="wfb-camera.service", session_lease_sec=45.0
    )
    service._capture_worker = FakeCaptureWorker(mapping_running=mapping_running)
    service._gcs_controls_captures = True
    service._gcs_session_token = "owner-token"
    service._session_lease_deadline = time.monotonic() + 45.0
    return service


class CameraSessionRecoveryTest(unittest.TestCase):
    def test_verified_resume_releases_ownership(self) -> None:
        service = make_service(mapping_running=True)
        service._start_live_video_verified = mock.Mock(return_value=True)

        self.assertTrue(service.resume_live_video("owner-token"))

        self.assertFalse(service._gcs_controls_captures)
        self.assertIsNone(service._gcs_session_token)
        self.assertEqual(service._session_lease_deadline, 0.0)
        self.assertTrue(service._capture_worker.mapping_stopped)
        self.assertTrue(service._capture_worker.thumbnails_resumed)
        self.assertTrue(service._capture_worker.session_closed)

    def test_failed_service_restart_retains_recovery_handle(self) -> None:
        service = make_service(mapping_running=True)
        service._start_live_video_verified = mock.Mock(return_value=False)

        self.assertFalse(service.resume_live_video("owner-token"))

        self.assertTrue(service._gcs_controls_captures)
        self.assertEqual(service._gcs_session_token, "owner-token")
        self.assertFalse(service._capture_worker.session_closed)

    def test_tokenized_resume_repairs_inactive_live_service(self) -> None:
        service = make_service()
        service._gcs_controls_captures = False
        service._gcs_session_token = None
        service._camera_service_streaming = mock.Mock(return_value=False)
        service._start_live_video_verified = mock.Mock(return_value=True)

        self.assertTrue(service.resume_live_video("completed-token"))

        service._start_live_video_verified.assert_called_once_with()

    def test_non_owner_cannot_resume_mapping_session(self) -> None:
        service = make_service(mapping_running=True)
        service._start_live_video_verified = mock.Mock(return_value=True)

        self.assertFalse(service.resume_live_video("different-token"))

        self.assertTrue(service._gcs_controls_captures)
        self.assertFalse(service._capture_worker.mapping_stopped)
        service._start_live_video_verified.assert_not_called()

    def test_expired_lease_automatically_resumes_live_video(self) -> None:
        service = make_service(mapping_running=True)
        service._session_lease_deadline = time.monotonic() - 1.0
        service.resume_live_video = mock.Mock(return_value=True)

        service._check_session_lease()

        service.resume_live_video.assert_called_once_with("owner-token")

    def test_matching_keepalive_refreshes_lease(self) -> None:
        service = make_service(mapping_running=True)
        old_deadline = service._session_lease_deadline

        self.assertTrue(service._refresh_session_lease("owner-token"))
        self.assertGreaterEqual(service._session_lease_deadline, old_deadline)
        self.assertFalse(service._refresh_session_lease("different-token"))

    def test_duplicate_pause_reuses_owned_mapping_session(self) -> None:
        service = make_service(mapping_running=True)
        session_directory = service._capture_worker.session_directory

        self.assertEqual(
            service.pause_live_video("owner-token"), session_directory
        )
        with self.assertRaisesRegex(RuntimeError, "another QGC mapping session"):
            service.pause_live_video("different-token")

    def test_tokenized_status_reports_authoritative_process_state(self) -> None:
        service = make_service(mapping_running=True)
        service._camera_service_active = mock.Mock(return_value=False)
        service._manual_socket = FakeManualSocket(b"STATUS session=owner-token")

        service._read_manual()

        self.assertEqual(len(service._manual_socket.replies), 1)
        self.assertIn(b"STATE MAPPING", service._manual_socket.replies[0])
        self.assertIn(b"token=owner-token", service._manual_socket.replies[0])
        self.assertIn(b"wfb=inactive", service._manual_socket.replies[0])

    def test_legacy_status_format_remains_compatible(self) -> None:
        service = make_service(mapping_running=True)
        service._manual_socket = FakeManualSocket(b"STATUS")

        service._read_manual()

        self.assertEqual(
            service._manual_socket.replies,
            [b"SESSION /home/shreeon/mapping_photos/mission_test\n"],
        )

    def test_stream_health_requires_camera_and_gstreamer_processes(self) -> None:
        service = make_service()
        service._camera_service_active = mock.Mock(return_value=True)
        process_results = [
            types.SimpleNamespace(stdout="756\n"),
            types.SimpleNamespace(
                stdout="792 rpicam-vid -t 0\n794 gst-launch-1.0 fdsrc\n"
            ),
        ]
        with mock.patch.object(
            ROUTE_MAPPING.subprocess, "run", side_effect=process_results
        ):
            self.assertTrue(service._camera_service_streaming())


if __name__ == "__main__":
    unittest.main()
