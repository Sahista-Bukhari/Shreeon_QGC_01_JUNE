#!/usr/bin/env bash
# Sync a cross-compiled QGC tree from the dev host to a Raspberry Pi for AppImage packaging.
# Does not rebuild QGroundControl — only copies AppDir, AppRun, and QML deploy output.
#
# Usage:
#   PI_HOST=pi@192.168.1.7 ./deploy/linux/sync-cross-build-for-appimage.sh
#
# Optional environment:
#   QGC_CROSS_BUILD   (default: ~/qgc-cross-build)
#   PI_PACKAGE_DIR    (default: ~/qgc-package on the Pi)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PI_HOST="${PI_HOST:-}"
QGC_CROSS_BUILD="${QGC_CROSS_BUILD:-${HOME}/qgc-cross-build}"
PI_PACKAGE_DIR="${PI_PACKAGE_DIR:-~/qgc-package}"

if [[ -z "${PI_HOST}" ]]; then
    echo "Set PI_HOST, for example: PI_HOST=pi@192.168.1.7 $0" >&2
    exit 1
fi

for path in "${QGC_CROSS_BUILD}/AppDir" "${QGC_CROSS_BUILD}/AppRun" "${QGC_CROSS_BUILD}/Release/QGroundControl"; do
    if [[ ! -e "${path}" ]]; then
        echo "Missing cross-build artifact: ${path}" >&2
        echo "Build on the host first, for example:" >&2
        echo "  cmake --build ${QGC_CROSS_BUILD} --config Release" >&2
        exit 1
    fi
done

echo "Creating package layout on ${PI_HOST}..."
ssh "${PI_HOST}" "mkdir -p ${PI_PACKAGE_DIR}/AppDir/usr/bin ${PI_PACKAGE_DIR}/tools"

echo "Syncing AppDir..."
rsync -av --delete "${QGC_CROSS_BUILD}/AppDir/" "${PI_HOST}:${PI_PACKAGE_DIR}/AppDir/"

echo "Syncing AppRun..."
rsync -av "${QGC_CROSS_BUILD}/AppRun" "${PI_HOST}:${PI_PACKAGE_DIR}/"
ssh "${PI_HOST}" "chmod +x ${PI_PACKAGE_DIR}/AppRun"

if [[ -d "${QGC_CROSS_BUILD}/qml" ]]; then
    echo "Syncing deployed QML..."
    rsync -av "${QGC_CROSS_BUILD}/qml/" "${PI_HOST}:${PI_PACKAGE_DIR}/qml/"
fi

echo "Syncing AppImage packaging script..."
rsync -av "${SCRIPT_DIR}/package-appimage-on-pi.sh" "${PI_HOST}:${PI_PACKAGE_DIR}/"
ssh "${PI_HOST}" "chmod +x ${PI_PACKAGE_DIR}/package-appimage-on-pi.sh"

echo "Done. On the Pi, run:"
echo "  ${PI_PACKAGE_DIR}/package-appimage-on-pi.sh"
