# Raspberry Pi cross-build and AppImage (Shreeon QGC)

This guide matches the **cross-compile → deploy → AppImage** workflow used internally (sysroot from the Pi, Qt **6.10.1** host + ARM kits, Shreeon source tree). It replaces older notes that built Qt **6.8.3** from source and installed to `~/qgc-rpi-install` with `LD_LIBRARY_PATH`.

Paths below use the **development host** layout:

| Item | Path |
|------|------|
| Shreeon QGC source | `~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE` |
| Cross build directory | `~/qgc-cross-build` |
| Pi sysroot on host | `~/rpi-sysroot` |
| Qt host (x86_64 tools) | `~/Qt/6.10.1/gcc_64` |
| Qt target (ARM64 libs) | `~/Qt/6.10.1/gcc_arm64` |

Replace `pi@<PI_IP>` with your Pi SSH target.

For **native build on the Pi only** (no cross-compile), see [RASPBERRY_PI_4_SETUP.md](RASPBERRY_PI_4_SETUP.md).

---

## 1. Prepare the Raspberry Pi (target)

```bash
sudo apt update
sudo apt upgrade -y

sudo apt install -y build-essential git cmake ninja-build rsync patchelf \
  wget fuse libfuse2

sudo apt install -y \
  libclang-dev libgl1-mesa-dev libglu1-mesa-dev \
  libx11-dev libxext-dev libxfixes-dev libxi-dev \
  libxrender-dev libxrandr-dev libxinerama-dev \
  libxkbcommon-dev libudev-dev libinput-dev \
  libdrm-dev libgbm-dev libfontconfig1-dev libfreetype6-dev \
  libpng-dev libjpeg-dev libasound2-dev \
  libegl1-mesa-dev libgles2-mesa-dev libvulkan-dev \
  libxcb-glx0-dev libxcb-cursor-dev libwayland-dev wayland-protocols \
  libmtdev-dev libevdev-dev libpulse-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libgstreamer-plugins-bad1.0-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav gstreamer1.0-gl \
  libssl-dev libsqlite3-dev libgeoclue-2-dev \
  libbluetooth-dev bluez libzstd-dev zlib1g-dev libusb-1.0-0-dev \
  libpipewire-0.3-dev
```

Install **Qt 6.10.1 ARM64 on the Pi** for AppImage packaging (not for recompiling QGC if you cross-built on the host).

**Recommended:** copy Qt from the dev PC (same kit used for cross-compile; avoids large downloads on the Pi):

```bash
# On the dev PC:
PI_HOST=shreeoncm5@192.168.1.12 ./deploy/linux/sync-qt-arm64-to-pi.sh
```

**Alternative:** install on the Pi with `aqtinstall`. If you see `IncompleteRead` / `ArchiveDownloadError`, clear the cache and retry, or use the rsync method above:

```bash
pipx install aqtinstall
pipx ensurepath
source ~/.bashrc
rm -rf ~/.local/share/aqt ~/.cache/aqt 2>/dev/null || true

aqt install-qt linux_arm64 desktop 6.10.1 linux_gcc_arm64 \
  --outputdir "$HOME/Qt" \
  -m qtcharts qtlocation qtpositioning qtspeech qt5compat \
     qtmultimedia qtserialport qtimageformats qtshadertools \
     qtconnectivity qtquick3d qtsensors qtscxml
```

Flight-controller serial access:

```bash
sudo usermod -aG dialout "$(id -un)"
sudo systemctl mask --now ModemManager.service
```

---

## 2. Prepare sysroot on the host

On the **development PC** (x86_64):

```bash
sudo apt update
sudo apt install -y \
  build-essential git cmake ninja-build ccache \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  rsync python3 python3-pip pkg-config patchelf \
  libxkbcommon-dev

mkdir -p ~/rpi-sysroot
rsync -avz pi@<PI_IP>:/lib/ ~/rpi-sysroot/lib/
rsync -avz pi@<PI_IP>:/usr/include/ ~/rpi-sysroot/usr/include/
rsync -avz pi@<PI_IP>:/usr/lib/ ~/rpi-sysroot/usr/lib/
rsync -avz pi@<PI_IP>:/usr/share/pkgconfig/ ~/rpi-sysroot/usr/share/pkgconfig/
```

If the linker misses XCB GL extensions, copy them from the Pi (adjust user/IP):

```bash
mkdir -p ~/rpi-sysroot/usr/include/xcb
scp pi@<PI_IP>:/usr/include/xcb/* ~/rpi-sysroot/usr/include/xcb/
scp pi@<PI_IP>:/usr/lib/aarch64-linux-gnu/libxcb-glx.so* \
  ~/rpi-sysroot/usr/lib/aarch64-linux-gnu/
```

---

## 3. Qt and cross-compiler on the host (recommended: aqt)

This project uses **Qt 6.10.1**, not a from-source Qt 6.8 tree.

On the host:

```bash
pipx install aqtinstall
aqt install-qt linux desktop 6.10.1 linux_gcc_64 --outputdir "$HOME/Qt" \
  -m qtcharts qtlocation qtpositioning qtspeech qt5compat \
     qtmultimedia qtserialport qtimageformats qtshadertools \
     qtconnectivity qtquick3d qtsensors qtscxml

aqt install-qt linux_arm64 desktop 6.10.1 linux_gcc_arm64 --outputdir "$HOME/Qt" \
  -m qtcharts qtlocation qtpositioning qtspeech qt5compat \
     qtmultimedia qtserialport qtimageformats qtshadertools \
     qtconnectivity qtquick3d qtsensors qtscxml
```

Cross GCC:

```bash
sudo apt install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

Optional manual toolchain file (`~/toolchain-aarch64.cmake`) — only if you are **not** using Qt’s `qt.toolchain.cmake`:

```cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_SYSROOT "$ENV{HOME}/rpi-sysroot")
set(CMAKE_FIND_ROOT_PATH "${CMAKE_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
```

---

## 4. Configure and cross-build Shreeon QGC (host)

```bash
cd ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE

export QT_HOST_PATH="$HOME/Qt/6.10.1/gcc_64"
export PATH="$HOME/Qt/6.10.1/gcc_64/bin:$PATH"

"$HOME/Qt/6.10.1/gcc_arm64/bin/qt-cmake" \
  -S . \
  -B "$HOME/qgc-cross-build" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DQGC_BUILD_TESTING=OFF \
  -DCMAKE_FIND_ROOT_PATH="$HOME/rpi-sysroot;$HOME/Qt/6.10.1/gcc_arm64"

cmake --build "$HOME/qgc-cross-build" --parallel "$(nproc)"
```

Verify the binary:

```bash
file "$HOME/qgc-cross-build/Release/QGroundControl"
# Expect: ARM aarch64
```

Populate `AppDir` (install copies the binary, desktop entry, icons, and `AppRun`; **AppImage is not built on the cross-compile host**):

```bash
# Reconfigure once after pulling install.cmake fixes:
"$HOME/Qt/6.10.1/gcc_arm64/bin/qt-cmake" -S . -B "$HOME/qgc-cross-build"

cmake --install "$HOME/qgc-cross-build" --config Release
```

On an x86 host building for `aarch64`, install prints *Skipping AppImage on cross-build host* and finishes successfully. You need `~/qgc-cross-build/AppDir/`, `AppRun`, and `qml/` before syncing to the Pi.

Keep `-DQGC_CREATE_APPIMAGE=OFF` for cross builds (default in many cross trees). AppImage creation is only `package-appimage-on-pi.sh` on the Pi.

---

## 5. Create AppImage **without rebuilding QGC**

Qt does not bundle libraries during cross-install. **linuxdeploy** (with the Qt plugin) must run on **aarch64** — on the Pi.

### 5.1 From the host — sync package tree to the Pi

```bash
cd ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE

PI_HOST=pi@<PI_IP> \
QGC_CROSS_BUILD="$HOME/qgc-cross-build" \
  ./deploy/linux/sync-cross-build-for-appimage.sh
```

### 5.2 On the Pi — package AppImage

```bash
~/qgc-package/package-appimage-on-pi.sh
```

Output:

```text
~/qgc-package/QGroundControl-aarch64.AppImage
```

Run from the **Pi desktop** (local terminal or SSH with Wayland/X11 env vars — see [RASPBERRY_PI_4_SETUP.md §9](RASPBERRY_PI_4_SETUP.md)):

```bash
chmod +x ~/qgc-package/QGroundControl-aarch64.AppImage
~/qgc-package/QGroundControl-aarch64.AppImage
```

Copy the AppImage to other Pis:

```bash
scp pi@<PI_IP>:~/qgc-package/QGroundControl-aarch64.AppImage .
```

---

## 6. Legacy install layout (no AppImage)

If you still use a plain install prefix from cross-build (`cmake --install --prefix ~/qgc-rpi-install` on an older workflow), on the Pi:

```bash
LD_LIBRARY_PATH=/usr/local/qt6/lib ./QGroundControl
```

Prefer the **AppImage** above; it bundles Qt and GStreamer dependencies.

**Full-screen (optional):** in `/boot/firmware/config.txt`, comment out overscan disable if the display is cropped:

```text
# disable_overscan=1
```

---

## 7. PX4 SITL + QGC on the Pi (UDP)

On Ubuntu host:

```bash
git clone https://github.com/PX4/PX4-Autopilot.git --recursive
cd PX4-Autopilot
bash ./Tools/setup/ubuntu.sh
# reboot, then:
make px4_sitl gz_x500
```

Example with home location and MAVLink to the Pi (`192.168.1.13` = Pi IP, adjust):

```bash
PX4_HOME_LAT=13.065902545597691 \
PX4_HOME_LON=77.52597087967361 \
PX4_HOME_ALT=10 \
make px4_sitl gz_x500
```

In PX4 shell:

```text
param set MAV_0_BROADCAST 1
param save
mavlink stop-all
mavlink start -x -u 14550 -r 400000 -t 192.168.1.13
```

In QGC on the Pi: **Application Settings → Comm Links → Add → UDP**, listening port **14550**. Connect.

Debug UDP on the Pi:

```bash
sudo tcpdump -i wlan0 udp port 14550
```

---

## 8. Archive bundles (QGC_Build.tar.xz / QGroundControl_install.tar.xz)

If you received pre-made tarballs instead of building locally:

1. Extract **QGC_Build.tar.xz** into `~/qgc-cross-build` (or merge `AppDir`, `Release/QGroundControl`, `AppRun`, `qml`).
2. Extract **QGroundControl_install.tar.xz** only if you use the legacy prefix layout (§6).
3. Continue from **§5** to produce `QGroundControl-aarch64.AppImage` on the Pi.

---

## Quick reference

| Step | Where | Action |
|------|--------|--------|
| Cross-compile | Host | `qt-cmake` + `cmake --build ~/qgc-cross-build` |
| AppImage bundle | Pi | `package-appimage-on-pi.sh` after sync |
| Run | Pi desktop | `./QGroundControl-aarch64.AppImage` |
| SITL | Host | PX4 `make px4_sitl gz_x500`, UDP 14550 to Pi |
