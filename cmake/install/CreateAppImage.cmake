# ============================================================================
# CreateAppImage.cmake
# Creates AppImage packages for Linux distribution
# ============================================================================
#
# TODO: Implement go-appimage, update information with GitHub Releases, signing
#

if(NOT DEFINED QGC_APPIMAGE_BUILD_DIR OR QGC_APPIMAGE_BUILD_DIR STREQUAL "")
    message(FATAL_ERROR "QGC: QGC_APPIMAGE_BUILD_DIR must be set before including CreateAppImage.cmake")
endif()

message(STATUS "QGC: Creating AppImage...")
set(_qgc_appimage_build_dir "${QGC_APPIMAGE_BUILD_DIR}")

set(APPDIR_PATH "${_qgc_appimage_build_dir}/AppDir")
set(APPIMAGE_PATH "${_qgc_appimage_build_dir}/${CMAKE_PROJECT_NAME}-${CMAKE_SYSTEM_PROCESSOR}.AppImage")

# ============================================================================
# Helper Functions
# ============================================================================

# Download and cache build tools
function(download_tool VAR URL)
    cmake_path(GET URL FILENAME _name)
    set(_dest "${_qgc_appimage_build_dir}/tools/${_name}")
    if(NOT EXISTS "${_dest}")
        file(MAKE_DIRECTORY "${_qgc_appimage_build_dir}/tools")
        message(STATUS "QGC: Downloading ${_name} to ${_dest}")
        file(DOWNLOAD "${URL}" "${_dest}" STATUS _status)
        list(GET _status 0 _result)
        if(NOT _result EQUAL 0)
            message(FATAL_ERROR "Failed to download ${URL} to ${_dest}: ${_status}")
        endif()
        file(CHMOD "${_dest}" FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    endif()
    set(${VAR}_PATH "${_dest}" PARENT_SCOPE)
endfunction()

# ============================================================================
# Download Required Tools
# ============================================================================

message(STATUS "QGC: Downloading AppImage build tools...")

download_tool(LINUXDEPLOY https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${CMAKE_SYSTEM_PROCESSOR}.AppImage)
download_tool(APPIMAGETOOL https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${CMAKE_SYSTEM_PROCESSOR}.AppImage)

# AppImageLint is only available for x86_64
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64")
    download_tool(APPIMAGELINT https://github.com/TheAssassin/appimagelint/releases/download/continuous/appimagelint-${CMAKE_SYSTEM_PROCESSOR}.AppImage)
endif()

# ============================================================================
# Bundle Runtime Dependencies
# ============================================================================

message(STATUS "QGC: Bundling runtime dependencies with linuxdeploy...")

execute_process(
    COMMAND "${LINUXDEPLOY_PATH}"
            --appdir "${APPDIR_PATH}"
            --executable "${APPDIR_PATH}/usr/bin/${CMAKE_PROJECT_NAME}"
            --desktop-file "${APPDIR_PATH}/usr/share/applications/${QGC_PACKAGE_NAME}.desktop"
            --custom-apprun "${_qgc_appimage_build_dir}/AppRun"
            --icon-file "${APPDIR_PATH}/usr/share/icons/hicolor/256x256/apps/${CMAKE_PROJECT_NAME}.png"
    COMMAND_ECHO STDOUT
    COMMAND_ERROR_IS_FATAL ANY
)

# ============================================================================
# Build Final AppImage
# ============================================================================

message(STATUS "QGC: Building AppImage package...")

set(ENV{ARCH} ${CMAKE_SYSTEM_PROCESSOR})
set(ENV{VERSION} ${CMAKE_PROJECT_VERSION})

execute_process(
    COMMAND "${APPIMAGETOOL_PATH}" --no-appstream "${APPDIR_PATH}" "${APPIMAGE_PATH}"
    COMMAND_ECHO STDOUT
    COMMAND_ERROR_IS_FATAL ANY
)

message(STATUS "QGC: AppImage created successfully: ${APPIMAGE_PATH}")

# ============================================================================
# Validation & Linting
# ============================================================================

if(EXISTS "${APPIMAGELINT_PATH}")
    message(STATUS "QGC: Running AppImage linter...")
    execute_process(
        COMMAND "${APPIMAGELINT_PATH}" "${APPIMAGE_PATH}"
        RESULT_VARIABLE LINT_RESULT
        COMMAND_ECHO STDOUT
    )
    if(NOT LINT_RESULT EQUAL 0)
        message(WARNING "QGC: AppImageLint reported issues - see output above")
    else()
        message(STATUS "QGC: AppImage passed validation")
    endif()
else()
    message(STATUS "QGC: AppImageLint not available, skipping validation")
endif()
