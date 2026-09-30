#!/usr/bin/env bash
# Build QGroundControl-aarch64.AppImage on the cross-build host after install populated AppDir.
# Requires qemu-user-static (binfmt) so aarch64 linuxdeploy/AppImage tools can run on x86_64.
#
# Usage (Ubuntu 24.04 — do NOT install fuse/libfuse2; that conflicts with fuse3 and can remove GNOME):
#   sudo apt install qemu-user-static patchelf wget
#   QGC_CROSS_BUILD="$HOME/qgc-cross-build" "$HOME/qgc-cross-build/package-appimage-cross-host.sh"
#
# Environment:
#   QGC_CROSS_BUILD   default: ~/qgc-cross-build
#   QT_ROOT           default: ~/Qt/6.10.1/gcc_arm64
#   RPI_SYSROOT       default: ~/rpi-sysroot

set -euo pipefail

expand_tilde() {
  case "$1" in
    "~") echo "${HOME}" ;;
    "~/"*) echo "${HOME}/${1#~/}" ;;
    *) echo "$1" ;;
  esac
}

QGC_CROSS_BUILD="$(expand_tilde "${QGC_CROSS_BUILD:-${HOME}/qgc-cross-build}")"
QT_ROOT="$(expand_tilde "${QT_ROOT:-${HOME}/Qt/6.10.1/gcc_arm64}")"
RPI_SYSROOT="$(expand_tilde "${RPI_SYSROOT:-${HOME}/rpi-sysroot}")"
TOOLS_DIR="${QGC_CROSS_BUILD}/tools"
APPDIR="${QGC_CROSS_BUILD}/AppDir"
APPRUN="${QGC_CROSS_BUILD}/AppRun"
APPIMAGE_OUT="${QGC_CROSS_BUILD}/QGroundControl-aarch64.AppImage"

LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage"
PLUGIN_QT_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-aarch64.AppImage"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"

die() { echo "$*" >&2; exit 1; }

host_arch="$(uname -m)"
if [[ "${host_arch}" == "aarch64" ]]; then
  exec "$(dirname "$0")/package-appimage-on-pi.sh"
fi

if [[ "${host_arch}" != "x86_64" ]]; then
  die "Unsupported host architecture: ${host_arch} (expected x86_64 or aarch64)"
fi

if ! command -v patchelf >/dev/null; then
  die "patchelf not found — install with: sudo apt install patchelf"
fi

QEMU_AARCH64="${QEMU_AARCH64:-}"
if [[ -z "${QEMU_AARCH64}" ]]; then
  if command -v qemu-aarch64-static >/dev/null; then
    QEMU_AARCH64="$(command -v qemu-aarch64-static)"
  elif [[ -x "${TOOLS_DIR}/qemu-aarch64-static" ]]; then
    QEMU_AARCH64="${TOOLS_DIR}/qemu-aarch64-static"
  else
    die "qemu-aarch64-static not found — install with: sudo apt install qemu-user-static"
  fi
fi
export PATH="$(dirname "${QEMU_AARCH64}"):${PATH}"

# Quick binfmt check: aarch64 AppImage runtime must be executable on this host.
_test_appimage="/tmp/qgc-binfmt-test-$$.AppImage"
if wget -q -O "${_test_appimage}" "${LINUXDEPLOY_URL}"; then
  chmod +x "${_test_appimage}"
  if ! APPIMAGE_EXTRACT_AND_RUN=1 "${_test_appimage}" --version >/dev/null 2>&1; then
    rm -f "${_test_appimage}"
    die "aarch64 AppImage tools cannot run on this host. Install/register binfmt: sudo apt install qemu-user-static"
  fi
  rm -f "${_test_appimage}"
fi

[[ -x "${APPDIR}/usr/bin/QGroundControl" ]] || die "Missing ${APPDIR}/usr/bin/QGroundControl — run: cmake --install ${QGC_CROSS_BUILD} --config Release"
[[ -f "${APPRUN}" ]] || die "Missing ${APPRUN}"
[[ -d "${QT_ROOT}/lib" ]] || die "Qt not found at QT_ROOT=${QT_ROOT}"

DESKTOP="${APPDIR}/usr/share/applications/org.mavlink.qgroundcontrol.desktop"
ICON="${APPDIR}/usr/share/icons/hicolor/256x256/apps/QGroundControl.png"
[[ -f "${DESKTOP}" ]] || die "Missing desktop file: ${DESKTOP}"
[[ -f "${ICON}" ]] || die "Missing icon: ${ICON}"

mkdir -p "${TOOLS_DIR}"
download_tool() {
  local url="$1" dest="$2"
  if [[ ! -x "${dest}" ]]; then
    echo "Downloading $(basename "${dest}")..."
    wget -q -O "${dest}" "${url}"
    chmod +x "${dest}"
  fi
}

download_tool "${LINUXDEPLOY_URL}" "${TOOLS_DIR}/linuxdeploy-aarch64.AppImage"
download_tool "${PLUGIN_QT_URL}" "${TOOLS_DIR}/linuxdeploy-plugin-qt-aarch64.AppImage"
download_tool "${APPIMAGETOOL_URL}" "${TOOLS_DIR}/appimagetool-x86_64.AppImage"

chmod +x "${APPRUN}"

sys_gst="${RPI_SYSROOT}/usr/lib/aarch64-linux-gnu/gstreamer-1.0"
[[ -d "${sys_gst}" ]] || die "Missing sysroot GStreamer plugins: ${sys_gst}"
echo "Using GStreamer plugins from sysroot: ${sys_gst}"
rm -rf "${APPDIR}/usr/lib/gstreamer-1.0" "${APPDIR}/usr/lib/gstreamer1.0"
mkdir -p "${APPDIR}/usr/lib/gstreamer-1.0"
cp -a "${sys_gst}/." "${APPDIR}/usr/lib/gstreamer-1.0/"

if [[ -d "${QGC_CROSS_BUILD}/qml" ]]; then
  export QML_SOURCES_PATHS="${QGC_CROSS_BUILD}/qml"
fi

export PATH="${QT_ROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${QT_ROOT}/lib:${LD_LIBRARY_PATH:-}"
export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH=aarch64

SQL_DRIVER_DIR="${QT_ROOT}/plugins/sqldrivers"
if [[ -d "${SQL_DRIVER_DIR}" ]]; then
  echo "Removing optional Qt SQL drivers (keeping libqsqlite only)..."
  rm -f "${SQL_DRIVER_DIR}"/libqsqlmysql.so* \
        "${SQL_DRIVER_DIR}"/libqsqlpsql.so* \
        "${SQL_DRIVER_DIR}"/libqsqlodbc.so* \
        "${SQL_DRIVER_DIR}"/libqsqlmimer.so* \
        "${SQL_DRIVER_DIR}"/libqsqlibase.so* 2>/dev/null || true
fi

echo "Bundling Qt and libraries into AppDir..."
"${TOOLS_DIR}/linuxdeploy-aarch64.AppImage" \
  --appdir "${APPDIR}" \
  --executable "${APPDIR}/usr/bin/QGroundControl" \
  --desktop-file "${DESKTOP}" \
  --custom-apprun "${APPRUN}" \
  --icon-file "${ICON}" \
  --plugin qt

echo "Creating AppImage..."
rm -f "${APPIMAGE_OUT}"
"${TOOLS_DIR}/appimagetool-x86_64.AppImage" --no-appstream "${APPDIR}" "${APPIMAGE_OUT}"
chmod +x "${APPIMAGE_OUT}"

echo "Success: ${APPIMAGE_OUT}"
