#!/usr/bin/env bash
# Build QGroundControl-aarch64.AppImage on a Raspberry Pi from an existing cross-compiled binary.
# Run ON the Pi (aarch64). No QGC recompile — only linuxdeploy + appimagetool bundling.
#
# Prerequisites on the Pi:
#   - Qt 6.10.1 linux_gcc_arm64 (see docs/RASPBERRY_PI_CROSS_BUILD_AND_APPIMAGE.md)
#   - patchelf, fuse or libfuse2, wget
#   - Package tree from sync-cross-build-for-appimage.sh (~/qgc-package by default)
#
# Usage:
#   ~/qgc-package/package-appimage-on-pi.sh
#   QGC_PACKAGE_DIR=~/qgc-package QT_ROOT=~/Qt/6.10.1/gcc_arm64 ~/qgc-package/package-appimage-on-pi.sh

set -euo pipefail

QGC_PACKAGE_DIR="${QGC_PACKAGE_DIR:-${HOME}/qgc-package}"
QT_ROOT="${QT_ROOT:-${HOME}/Qt/6.10.1/gcc_arm64}"
TOOLS_DIR="${QGC_PACKAGE_DIR}/tools"
APPDIR="${QGC_PACKAGE_DIR}/AppDir"
APPRUN="${QGC_PACKAGE_DIR}/AppRun"
APPIMAGE_OUT="${QGC_PACKAGE_DIR}/QGroundControl-aarch64.AppImage"

LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-aarch64.AppImage"
PLUGIN_QT_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-aarch64.AppImage"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-aarch64.AppImage"

die() { echo "$*" >&2; exit 1; }

[[ -x "${APPDIR}/usr/bin/QGroundControl" ]] || die "Missing ${APPDIR}/usr/bin/QGroundControl — run sync-cross-build-for-appimage.sh from the host."
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
download_tool "${APPIMAGETOOL_URL}" "${TOOLS_DIR}/appimagetool-aarch64.AppImage"

chmod +x "${APPRUN}"

# Cross-install copies GStreamer plugins from the host sysroot. They often miss Pi libraries
# (libxml2, opencore-amr, …) and break linuxdeploy. Replace with plugins from this Pi.
apt_pkg_installable() {
    apt-cache show "$1" >/dev/null 2>&1
}

if [[ "${SKIP_APT_GST_DEPS:-0}" != "1" ]] && command -v apt-get >/dev/null; then
    echo "Installing GStreamer on the Pi (for bundling into AppImage)..."
    sudo apt-get update -qq
    gst_pkgs=(
        libopencore-amrwb0 libopencore-amrnb0
        gstreamer1.0-plugins-base gstreamer1.0-plugins-good
        gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly
        gstreamer1.0-gl gstreamer1.0-libav
        libgstreamer1.0-0 libgstreamer-plugins-base1.0-0
        libgstreamer-plugins-good1.0-0 libgstreamer-plugins-bad1.0-0
    )
    # Ubuntu arm64 may use libxml2t64 instead of libxml2; GStreamer plugins pull XML in anyway.
    for xml_pkg in libxml2-16 libxml2 libxml2t64; do
        if apt_pkg_installable "${xml_pkg}"; then
            gst_pkgs+=("${xml_pkg}")
            break
        fi
    done
    installable=()
    for pkg in "${gst_pkgs[@]}"; do
        if apt_pkg_installable "${pkg}"; then
            installable+=("${pkg}")
        else
            echo "Note: apt package not available, skipping: ${pkg}"
        fi
    done
    sudo apt-get install -y --no-install-recommends "${installable[@]}"
fi

refresh_gstreamer_plugins_from_system() {
    local sys_dir=""
    for d in /usr/lib/aarch64-linux-gnu/gstreamer-1.0 \
             /usr/lib/gstreamer-1.0; do
        if [[ -d "${d}" ]] && compgen -G "${d}/libgst*.so" >/dev/null; then
            sys_dir="${d}"
            break
        fi
    done
    [[ -n "${sys_dir}" ]] || die "No GStreamer plugins on Pi — install gstreamer1.0-plugins-* packages."

    echo "Replacing AppDir GStreamer plugins with Pi system plugins from ${sys_dir}..."
    rm -rf "${APPDIR}/usr/lib/gstreamer-1.0" "${APPDIR}/usr/lib/gstreamer1.0"
    mkdir -p "${APPDIR}/usr/lib/gstreamer-1.0"
    cp -a "${sys_dir}/." "${APPDIR}/usr/lib/gstreamer-1.0/"

    # Bundle gst-plugin-scanner (AppRun expects this path).
    local scanner=""
    for cand in \
        /usr/lib/aarch64-linux-gnu/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner \
        /usr/lib/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner; do
        if [[ -x "${cand}" ]]; then
            scanner="${cand}"
            break
        fi
    done
    if [[ -n "${scanner}" ]]; then
        mkdir -p "${APPDIR}/usr/lib/gstreamer1.0/gstreamer-1.0"
        cp -a "${scanner}" "${APPDIR}/usr/lib/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner"
        chmod +x "${APPDIR}/usr/lib/gstreamer1.0/gstreamer-1.0/gst-plugin-scanner"
    else
        echo "Warning: gst-plugin-scanner not found on system; video plugin scan may warn." >&2
    fi
}

refresh_gstreamer_plugins_from_system

if [[ -d "${QGC_PACKAGE_DIR}/qml" ]]; then
    export QML_SOURCES_PATHS="${QGC_PACKAGE_DIR}/qml"
elif [[ -d "${HOME}/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE/src" ]]; then
    export QML_SOURCES_PATHS="${HOME}/shreeon_Tech_V1/Shreeon_QGC_01_JUNE/Shreeon_QGC_01_JUNE/src"
fi

export PATH="${QT_ROOT}/bin:${PATH}"
export LD_LIBRARY_PATH="${QT_ROOT}/lib:${LD_LIBRARY_PATH:-}"
export APPIMAGE_EXTRACT_AND_RUN=1
export ARCH=aarch64
# Ensure linuxdeploy-plugin-qt pulls Quick3D (required by FlyView / Viewer3D).
export EXTRA_QT_MODULES="${EXTRA_QT_MODULES:+${EXTRA_QT_MODULES};}quick3d;shadertools"

# linuxdeploy-plugin-qt walks all Qt plugins. Optional SQL drivers pull DB client libs
# (libmysqlclient, libpq, …). QGroundControl uses SQLite only (libqsqlite).
SQL_DRIVER_DIR="${QT_ROOT}/plugins/sqldrivers"
if [[ -d "${SQL_DRIVER_DIR}" ]]; then
    echo "Removing optional Qt SQL drivers (keeping libqsqlite only)..."
    shopt -s nullglob
    rm -f "${SQL_DRIVER_DIR}"/libqsqlmysql.so* \
          "${SQL_DRIVER_DIR}"/libqsqlpsql.so* \
          "${SQL_DRIVER_DIR}"/libqsqlodbc.so* \
          "${SQL_DRIVER_DIR}"/libqsqlmimer.so* \
          "${SQL_DRIVER_DIR}"/libqsqlibase.so* 2>/dev/null || true
    shopt -u nullglob
fi

echo "Bundling Qt and libraries into AppDir..."
"${TOOLS_DIR}/linuxdeploy-aarch64.AppImage" \
    --appdir "${APPDIR}" \
    --executable "${APPDIR}/usr/bin/QGroundControl" \
    --desktop-file "${DESKTOP}" \
    --custom-apprun "${APPRUN}" \
    --icon-file "${ICON}" \
    --plugin qt

# linuxdeploy sometimes misses Quick3D QML; copy from QT_ROOT if needed.
if [[ ! -e "${APPDIR}/usr/qml/QtQuick3D/libqquick3dplugin.so" && -d "${QT_ROOT}/qml/QtQuick3D" ]]; then
    echo "Copying QtQuick3D QML module into AppDir..."
    mkdir -p "${APPDIR}/usr/qml"
    cp -a "${QT_ROOT}/qml/QtQuick3D" "${APPDIR}/usr/qml/"
    shopt -s nullglob
    cp -a "${QT_ROOT}/lib"/libQt6Quick3D*.so* "${APPDIR}/usr/lib/" 2>/dev/null || true
    cp -a "${QT_ROOT}/lib"/libQt6ShaderTools*.so* "${APPDIR}/usr/lib/" 2>/dev/null || true
    shopt -u nullglob
fi

# Re-assert scanner / plugins after linuxdeploy may have rearranged paths.
refresh_gstreamer_plugins_from_system

# Pi FFmpeg (libav) often mismatches and can SIGILL inside AppImages. Drop after
# the final plugin refresh so they are not re-copied from the system.
# libgstgio.so has also been observed to SIGSEGV on Ubuntu/CM5 during registry load.
echo "Removing bundled libav / gst-libav / gstgio to avoid Pi ABI / crash issues..."
rm -f "${APPDIR}/usr/lib/gstreamer-1.0"/libgstlibav.so* \
      "${APPDIR}/usr/lib/gstreamer-1.0"/libgstgio.so* \
      "${APPDIR}/usr/lib"/libavcodec.so* \
      "${APPDIR}/usr/lib"/libavformat.so* \
      "${APPDIR}/usr/lib"/libavutil.so* \
      "${APPDIR}/usr/lib"/libavfilter.so* \
      "${APPDIR}/usr/lib"/libswscale.so* \
      "${APPDIR}/usr/lib"/libswresample.so* 2>/dev/null || true

echo "Creating AppImage..."
rm -f "${APPIMAGE_OUT}"
# Upstream appdata may reference dead screenshot URLs; --no-appstream skips strict validation.
"${TOOLS_DIR}/appimagetool-aarch64.AppImage" --no-appstream "${APPDIR}" "${APPIMAGE_OUT}"
chmod +x "${APPIMAGE_OUT}"

echo "Success: ${APPIMAGE_OUT}"
echo "Run on the Pi desktop (not plain headless SSH):"
echo "  ${APPIMAGE_OUT}"
