# Raspberry Pi route-mapping capture

**Full end-to-end guide (GCS + Pi + workflow + changelog):**  
[`docs/en/shreeon-route-mapping-implementation.md`](../../docs/en/shreeon-route-mapping-implementation.md)

This service keeps the existing WFB H.264 stream and captures full-resolution
4608x2592 JPEG files on the Raspberry Pi. **Route Mapping photo count and timing
come from QGC** (survey trigger distance and planned `cameraShots`); QGC sends
one sequenced **`CAPTURE N`** per calculated trigger over UDP **14551**, then
copies each JPEG with **SCP**. With **`QGC_LED=1`**, UART `CAMERA_TRIGGER` does
not queue extra Pi captures during a QGC session.

Photos are stored under:

```text
/home/shreeon/mapping_photos/mission_YYYYMMDD_HHMMSS/
```

## Required GCS SSH key

QGC uses non-interactive SCP and cannot answer a password prompt. Install the
GCS user's public key on the Pi before flying.

**Run on the GCS PC** (e.g. `shreeon@ubuntu`), not on the Pi. The drone link
(WFB) must be up so `10.5.0.2` is reachable.

If `ssh-copy-id` says **No identities found**, create a key first:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
ssh-copy-id -i ~/.ssh/id_ed25519.pub shreeon@10.5.0.2
ssh -o BatchMode=yes -o ConnectTimeout=3 shreeon@10.5.0.2 true
```

(Use `ssh-copy-id shreeon@10.5.0.2` instead if you already have `~/.ssh/id_rsa`
or `~/.ssh/id_ed25519`.)

The second command must exit successfully without prompting. QGC runs the same
precheck when a Route Mapping photo session starts and blocks the session with
a modal setup message if key authentication is unavailable.

GCS capture triggers use SSH (`/home/shreeon/capture.sh`, installed by
`install-on-pi.sh`) over a multiplexed connection, then SCP for each JPEG.

## Install / update Pi software

**On the GCS**, copy this folder to the Pi (adjust the repo path):

```bash
scp -r ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE/deploy/pi-route-mapping shreeon@10.5.0.2:~/
```

**On the Pi** (after `ssh shreeon@10.5.0.2`):

```bash
cd ~/pi-route-mapping
sudo bash install-on-pi.sh
```

Do not run `install-on-pi.sh` on the GCS — it only exists in the repo and must
run on the Raspberry Pi.

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
printf 'VIDEO_PAUSE' | nc -u -w 5 127.0.0.1 14551
printf 'CAPTURE' | nc -u -w 1 127.0.0.1 14551
printf 'VIDEO_RESUME' | nc -u -w 1 127.0.0.1 14551
```

`VIDEO_PAUSE` creates a folder at the current flight start time and returns its
authoritative path. QGroundControl stores that reply and sends sequenced,
idempotent triggers over the WFB LAN:

```text
> VIDEO_PAUSE
< OK session=/home/shreeon/mapping_photos/mission_20260919_124005
> CAPTURE 1
< QUEUED seq=1 path=/home/shreeon/mapping_photos/mission_…/image_0001_gcs_0001_….jpg
```

Files are named `image_0001_gcs_0001_<timestamp>.jpg` under the returned
`mission_YYYYMMDD_HHMMSS` directory. Repeating the same sequence within that
session is safe and does not take a duplicate photo. Set `MANUAL_HOST=0.0.0.0`
in `/etc/default/shreeon-route-mapping` so GCS can reach UDP port 14551. No
`QGC_LED` setting is required: `VIDEO_PAUSE` selects QGC as capture authority
for that session, and `VIDEO_RESUME` restores standalone UART triggering.

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
