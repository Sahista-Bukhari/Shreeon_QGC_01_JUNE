#!/usr/bin/env bash
# Pinned AppImage packaging tool versions and SHA-256 digests.
# Sourced by package-appimage-cross-host.sh and package-appimage-on-pi.sh.
# Update digests when bumping versions (download + sha256sum).

# linuxdeploy 1-alpha-20251107-1
LINUXDEPLOY_VERSION="1-alpha-20251107-1"
LINUXDEPLOY_AARCH64_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/${LINUXDEPLOY_VERSION}/linuxdeploy-aarch64.AppImage"
LINUXDEPLOY_AARCH64_SHA256="620095110d693282b8ebeb244a95b5e911cf8f65f76c88b4b47d16ae6346fcff"

# linuxdeploy-plugin-qt 1-alpha-20250213-1
LINUXDEPLOY_PLUGIN_QT_VERSION="1-alpha-20250213-1"
LINUXDEPLOY_PLUGIN_QT_AARCH64_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/${LINUXDEPLOY_PLUGIN_QT_VERSION}/linuxdeploy-plugin-qt-aarch64.AppImage"
LINUXDEPLOY_PLUGIN_QT_AARCH64_SHA256="bf1c24aff6d749b5cf423afad6f15abd4440f81dec1aab95706b25f6667cdcf1"

# appimagetool 1.9.1
APPIMAGETOOL_VERSION="1.9.1"
APPIMAGETOOL_X86_64_URL="https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-x86_64.AppImage"
APPIMAGETOOL_X86_64_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
APPIMAGETOOL_AARCH64_URL="https://github.com/AppImage/appimagetool/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-aarch64.AppImage"
APPIMAGETOOL_AARCH64_SHA256="f0837e7448a0c1e4e650a93bb3e85802546e60654ef287576f46c71c126a9158"

# Download url -> dest and verify sha256 before marking executable.
# Re-downloads when the file is missing or the digest does not match.
download_verified_tool() {
  local url="$1"
  local dest="$2"
  local expected_sha256="$3"
  local actual=""

  if [[ -z "${expected_sha256}" || "${#expected_sha256}" -ne 64 ]]; then
    echo "Internal error: missing/invalid SHA-256 for $(basename "${dest}")" >&2
    return 1
  fi

  if [[ -f "${dest}" ]]; then
    actual="$(sha256sum "${dest}" | awk '{print $1}')"
    if [[ "${actual}" == "${expected_sha256}" ]]; then
      chmod +x "${dest}"
      return 0
    fi
    echo "Checksum mismatch for $(basename "${dest}") (got ${actual}, want ${expected_sha256}); re-downloading..." >&2
    rm -f "${dest}"
  fi

  echo "Downloading $(basename "${dest}") (pinned)..."
  local tmp="${dest}.partial.$$"
  if ! wget -q -O "${tmp}" "${url}"; then
    rm -f "${tmp}"
    echo "Failed to download ${url}" >&2
    return 1
  fi

  actual="$(sha256sum "${tmp}" | awk '{print $1}')"
  if [[ "${actual}" != "${expected_sha256}" ]]; then
    rm -f "${tmp}"
    echo "SHA-256 verification failed for $(basename "${dest}")" >&2
    echo "  expected: ${expected_sha256}" >&2
    echo "  actual:   ${actual}" >&2
    return 1
  fi

  mv -f "${tmp}" "${dest}"
  chmod +x "${dest}"
  echo "Verified $(basename "${dest}") SHA-256=${actual}"
}
