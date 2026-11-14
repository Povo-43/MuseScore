# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies
#
# Packages the bundled application resources into the Android APK assets.
#
# Usage (script mode):
#   cmake -DSOURCE_DIR=<share source dir> -DBINARY_LOCALE_DIR=<built .qm dir>
#         -DQT_TRANSLATIONS_DIR=<qt translations> -DRES_LOCATION=share/mscore-4.x
#         -DASSETS_DIR=<package assets dir>
#         -P PrepareAssets.cmake

set(_assets_root "${ASSETS_DIR}/${RES_LOCATION}")

# Resources that are useful on mobile.
# Note: testflowscripts are development-only and are skipped.
set(_resource_dirs
    sound
    templates
    styles
    wallpapers
    manual
    workspaces
    plugins
    extensions
)

foreach(_dir ${_resource_dirs})
    if (IS_DIRECTORY "${SOURCE_DIR}/${_dir}")
        file(COPY "${SOURCE_DIR}/${_dir}" DESTINATION "${_assets_root}")
    endif()
endforeach()

# Braille tables (liblouis), passed as a list from the build configuration
if (TABLES)
    file(COPY ${TABLES} DESTINATION "${_assets_root}/tables")
endif()

# Translations: compiled .qm files from the build
if (EXISTS "${BINARY_LOCALE_DIR}")
    file(GLOB _qm_files "${BINARY_LOCALE_DIR}/*.qm")
    if (_qm_files)
        file(COPY ${_qm_files} DESTINATION "${_assets_root}/locale")
    endif()
endif()

# Qt's own translations used by the app
if (EXISTS "${QT_TRANSLATIONS_DIR}")
    file(GLOB _qt_qm_files
        "${QT_TRANSLATIONS_DIR}/qt_*.qm"
        "${QT_TRANSLATIONS_DIR}/qtbase_*.qm"
        "${QT_TRANSLATIONS_DIR}/qtmultimedia_*.qm"
    )
    if (_qt_qm_files)
        file(COPY ${_qt_qm_files} DESTINATION "${_assets_root}/locale")
    endif()
endif()

file(WRITE "${_assets_root}/SF_VERSION" "android-apk\n")

message(STATUS "Android assets prepared in: ${_assets_root}")
