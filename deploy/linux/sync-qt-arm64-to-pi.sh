#!/usr/bin/env bash
# Copy Qt 6.10.1 gcc_arm64 from the dev host to the Pi (for AppImage packaging).
# Use this when aqtinstall fails on the Pi (IncompleteRead / slow network).
#
# Usage:
#   PI_HOST=shreeoncm5@192.168.1.12 ./deploy/linux/sync-qt-arm64-to-pi.sh

set -euo pipefail

PI_HOST="${PI_HOST:-}"
QT_ARM64="${QT_ARM64:-${HOME}/Qt/6.10.1/gcc_arm64}"

if [[ -z "${PI_HOST}" ]]; then
    echo "Set PI_HOST, for example: PI_HOST=shreeoncm5@192.168.1.12 $0" >&2
    exit 1
fi

if [[ ! -d "${QT_ARM64}/lib" ]]; then
    echo "Missing Qt ARM64 kit at ${QT_ARM64}" >&2
    echo "On the host, install with aqt:" >&2
    echo "  aqt install-qt linux_arm64 desktop 6.10.1 linux_gcc_arm64 --outputdir \"\$HOME/Qt\" -m ..." >&2
    exit 1
fi

echo "Syncing Qt (~2 GB) to ${PI_HOST}:~/Qt/6.10.1/gcc_arm64/ ..."
ssh "${PI_HOST}" "mkdir -p ~/Qt/6.10.1"

rsync -av --partial --info=progress2 \
    "${QT_ARM64}/" \
    "${PI_HOST}:~/Qt/6.10.1/gcc_arm64/"

echo "Done. On the Pi, verify:"
echo "  ls ~/Qt/6.10.1/gcc_arm64/lib/libQt6Multimedia.so.6"
echo "Then run: QT_ROOT=~/Qt/6.10.1/gcc_arm64 ~/qgc-package/package-appimage-on-pi.sh"
