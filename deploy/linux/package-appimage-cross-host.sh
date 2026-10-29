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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=appimage-tool-pins.sh
source "${SCRIPT_DIR}/appimage-tool-pins.sh"
# shellcheck source=appimage-qt-plugin-filter.sh
source "${SCRIPT_DIR}/appimage-qt-plugin-filter.sh"

# Expand a leading ~/ even when the override was quoted (e.g. QGC_CROSS_BUILD='~/…'),
# so the shell did not perform tilde expansion before invoking this script.
# Prefer [[ ]] over case: case patterns undergo tilde expansion, which turns a
# "~/"* pattern into "$HOME/"* and then fails to match a literal "~/…" override.
expand_tilde() {
  local path="$1"
  if [[ "${path}" == "~" ]]; then
    printf '%s\n' "${HOME}"
  elif [[ "${path}" == "~/"* ]]; then
    printf '%s\n' "${HOME}/${path#"~/"}"
  else
    printf '%s\n' "${path}"
  fi
}

QGC_CROSS_BUILD="$(expand_tilde "${QGC_CROSS_BUILD:-${HOME}/qgc-cross-build}")"
QT_ROOT="$(expand_tilde "${QT_ROOT:-${HOME}/Qt/6.10.1/gcc_arm64}")"
RPI_SYSROOT="$(expand_tilde "${RPI_SYSROOT:-${HOME}/rpi-sysroot}")"
TOOLS_DIR="${QGC_CROSS_BUILD}/tools"
APPDIR="${QGC_CROSS_BUILD}/AppDir"
APPRUN="${QGC_CROSS_BUILD}/AppRun"
APPIMAGE_OUT="${QGC_CROSS_BUILD}/QGroundControl-aarch64.AppImage"

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

[[ -x "${APPDIR}/usr/bin/QGroundControl" ]] || die "Missing ${APPDIR}/usr/bin/QGroundControl — run: cmake --install ${QGC_CROSS_BUILD} --config Release"
[[ -f "${APPRUN}" ]] || die "Missing ${APPRUN}"
[[ -d "${QT_ROOT}/lib" ]] || die "Qt not found at QT_ROOT=${QT_ROOT}"

DESKTOP="${APPDIR}/usr/share/applications/org.mavlink.qgroundcontrol.desktop"
ICON="${APPDIR}/usr/share/icons/hicolor/256x256/apps/QGroundControl.png"
[[ -f "${DESKTOP}" ]] || die "Missing desktop file: ${DESKTOP}"
[[ -f "${ICON}" ]] || die "Missing icon: ${ICON}"

mkdir -p "${TOOLS_DIR}"
download_verified_tool "${LINUXDEPLOY_AARCH64_URL}" \
  "${TOOLS_DIR}/linuxdeploy-aarch64.AppImage" "${LINUXDEPLOY_AARCH64_SHA256}" \
  || die "Failed to fetch verified linuxdeploy"
download_verified_tool "${LINUXDEPLOY_PLUGIN_QT_AARCH64_URL}" \
  "${TOOLS_DIR}/linuxdeploy-plugin-qt-aarch64.AppImage" "${LINUXDEPLOY_PLUGIN_QT_AARCH64_SHA256}" \
  || die "Failed to fetch verified linuxdeploy-plugin-qt"
download_verified_tool "${APPIMAGETOOL_X86_64_URL}" \
  "${TOOLS_DIR}/appimagetool-x86_64.AppImage" "${APPIMAGETOOL_X86_64_SHA256}" \
  || die "Failed to fetch verified appimagetool"

# Quick binfmt check using the already-verified aarch64 linuxdeploy binary.
if ! APPIMAGE_EXTRACT_AND_RUN=1 "${TOOLS_DIR}/linuxdeploy-aarch64.AppImage" --version >/dev/null 2>&1; then
  die "aarch64 AppImage tools cannot run on this host. Install/register binfmt: sudo apt install qemu-user-static"
fi

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

# Point linuxdeploy-plugin-qt at a sqlite-only plugins tree; never modify QT_ROOT.
use_sqlite_only_qt_plugins "${QT_ROOT}" || die "Failed to stage sqlite-only Qt plugins"

# Bundle aarch64 pdftoppm from the Pi sysroot for User Manual PDF preview.
PDFTOPPM_SRC=""
for _cand in "${RPI_SYSROOT}/usr/bin/pdftoppm" "${RPI_SYSROOT}/bin/pdftoppm"; do
  if [[ -x "${_cand}" ]]; then
    PDFTOPPM_SRC="${_cand}"
    break
  fi
done
PDFTOPPM_APPDIR=""
if PDFTOPPM_APPDIR="$(bundle_pdftoppm_into_appdir "${APPDIR}" "${PDFTOPPM_SRC}")"; then
  :
else
  PDFTOPPM_APPDIR=""
fi

echo "Bundling Qt and libraries into AppDir..."
LINUXDEPLOY_ARGS=(
  --appdir "${APPDIR}"
  --executable "${APPDIR}/usr/bin/QGroundControl"
  --desktop-file "${DESKTOP}"
  --custom-apprun "${APPRUN}"
  --icon-file "${ICON}"
  --plugin qt
)
if [[ -n "${PDFTOPPM_APPDIR}" && -x "${PDFTOPPM_APPDIR}" ]]; then
  LINUXDEPLOY_ARGS+=(--executable "${PDFTOPPM_APPDIR}")
fi
"${TOOLS_DIR}/linuxdeploy-aarch64.AppImage" "${LINUXDEPLOY_ARGS[@]}"

strip_optional_sql_drivers_from_appdir "${APPDIR}"

echo "Creating AppImage..."
rm -f "${APPIMAGE_OUT}"
"${TOOLS_DIR}/appimagetool-x86_64.AppImage" --no-appstream "${APPDIR}" "${APPIMAGE_OUT}"
chmod +x "${APPIMAGE_OUT}"

echo "Success: ${APPIMAGE_OUT}"
