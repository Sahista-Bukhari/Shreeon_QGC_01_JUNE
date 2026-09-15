# Raspberry Pi Route Mapping capture

The route-mapping service keeps the existing PX4 UART/WFB MAVLink bridge alive.
QGC invokes `shreeon-route-mapping-camera` over SSH for each requested real
4608x2592 still image. The helper pauses `wfb-camera.service`, captures with
`rpicam-still`, and restarts the video service in a `finally` path.

The Pi copy exists only in volatile runtime storage while QGC transfers it:

```text
/run/shreeon-route-mapping/photos/<qgc-request-token>.jpg
```

QGC downloads to a local `.part` file, validates the JPEG, atomically renames
it into QGC's configured Photo directory, and then sends an `ack` command that
deletes the Pi copy. Repeating a capture token returns the same temporary file,
so SSH/SCP retries cannot operate the camera or download a new photo twice.

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

## Pi installation

Install the helper as a root-owned executable:

```bash
sudo install -o root -g root -m 0755 route_mapping_camera_once.py \
    /usr/local/libexec/shreeon-route-mapping-camera
```

Allow only the fixed, root-owned helper to run without an interactive password.
Create `/etc/sudoers.d/shreeon-route-mapping-camera` with `visudo`:

```sudoers
shreeon ALL=(root) NOPASSWD: /usr/local/libexec/shreeon-route-mapping-camera *
```

Validate the rule, then test one capture while the vehicle is disarmed:

```bash
sudo visudo -cf /etc/sudoers.d/shreeon-route-mapping-camera
sudo -n /usr/local/libexec/shreeon-route-mapping-camera capture manual_001
sudo -n /usr/local/libexec/shreeon-route-mapping-camera ack manual_001
```

Install the modified service script, default file, and systemd unit at their
normal Pi locations, then reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart route-mapping-capture.service
systemctl status route-mapping-capture.service wfb-camera.service --no-pager
```

The legacy service can still capture observed MAVLink triggers when explicitly
started with `--capture-from-mavlink`. Do not enable that option with QGC's SSH
capture path, because both paths would otherwise request the same camera shot.
The option changes capture ownership only; serial/WFB MAVLink forwarding remains
active regardless.
