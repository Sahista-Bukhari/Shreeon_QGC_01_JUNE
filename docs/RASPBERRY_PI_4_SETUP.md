# Raspberry Pi 4 Setup and QGroundControl Build Guide

This guide installs, copies, builds, and runs this customized QGroundControl project on a Raspberry Pi 4.

**Cross-compile on a PC and ship an AppImage (no second QGC compile):** see [RASPBERRY_PI_CROSS_BUILD_AND_APPIMAGE.md](RASPBERRY_PI_CROSS_BUILD_AND_APPIMAGE.md) and `deploy/linux/sync-cross-build-for-appimage.sh` / `package-appimage-on-pi.sh`.

## Requirements

- Raspberry Pi 4 with 4 GB RAM or more
- 64-bit operating system (`aarch64`)
- At least 25 GB free storage
- Active cooling during compilation
- Raspberry Pi and development computer connected to the same network
- Project on the development computer at:

  ```text
  ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE
  ```

The first build can take several hours on a 4 GB Raspberry Pi 4.

## 1. Install an operating system only when required

If the Pi already opens a terminal and commands such as `uname -m` work, it already has an operating system. Skip to [Verify the Pi](#2-verify-the-pi).

For a blank storage device, install Raspberry Pi Imager on a separate Linux computer:

```bash
sudo apt update
sudo apt install -y rpi-imager
rpi-imager
```

In Imager select:

1. Raspberry Pi 4
2. Ubuntu Desktop 24.04 LTS (64-bit)
3. The target SSD or microSD card
4. Configure a username, password, Wi-Fi, hostname, and enable SSH
5. Write and verify the image

Do not run the graphical `rpi-imager` program through a normal SSH session. It requires a graphical display. For headless imaging, install `rpi-imager-cli`, but only write to a separately connected target disk.

```bash
sudo apt install -y rpi-imager-cli
findmnt -no SOURCE /
lsblk -o NAME,SIZE,TYPE,MODEL,TRAN,MOUNTPOINTS
```

`/dev/mmcblk0` is a storage device name, not a command. If `/` is mounted from `/dev/mmcblk0p2`, never flash `/dev/mmcblk0` from that running system. A separately connected USB SSD normally appears as `/dev/sda`. Verify the device before writing because imaging permanently erases it.

## 2. Verify the Pi

Run on the Raspberry Pi:

```bash
uname -m
free -h
df -h /
nproc
hostname -I
```

Expected architecture:

```text
aarch64
```

Use the IPv4 address reported by `hostname -I`, such as `192.168.1.9`. An address ending in `.local` may not resolve on every network.

## 3. Copy the project to the Pi

Keep the existing Pi terminal open. Open a second terminal on the development computer.

Replace `<PI_IP>` with the Pi's IPv4 address:

```bash
ssh pi@<PI_IP> "mkdir -p ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE"
```

Copy the complete source tree:

```bash
rsync -av \
  --exclude build \
  --exclude .git \
  ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE/ \
  pi@<PI_IP>:/home/pi/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE/
```

On the Pi, enter and verify the copied project:

```bash
cd ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE

test -f CMakeLists.txt && echo "QGC source ready"

ls cmake/Helpers.cmake \
   cmake/CustomOptions.cmake \
   cmake/modules/Git.cmake \
   cmake/modules/CPM.cmake
```

If any CMake helper file is missing, run the same `rsync` command again before configuring. Missing helper files produce errors such as:

```text
include could not find requested file: Helpers
find_package called with invalid argument "..."
QTP0001 is not a known Qt policy
```

These are cascading incomplete-copy errors; do not modify `CMakeLists.txt` to work around them.

## 4. Install build and runtime dependencies

Run on the Pi:

```bash
sudo apt update

sudo apt install -y \
  build-essential cmake ninja-build git ccache pkg-config pipx patchelf \
  libx11-dev libx11-xcb-dev libxcb-cursor-dev libxcb-xinerama0-dev \
  libxkbcommon-dev libxkbcommon-x11-dev libgl1-mesa-dev libegl1-mesa-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libgstreamer-plugins-bad1.0-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav gstreamer1.0-gl \
  libusb-1.0-0-dev libvulkan-dev libpipewire-0.3-dev
```

## 5. Install Qt 6.10.1 for ARM64

The project requires Qt 6.10.1 and its additional modules.

```bash
pipx install aqtinstall
pipx ensurepath
source ~/.bashrc
aqt --version
```

Install Qt:

```bash
aqt install-qt \
  linux_arm64 desktop 6.10.1 linux_gcc_arm64 \
  --outputdir "$HOME/Qt" \
  -m qtcharts qtlocation qtpositioning qtspeech qt5compat \
     qtmultimedia qtserialport qtimageformats qtshadertools \
     qtconnectivity qtquick3d qtsensors qtscxml
```

This download is several gigabytes. Verify `qt-cmake` afterwards:

```bash
QT_CMAKE="$(find "$HOME/Qt" -type f -path '*/bin/qt-cmake' | head -n1)"
echo "$QT_CMAKE"
```

Expected path:

```text
/home/pi/Qt/6.10.1/gcc_arm64/bin/qt-cmake
```

## 6. Configure the QGC build

Enter the project directory:

```bash
cd ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE
```

Remove only a previous failed/generated build directory:

```bash
rm -rf ~/qgc-build
```

Configure a Release build:

```bash
QT_CMAKE="$(find "$HOME/Qt" -type f -path '*/bin/qt-cmake' | head -n1)"

"$QT_CMAKE" \
  -S . \
  -B "$HOME/qgc-build" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DQGC_BUILD_TESTING=OFF
```

Continue only when CMake finishes with:

```text
Build files have been written to: /home/pi/qgc-build
```

## 7. Compile

Use one build thread on a 4 GB Pi to reduce the chance of running out of memory:

```bash
cmake --build "$HOME/qgc-build" --parallel 1
```

Locate the resulting executable:

```bash
find "$HOME/qgc-build" -type f -name QGroundControl -executable
```

The expected executable is:

```text
/home/pi/qgc-build/Release/QGroundControl
```

## 8. Configure flight-controller serial access

```bash
sudo usermod -aG dialout "$(id -un)"
sudo systemctl mask --now ModemManager.service
```

Log out and back in, or reboot, so the new group membership takes effect:

```bash
sudo reboot
```

## 9. Run QGroundControl

QGroundControl is graphical. A monitor and active desktop session must exist on the Pi.

From a terminal opened directly on the Pi desktop:

```bash
~/qgc-build/Release/QGroundControl
```

From SSH while a Wayland desktop session is already active for the same user:

```bash
XDG_RUNTIME_DIR=/run/user/$(id -u) \
WAYLAND_DISPLAY=wayland-0 \
~/qgc-build/Release/QGroundControl
```

For an X11 desktop session:

```bash
DISPLAY=:0 ~/qgc-build/Release/QGroundControl
```

A normal headless SSH terminal cannot display the QGC interface without an active graphical session. Use a monitor, Raspberry Pi Connect, VNC, or another remote-desktop solution when the interface must be viewed remotely.

## 10. Update the source later

After changing the project on the development computer, synchronize it again:

```bash
rsync -av \
  --exclude build \
  --exclude .git \
  ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE/ \
  pi@<PI_IP>:/home/pi/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE/
```

Then rebuild on the Pi:

```bash
cmake --build "$HOME/qgc-build" --parallel 1
```

Rerun CMake configuration first if `CMakeLists.txt`, the `cmake` directory, Qt modules, or build options changed.
