# Raspberry Pi route-mapping capture

This service keeps the existing WFB H.264 stream and captures full-resolution
4608x2592 JPEG files on the Raspberry Pi when PX4 emits a MAVLink
`CAMERA_TRIGGER` message. A capture pauses the live video for a few seconds and
then restarts it automatically.

Photos are stored under:

```text
/home/shreeon/mapping_photos/mission_YYYYMMDD_HHMMSS/
```

The service also bridges MAVLink between `/dev/ttyAMA0` and the WFB UDP endpoint
at `127.0.0.1:14550`. The default serial speed is 57600 baud and can be changed
in `/etc/default/shreeon-route-mapping`.

The flight controller must be connected as follows:

```text
Flight-controller TELEM TX -> Pi GPIO15 / UART RX (physical pin 10)
Flight-controller TELEM RX -> Pi GPIO14 / UART TX (physical pin 8)
Flight-controller GND      -> Pi GND
```

Do not connect a 5 V serial signal to the Pi UART. Both sides must use 3.3 V
UART logic.

For a safe manual test while disarmed:

```bash
printf 'CAPTURE' | nc -u -w 1 127.0.0.1 14551
```

QGroundControl (GCS-led capture) sends sequenced triggers over the WFB LAN:

```bash
printf 'CAPTURE 1' | nc -u -w 1 10.5.0.2 14551
```

Files are named `image_0001_gcs_0001_<timestamp>.jpg` under the active
`mission_*` session directory. Set `MANUAL_HOST=0.0.0.0` and `QGC_LED=1` in
`/etc/default/shreeon-route-mapping` so GCS can reach UDP port 14551 and UART
`CAMERA_TRIGGER` does not double-capture.

During a Route Mapping flight, QGC sends `VIDEO_PAUSE` when the photo session
starts (stops `wfb-camera.service` for the whole session so `rpicam-still` can
use the sensor) and `VIDEO_RESUME` when the session ends:

```bash
printf 'VIDEO_PAUSE' | nc -u -w 1 10.5.0.2 14551
printf 'VIDEO_RESUME' | nc -u -w 1 10.5.0.2 14551
```

The same test can be requested without netcat:

```bash
sudo systemctl kill --signal=SIGUSR1 route-mapping-capture.service
```

Check operation and saved files:

```bash
systemctl status route-mapping-capture.service wfb-camera.service
journalctl -u route-mapping-capture.service -n 100 --no-pager
find /home/shreeon/mapping_photos -type f -name '*.jpg' -printf '%s %p\n'
```

The automatic route-mapping trigger requires valid MAVLink bytes from PX4. If
the service shows no telemetry, verify the crossed TX/RX wiring, shared ground,
PX4 TELEM port selection, and the configured baud rate.
