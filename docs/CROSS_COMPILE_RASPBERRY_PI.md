# Cross-Compile Shreeon QGroundControl for Raspberry Pi (x86_64 → ARM64)

Build QGC on a **Linux x86_64 laptop/desktop**, deploy the binary to a **Raspberry Pi 4 (64-bit)**, and run it there. This avoids long native compiles and OOM issues on the Pi.

For **native build on the Pi**, see [RASPBERRY_PI_4_SETUP.md](RASPBERRY_PI_4_SETUP.md).

---

## Overview

| Item | Typical path |
|------|----------------|
| Source (laptop) | `~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE` |
| Qt **host** (x86_64, build tools) | `~/Qt/6.10.1/gcc_64` |
| Qt **target** (arm64, link) | `~/Qt/6.10.1/gcc_arm64` |
| Cross build directory (laptop) | `~/qgc-cross-build` |
| **Binary output** (laptop) | `~/qgc-cross-build/Release/QGroundControl` |
| Pi sysroot (laptop) | `~/rpi-sysroot` |
| Deploy on Pi | `~/qgc-cross/Release/QGroundControl` |
| Qt on Pi (runtime) | `~/Qt/6.10.1/gcc_arm64/lib` |

**Qt version:** 6.10.1 (see `.github/build-config.json`).

**Terminals:**

- **ASUS** — development machine (cross-compile, `rsync`).
- **Pi** — Raspberry Pi (`ssh admin@<PI_IP>` or local desktop terminal).

Replace `<PI_IP>` (e.g. `192.168.1.10`) and `admin` if your Pi user differs.

---

## 1. One-time setup on ASUS (laptop)

### 1.1 Cross toolchain and pkg-config

**Terminal: ASUS**

```bash
sudo apt update
sudo apt install -y \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  pkg-config rsync ccache ninja-build
```

Ubuntu 24.04 does **not** ship `pkg-config-aarch64-linux-gnu`; use host `pkg-config` with `PKG_CONFIG_SYSROOT_DIR` (below).

### 1.2 Qt 6.10.1 (host + target)

Install with [aqtinstall](https://github.com/miurahr/aqtinstall):

**Terminal: ASUS**

```bash
pipx install aqtinstall
pipx ensurepath
source ~/.bashrc

# Host (x86_64) — required for qsb, moc, etc. during cross-build
aqt install-qt linux desktop 6.10.1 linux_gcc_64 \
  --outputdir "$HOME/Qt" \
  -m qtcharts qtlocation qtpositioning qtspeech qt5compat \
     qtmultimedia qtserialport qtimageformats qtshadertools \
     qtconnectivity qtquick3d qtsensors qtscxml qtwayland

# Target (arm64) — link against this on the Pi
aqt install-qt linux_arm64 desktop 6.10.1 linux_gcc_arm64 \
  --outputdir "$HOME/Qt" \
  -m qtcharts qtlocation qtpositioning qtspeech qt5compat \
     qtmultimedia qtserialport qtimageformats qtshadertools \
     qtconnectivity qtquick3d qtsensors qtscxml qtwayland
```

Verify:

```bash
test -x ~/Qt/6.10.1/gcc_64/bin/qt-cmake && test -x ~/Qt/6.10.1/gcc_arm64/bin/qt-cmake && echo "QT OK"
```

### 1.3 Pi sysroot (headers + libraries for GStreamer/glib)

Copy enough of the Pi root filesystem for pkg-config and linking. Run from **ASUS** (Pi must be on the network):

```bash
export SYSROOT="$HOME/rpi-sysroot"
mkdir -p "$SYSROOT"

rsync -av --relative admin@<PI_IP>:/./usr/include \
  admin@<PI_IP>:/./usr/lib/aarch64-linux-gnu \
  admin@<PI_IP>:/./usr/share/pkgconfig \
  "$SYSROOT/"
```

On the Pi, GStreamer dev packages should be installed (same as native guide):

**Terminal: Pi**

```bash
sudo apt update
sudo apt install -y \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libgstreamer-plugins-bad1.0-dev \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-gl
```

Then re-run the `rsync` from **ASUS** if you add packages later.

**Sysroot symlinks** (helps CMake `FindGStreamer` when it falls back to `usr/lib`):

**Terminal: ASUS**

```bash
export SYSROOT="$HOME/rpi-sysroot"
sudo ln -sfn aarch64-linux-gnu/pkgconfig "$SYSROOT/usr/lib/pkgconfig"
sudo ln -sfn aarch64-linux-gnu/gstreamer-1.0 "$SYSROOT/usr/lib/gstreamer-1.0"
```

### 1.4 Chainload toolchain (force ARM64 for GStreamer discovery)

**Terminal: ASUS**

```bash
cat > ~/qgc-pi.toolchain.cmake << 'EOF'
set(CMAKE_SYSTEM_NAME Linux CACHE STRING "" FORCE)
set(CMAKE_SYSTEM_PROCESSOR aarch64 CACHE STRING "" FORCE)
set(CMAKE_SYSROOT "$ENV{HOME}/rpi-sysroot" CACHE PATH "" FORCE)
set(QT_HOST_PATH "$ENV{HOME}/Qt/6.10.1/gcc_64" CACHE PATH "" FORCE)
EOF
```

---

## 2. Configure and build (ASUS)

Always use **`qt-cmake` from the arm64 Qt kit**, **Ninja**, and **host `qsb`** (`gcc_64`). Do not run partial `cmake -B` without the full flag set (it breaks Qt discovery).

**Terminal: ASUS**

```bash
export SYSROOT="$HOME/rpi-sysroot"
export QT_HOST_PATH="$HOME/Qt/6.10.1/gcc_64"
export QT_TARGET_PATH="$HOME/Qt/6.10.1/gcc_arm64"
export QT_CMAKE="$QT_TARGET_PATH/bin/qt-cmake"

export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
export PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig:$SYSROOT/usr/share/pkgconfig"
unset PKG_CONFIG_PATH

pkg-config --cflags gstreamer-1.0 | grep -q "$SYSROOT" && echo "GST PKG OK" || echo "GST PKG WRONG — fix sysroot rsync"

cd ~/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE

# Clean configure (required after generator/toolchain mistakes)
rm -rf ~/qgc-cross-build

"$QT_CMAKE" \
  -S . \
  -B ~/qgc-cross-build \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$QT_TARGET_PATH/lib/cmake/Qt6/qt.toolchain.cmake" \
  -DQT_CHAINLOAD_TOOLCHAIN_FILE="$HOME/qgc-pi.toolchain.cmake" \
  -DCMAKE_SYSROOT="$SYSROOT" \
  -DGStreamer_ROOT_DIR="$SYSROOT/usr" \
  -DCMAKE_FIND_ROOT_PATH="$SYSROOT;$QT_TARGET_PATH" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DCMAKE_PREFIX_PATH="$QT_TARGET_PATH" \
  -DQT_HOST_PATH="$QT_HOST_PATH" \
  -DQSB_PROGRAM:FILEPATH="$QT_HOST_PATH/bin/qsb" \
  -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
  -DCMAKE_CXX_FLAGS="-march=armv8-a" \
  -DQGC_BUILD_TESTING=OFF \
  -DQGC_CREATE_APPIMAGE=OFF

grep -E 'CMAKE_GENERATOR:|^QSB_PROGRAM:' ~/qgc-cross-build/CMakeCache.txt
# Expect: Ninja and gcc_64/bin/qsb (NOT gcc_arm64/bin/qsb)

cmake --build ~/qgc-cross-build --parallel "$(nproc)"
```

Success:

```text
[xxxx/xxxx] Linking CXX executable Release/QGroundControl
```

Verify binary:

```bash
file ~/qgc-cross-build/Release/QGroundControl
ls -lh ~/qgc-cross-build/Release/QGroundControl
```

Expect **ELF 64-bit … ARM aarch64**. Do **not** run this file on the laptop.

### 2.1 Rebuild after source changes

**Terminal: ASUS**

```bash
cmake --build ~/qgc-cross-build --parallel "$(nproc)"
```

Re-run the full configure block only if you change toolchain, Qt paths, or sysroot.

### 2.2 Optional: build without GStreamer video

If GStreamer cross-compile fails and you need a binary quickly:

Add to the `"$QT_CMAKE"` line:

```bash
  -DQGC_ENABLE_GST_VIDEOSTREAMING=OFF \
```

Live camera/video pipeline will not work until GStreamer cross-build is fixed.

---

## 3. Deploy to Raspberry Pi

### 3.1 Copy Release folder

**Terminal: ASUS**

```bash
ssh admin@<PI_IP> 'mkdir -p ~/qgc-cross/Release'

rsync -av ~/qgc-cross-build/Release/ admin@<PI_IP>:~/qgc-cross/Release/
```

The runnable app is:

```text
/home/admin/qgc-cross/Release/QGroundControl
```

### 3.2 Qt runtime on the Pi

Each Pi needs Qt **6.10.1** `gcc_arm64` (same as [RASPBERRY_PI_4_SETUP.md §5](RASPBERRY_PI_4_SETUP.md)). Install with `aqt` on the Pi, or copy from a working Pi:

**Terminal: ASUS** (example: from Pi A to Pi B)

```bash
ssh admin@PI_A 'tar czf - -C $HOME Qt/6.10.1/gcc_arm64' | \
  ssh admin@PI_B 'mkdir -p ~/Qt/6.10.1 && tar xzf - -C ~/Qt/6.10.1'
```

---

## 4. Run on the Pi

### 4.1 Manual run (recommended for testing)

Use the **desktop Terminal on the HDMI monitor** (best for GUI). First start can take **~30–60 seconds** on Pi 4.

**Terminal: Pi**

```bash
env LD_LIBRARY_PATH=$HOME/Qt/6.10.1/gcc_arm64/lib \
  ~/qgc-cross/Release/QGroundControl
```

If the window is blank or missing, try:

```bash
export LD_LIBRARY_PATH=$HOME/Qt/6.10.1/gcc_arm64/lib
export QT_QPA_PLATFORM=wayland
~/qgc-cross/Release/QGroundControl
```

Or X11:

```bash
export LD_LIBRARY_PATH=$HOME/Qt/6.10.1/gcc_arm64/lib
export QT_QPA_PLATFORM=xcb
~/qgc-cross/Release/QGroundControl
```

Software rendering (slow, last resort):

```bash
export LD_LIBRARY_PATH=$HOME/Qt/6.10.1/gcc_arm64/lib
export QT_QPA_PLATFORM=wayland
export QSG_RHI_BACKEND=software
~/qgc-cross/Release/QGroundControl
```

### 4.2 Run from SSH (show on Pi monitor)

**Terminal: Pi (SSH)**

```bash
export DISPLAY=:0
export XAUTHORITY=/home/admin/.Xauthority
export LD_LIBRARY_PATH=$HOME/Qt/6.10.1/gcc_arm64/lib
export QT_QPA_PLATFORM=wayland
~/qgc-cross/Release/QGroundControl
```

On the **Pi desktop** once, if permission denied:

```bash
xhost +local:
```

### 4.3 Console messages you can ignore

- `en_GB` localization errors  
- `speechd` / TTS errors  
- `GeoClue2` / positioning errors (unless you use Pi GPS)  
- `OpenSans` font warnings  

If you see **`the application begins`** in the log, QGC started; look at the **HDMI display** or try `QT_QPA_PLATFORM` above.

Check process:

```bash
pgrep -a QGroundControl
```

---

## 5. Autostart on desktop login

**Terminal: Pi**

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/qgroundcontrol.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=QGroundControl
Exec=env LD_LIBRARY_PATH=/home/admin/Qt/6.10.1/gcc_arm64/lib QT_QPA_PLATFORM=wayland /home/admin/qgc-cross/Release/QGroundControl
X-GNOME-Autostart-enabled=true
EOF
```

Enable **Desktop Autologin** for your user:

```bash
sudo raspi-config
```

**System Options → Boot / Auto Login → Desktop Autologin**

Remove autostart (manual only):

```bash
rm ~/.config/autostart/qgroundcontrol.desktop
```

---

## 6. Troubleshooting (quick reference)

| Problem | What to do |
|--------|------------|
| `Exec format error` for `qsb` | Set `-DQSB_PROGRAM:FILEPATH=$HOME/Qt/6.10.1/gcc_64/bin/qsb` and `-DQT_HOST_PATH=$HOME/Qt/6.10.1/gcc_64` |
| Generator mismatch (Ninja vs Makefiles) | `rm -rf ~/qgc-cross-build` and full `qt-cmake` block again |
| GStreamer / `x86_64` in sysroot paths | `unset PKG_CONFIG_PATH`, `-DGStreamer_ROOT_DIR=$SYSROOT/usr`, chainload toolchain, sysroot symlinks |
| `uintptr_t` / gstqml6gl errors | Host x86 GStreamer headers; fix pkg-config sysroot (section 2) |
| `FindQt6` missing after partial cmake | Never run bare `cmake -B`; use full `"$QT_CMAKE"` configure |
| Missing `.so` on Pi | `LD_LIBRARY_PATH=$HOME/Qt/6.10.1/gcc_arm64/lib`; install/copy Qt on Pi |
| UI not visible | Run from Pi desktop terminal; set `QT_QPA_PLATFORM=wayland` or `xcb` |

Find all copies of the binary on Pi:

```bash
find ~ -name QGroundControl -type f -executable 2>/dev/null
```

---

## 7. Command cheat sheet

**Build (ASUS):**

```bash
cmake --build ~/qgc-cross-build --parallel "$(nproc)"
```

**Deploy (ASUS):**

```bash
rsync -av ~/qgc-cross-build/Release/ admin@<PI_IP>:~/qgc-cross/Release/
```

**Run (Pi):**

```bash
env LD_LIBRARY_PATH=$HOME/Qt/6.10.1/gcc_arm64/lib ~/qgc-cross/Release/QGroundControl
```

**Binary locations:**

- Laptop: `~/qgc-cross-build/Release/QGroundControl`  
- Pi: `~/qgc-cross/Release/QGroundControl`
