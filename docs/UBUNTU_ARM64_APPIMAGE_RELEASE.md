# Shreeon QGC AppImage release for Ubuntu ARM64

This guide creates an ARM64 QGroundControl AppImage for the Ubuntu device at
`shreeoncm5@192.168.1.12`.

The QGC source is compiled on the x86_64 development PC. The resulting ARM64
files are copied to the CM5, where the final AppImage is packaged. Packaging on
the target prevents architecture and runtime-library mismatches.

## Terminal labels

Pay attention to the prompt before running a command.

| Label | Machine | Expected prompt | `uname -m` |
|---|---|---|---|
| **DEV PC** | Development PC | `shreeon-technologies@...` | `x86_64` |
| **CM5** | Ubuntu ARM64 target | `shreeoncm5@ubuntu` | `aarch64` |

Do not type backslashes before underscores. For example, use
`shreeon_Tech_V1`, not `shreeon\_Tech\_V1`.

## Quick repeat release after source changes

Use this section after the first build has already been configured and Qt is
already installed on both machines.

### 1. Rebuild and stage on the DEV PC

Run all commands in this section on the **DEV PC**:

```bash
uname -m
cd "$HOME/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE"

export QT_HOST_PATH="$HOME/Qt/6.10.1/gcc_64"
export PATH="$HOME/Qt/6.10.1/gcc_64/bin:$PATH"
export PKG_CONFIG_SYSROOT_DIR="$HOME/rpi-sysroot"
export PKG_CONFIG_LIBDIR="$HOME/rpi-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$HOME/rpi-sysroot/usr/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$HOME/rpi-sysroot/usr/share/pkgconfig"

cmake --build "$HOME/qgc-cross-build" --parallel 4
file "$HOME/qgc-cross-build/Release/QGroundControl"
cmake --install "$HOME/qgc-cross-build" --config Release
```

The `file` command must report `ARM aarch64`. Do not deploy an `x86-64`
binary to the CM5.

### 2. Sync the staged release from the DEV PC

Still on the **DEV PC**:

```bash
cd "$HOME/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE"

PI_HOST="shreeoncm5@192.168.1.12" \
QGC_CROSS_BUILD="$HOME/qgc-cross-build" \
  ./deploy/linux/sync-cross-build-for-appimage.sh
```

This replaces the remote `~/qgc-package/AppDir` with the newly staged build.

### 3. Package on the CM5

Connect from the **DEV PC**:

```bash
ssh shreeoncm5@192.168.1.12
```

The prompt must now show `shreeoncm5@ubuntu`. Run on the **CM5**:

```bash
QGC_PACKAGE_DIR="$HOME/qgc-package" \
QT_ROOT="$HOME/Qt/6.10.1/gcc_arm64" \
"$HOME/qgc-package/package-appimage-on-pi.sh"
```

After the script prints `Success`, publish it to `~/Videos`:

```bash
mkdir -p "$HOME/Videos"

install -m 755 \
  "$HOME/qgc-package/QGroundControl-aarch64.AppImage" \
  "$HOME/Videos/QGroundControl-aarch64.AppImage"

ls -lh "$HOME/Videos/QGroundControl-aarch64.AppImage"
sha256sum "$HOME/Videos/QGroundControl-aarch64.AppImage"
```

The released file is:

```text
/home/shreeoncm5/Videos/QGroundControl-aarch64.AppImage
```

## First-time setup

### 1. Verify both machines

On the **DEV PC**:

```bash
uname -m
```

Expected: `x86_64`.

On the **CM5**:

```bash
uname -m
hostname -I
```

Expected architecture: `aarch64`.

`uname -n` only displays the hostname and cannot be used to select the target
architecture.

### 2. Install DEV PC prerequisites

Run on the **DEV PC**:

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake ninja-build ccache \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  rsync pkg-config patchelf wget
```

The expected Qt directories are:

```text
~/Qt/6.10.1/gcc_64
~/Qt/6.10.1/gcc_arm64
```

The x86_64 Qt kit supplies build tools. The ARM64 kit supplies target headers
and libraries.

If either Qt kit is missing, install both on the **DEV PC**:

```bash
sudo apt install -y pipx
pipx install aqtinstall
pipx ensurepath
source "$HOME/.bashrc"

aqt install-qt linux desktop 6.10.1 linux_gcc_64 \
  --outputdir "$HOME/Qt" \
  -m qtcharts qtlocation qtpositioning qtspeech qt5compat \
     qtmultimedia qtserialport qtimageformats qtshadertools \
     qtconnectivity qtquick3d qtsensors qtscxml

aqt install-qt linux_arm64 desktop 6.10.1 linux_gcc_arm64 \
  --outputdir "$HOME/Qt" \
  -m qtcharts qtlocation qtpositioning qtspeech qt5compat \
     qtmultimedia qtserialport qtimageformats qtshadertools \
     qtconnectivity qtquick3d qtsensors qtscxml
```

Prepare the **CM5** for packaging:

```bash
sudo apt update
sudo apt install -y rsync wget patchelf
```

The packaging script installs the available ARM64 GStreamer runtime packages
that it needs. It runs AppImage tools with extraction enabled, so FUSE is not
required merely to create the AppImage.

### 3. Create or refresh the CM5 sysroot

These commands run on the **DEV PC**, not on the CM5:

```bash
export PI_HOST="shreeoncm5@192.168.1.12"

mkdir -p "$HOME/rpi-sysroot/lib"
mkdir -p "$HOME/rpi-sysroot/usr/include"
mkdir -p "$HOME/rpi-sysroot/usr/lib"
mkdir -p "$HOME/rpi-sysroot/usr/share/pkgconfig"

rsync -avz "$PI_HOST:/lib/" "$HOME/rpi-sysroot/lib/"
rsync -avz "$PI_HOST:/usr/include/" "$HOME/rpi-sysroot/usr/include/"
rsync -avz "$PI_HOST:/usr/lib/" "$HOME/rpi-sysroot/usr/lib/"
rsync -avz "$PI_HOST:/usr/share/pkgconfig/" \
  "$HOME/rpi-sysroot/usr/share/pkgconfig/"
```

Refresh the sysroot after a major Ubuntu upgrade or after changing important
runtime/development packages on the CM5.

### 4. Configure the ARM64 cross-build

Run on the **DEV PC**:

```bash
cd "$HOME/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE"

export QT_HOST_PATH="$HOME/Qt/6.10.1/gcc_64"
export PATH="$HOME/Qt/6.10.1/gcc_64/bin:$PATH"
export PKG_CONFIG_SYSROOT_DIR="$HOME/rpi-sysroot"
export PKG_CONFIG_LIBDIR="$HOME/rpi-sysroot/usr/lib/aarch64-linux-gnu/pkgconfig"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$HOME/rpi-sysroot/usr/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR:$HOME/rpi-sysroot/usr/share/pkgconfig"

"$HOME/Qt/6.10.1/gcc_arm64/bin/qt-cmake" \
  -S . \
  -B "$HOME/qgc-cross-build" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER=/usr/bin/aarch64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=/usr/bin/aarch64-linux-gnu-g++ \
  -DCMAKE_SYSROOT="$HOME/rpi-sysroot" \
  -DCMAKE_FIND_ROOT_PATH="$HOME/rpi-sysroot;$HOME/Qt/6.10.1/gcc_arm64" \
  -DQT_HOST_PATH="$HOME/Qt/6.10.1/gcc_64" \
  -DGStreamer_ROOT_DIR="$HOME/rpi-sysroot/usr" \
  -DQGC_BUILD_TESTING=OFF \
  -DQGC_CREATE_APPIMAGE=OFF
```

Configuration must finish with:

```text
Configuring done
Generating done
Build files have been written to: /home/shreeon-technologies/qgc-cross-build
```

Then follow the repeat-release workflow above.

### 5. Copy ARM64 Qt to the CM5 once

Run on the **DEV PC**:

```bash
ssh shreeoncm5@192.168.1.12 \
  'mkdir -p /home/shreeoncm5/Qt/6.10.1/gcc_arm64'

rsync -av --info=progress2 \
  "$HOME/Qt/6.10.1/gcc_arm64/" \
  "shreeoncm5@192.168.1.12:/home/shreeoncm5/Qt/6.10.1/gcc_arm64/"
```

Verify:

```bash
ssh shreeoncm5@192.168.1.12 \
  'test -d ~/Qt/6.10.1/gcc_arm64/lib && echo "Qt ready"'
```

## Running the AppImage

QGroundControl is graphical. Open a terminal from the Ubuntu desktop running on
the CM5 and execute:

```bash
unset QT_QPA_PLATFORM

QT_QPA_PLATFORM=xcb \
"$HOME/Videos/QGroundControl-aarch64.AppImage"
```

The terminal must have a display session:

```bash
echo "DISPLAY=$DISPLAY"
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
```

At least one value should be non-empty. A normal headless SSH shell cannot show
the QGC interface. Use the local desktop, VNC, Raspberry Pi Connect, or another
remote desktop when the CM5 is not connected to a monitor.

## Troubleshooting

### `Could not resolve hostname` during sysroot sync

`PI_HOST` is unset, or the sysroot commands were run on the CM5. Return to the
DEV PC and set it:

```bash
export PI_HOST="shreeoncm5@192.168.1.12"
echo "$PI_HOST"
ssh "$PI_HOST" 'uname -m'
```

The last command must print `aarch64`.

### `Qt not found at QT_ROOT=...`

Copy the ARM64 Qt directory from the DEV PC using the first-time setup command
above. Do not copy the `gcc_64` kit to the CM5.

### `qmake ... qemu-aarch64-static: not found`

The ARM64 Qt directory contains a qmake wrapper created for the DEV PC. Run the
following on the **CM5** to use the real native ARM64 qmake while preserving the
wrappers:

```bash
QT_BIN="$HOME/Qt/6.10.1/gcc_arm64/bin"

test -e "$QT_BIN/qmake.cross-host-wrapper" || \
  mv "$QT_BIN/qmake" "$QT_BIN/qmake.cross-host-wrapper"

test -e "$QT_BIN/qmake6.cross-host-wrapper" || \
  mv "$QT_BIN/qmake6" "$QT_BIN/qmake6.cross-host-wrapper"

ln -sfn qmake.real "$QT_BIN/qmake"
ln -sfn qmake6.real "$QT_BIN/qmake6"

"$QT_BIN/qmake" -query QT_VERSION
```

Expected Qt version: `6.10.1`.

### Missing `gst-plugins-good/ext/qt6/qt6glitem.h`

An interrupted dependency download can leave an incomplete generated cache.
Run on the **DEV PC**:

```bash
rm -rf \
  "$HOME/qgc-cross-build/cpm_modules/gstreamer_good_plugins" \
  "$HOME/qgc-cross-build/_deps/gstreamer_good_plugins-build" \
  "$HOME/qgc-cross-build/_deps/gstreamer_good_plugins-subbuild"
```

Rerun the ARM64 CMake configuration command.

### `mavlink_msg_target_field` or `mavlink_msg_get_target_system` is missing

The project must use a `libevents` revision compatible with its pinned MAVLink
revision. `src/MAVLink/LibEvents/CMakeLists.txt` pins the known-compatible
revision. Do not change it back to the moving `main` branch.

### Qt platform plugin `offscreen` cannot be initialized

The AppImage was launched without a graphical session. Launch it from a terminal
inside the CM5 Ubuntu desktop and force the bundled XCB backend:

```bash
QT_QPA_PLATFORM=xcb \
"$HOME/Videos/QGroundControl-aarch64.AppImage"
```

### No maximize button

The desktop window must not have equal minimum and maximum dimensions, and its
window flags must include `Qt.WindowMaximizeButtonHint`. The current
`src/UI/MainWindow.qml` configuration supports resizing and maximizing. Rebuild,
stage, sync, and package again after changing this file.

## Release checklist

- The build completed without an error.
- `file ~/qgc-cross-build/Release/QGroundControl` reports `ARM aarch64`.
- `cmake --install` refreshed `AppDir/usr/bin/QGroundControl`.
- The updated `AppDir` was synced to the CM5.
- Packaging printed `Success`.
- The new AppImage was installed in `~/Videos`.
- `sha256sum` was recorded for the release.
- QGC was tested from an active graphical desktop session.
