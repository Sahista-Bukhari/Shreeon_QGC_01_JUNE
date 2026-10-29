#!/usr/bin/env bash
# Helpers for AppImage packaging: keep optional Qt SQL drivers out of AppDir
# without deleting anything from the installed Qt SDK (QT_ROOT).
#
# linuxdeploy-plugin-qt walks QT_INSTALL_PLUGINS/sqldrivers and pulls in DB
# client libs (libmysqlclient, libpq, …). QGroundControl only needs SQLite.

# Stage dir created by use_sqlite_only_qt_plugins; cleaned by cleanup_qt_plugin_filter.
QGC_QT_PLUGIN_FILTER_STAGE=""

cleanup_qt_plugin_filter() {
  if [[ -n "${QGC_QT_PLUGIN_FILTER_STAGE}" && -d "${QGC_QT_PLUGIN_FILTER_STAGE}" ]]; then
    rm -rf "${QGC_QT_PLUGIN_FILTER_STAGE}"
  fi
  QGC_QT_PLUGIN_FILTER_STAGE=""
}

# Build a plugins tree that mirrors QT_ROOT/plugins but keeps only libqsqlite in
# sqldrivers/, then point QMAKE at a wrapper so linuxdeploy-plugin-qt uses it.
# Requires QT_ROOT. Sets QMAKE and prepends the stage bin/ to PATH.
use_sqlite_only_qt_plugins() {
  local qt_root="${1:-${QT_ROOT:-}}"
  local real_qmake=""
  local stage=""
  local plugins_src=""
  local sqlite_src=""

  if [[ -z "${qt_root}" || ! -d "${qt_root}/plugins" ]]; then
    echo "use_sqlite_only_qt_plugins: Qt plugins not found under QT_ROOT=${qt_root}" >&2
    return 1
  fi

  real_qmake="${qt_root}/bin/qmake"
  if [[ ! -x "${real_qmake}" ]]; then
    real_qmake="$(command -v qmake || true)"
  fi
  if [[ -z "${real_qmake}" || ! -x "${real_qmake}" ]]; then
    echo "use_sqlite_only_qt_plugins: qmake not found" >&2
    return 1
  fi

  cleanup_qt_plugin_filter
  stage="$(mktemp -d "${TMPDIR:-/tmp}/qgc-qt-plugins.XXXXXX")"
  QGC_QT_PLUGIN_FILTER_STAGE="${stage}"
  trap cleanup_qt_plugin_filter EXIT

  plugins_src="${qt_root}/plugins"
  echo "Staging sqlite-only Qt plugins for packaging (SDK left intact)..."
  # Prefer hardlinks when possible so we do not duplicate the whole plugins tree.
  if ! cp -al "${plugins_src}" "${stage}/plugins" 2>/dev/null; then
    cp -a "${plugins_src}" "${stage}/plugins"
  fi

  # Drop optional SQL drivers from the *stage* only. Hardlinked names are unlinked
  # here; the originals under QT_ROOT remain.
  rm -rf "${stage}/plugins/sqldrivers"
  mkdir -p "${stage}/plugins/sqldrivers"
  shopt -s nullglob
  for sqlite_src in "${plugins_src}/sqldrivers"/libqsqlite.so*; do
    cp -a "${sqlite_src}" "${stage}/plugins/sqldrivers/"
  done
  shopt -u nullglob

  mkdir -p "${stage}/bin"
  cat > "${stage}/bin/qmake" <<EOF
#!/usr/bin/env bash
# Wrapper: report filtered plugins path; forward everything else to real qmake.
if [[ "\${1:-}" == "-query" && "\${2:-}" == "QT_INSTALL_PLUGINS" ]]; then
  printf '%s\\n' "${stage}/plugins"
  exit 0
fi
exec "${real_qmake}" "\$@"
EOF
  chmod +x "${stage}/bin/qmake"

  export QMAKE="${stage}/bin/qmake"
  export PATH="${stage}/bin:${PATH}"
}

# Remove optional SQL drivers from AppDir after bundling (never touches QT_ROOT).
strip_optional_sql_drivers_from_appdir() {
  local appdir="${1:-${APPDIR:-}}"
  local sql_dir="${appdir}/usr/plugins/sqldrivers"

  [[ -d "${sql_dir}" ]] || return 0

  echo "Excluding optional Qt SQL drivers from AppDir (keeping libqsqlite only)..."
  shopt -s nullglob
  rm -f "${sql_dir}"/libqsqlmysql.so* \
        "${sql_dir}"/libqsqlpsql.so* \
        "${sql_dir}"/libqsqlodbc.so* \
        "${sql_dir}"/libqsqlmimer.so* \
        "${sql_dir}"/libqsqlibase.so* \
        "${sql_dir}"/libqsqloci.so* 2>/dev/null || true
  shopt -u nullglob
}

# Copy pdftoppm into AppDir/usr/bin for User Manual PDF preview. Prints the
# installed path on success (for --executable), empty string if unavailable.
bundle_pdftoppm_into_appdir() {
  local appdir="${1:-${APPDIR:-}}"
  local source_bin="${2:-}"
  local dest="${appdir}/usr/bin/pdftoppm"

  if [[ -z "${source_bin}" || ! -x "${source_bin}" ]]; then
    echo "Warning: pdftoppm not found — User Manual preview needs poppler-utils in the AppImage or on the system." >&2
    return 1
  fi

  mkdir -p "${appdir}/usr/bin"
  cp -a "${source_bin}" "${dest}"
  chmod +x "${dest}"
  echo "Bundled pdftoppm from ${source_bin}" >&2
  printf '%s\n' "${dest}"
}
