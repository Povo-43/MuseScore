# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies
#
# Copies QML module files to the Android package source directory so that
# androiddeployqt can resolve QML imports (Muse.Ui, Muse.UiComponents, etc.)
# at runtime.
#
# Usage (script mode):
#   cmake -DQML_DEST_DIR=<dest> -P CopyQmlModules.cmake

if (NOT DEFINED ENV{QML_DEST_DIR})
    message(FATAL_ERROR "QML_DEST_DIR not set")
endif()

set(QML_DEST_DIR "$ENV{QML_DEST_DIR}")

file(MAKE_DIRECTORY "${QML_DEST_DIR}")

# Get all build targets
get_property(_all_targets GLOBAL PROPERTY BUILDSYSTEM_TARGETS)

foreach(_target ${_all_targets})
    # Check if this target is a QML module
    get_property(_qml_uri TARGET ${_target} PROPERTY QML_MODULE_URI)
    if (NOT _qml_uri)
        continue()
    endif()

    get_property(_qml_version TARGET ${_target} PROPERTY QML_MODULE_VERSION)
    if (NOT _qml_version)
        set(_qml_version "1.0")
    endif()

    # Convert URI to path: Muse.Ui -> Muse/Ui
    string(REPLACE "." "/" _qml_path ${_qml_uri})

    # Get QML source files from target sources
    get_target_property(_sources ${_target} SOURCES)
    set(_qml_files "")
    foreach(_src ${_sources})
        if (_src MATCHES "\\.qml$")
            list(APPEND _qml_files ${_src})
        endif()
    endforeach()

    # Also check for generated qmldir in common build locations
    set(_qml_dir "")
    set(_search_dirs
        "${CMAKE_CURRENT_BINARY_DIR}/qml/${_qml_path}"
        "${CMAKE_CURRENT_BINARY_DIR}/${_target}_qml_autogen"
        "${CMAKE_CURRENT_BINARY_DIR}/${_target}_autogen"
    )
    foreach(_search_dir ${_search_dirs})
        if (EXISTS "${_search_dir}/qmldir")
            set(_qml_dir ${_search_dir})
            break()
        endif()
    endforeach()

    # Copy QML files
    set(_qmldir_entries "")
    foreach(_qml_file ${_qml_files})
        if (EXISTS "${_qml_file}")
            get_filename_component(_qml_name ${_qml_file} NAME)
            string(REGEX REPLACE "\\.qml$" "" _qml_type ${_qml_name})
            file(COPY ${_qml_file} DESTINATION "${QML_DEST_DIR}/${_qml_path}")
            list(APPEND _qmldir_entries "${_qml_type} ${_qml_name} 1.0")
        endif()
    endforeach()

    # Generate qmldir if we have QML files and didn't find a generated one
    if (_qml_files AND NOT _qml_dir)
        file(MAKE_DIRECTORY "${QML_DEST_DIR}/${_qml_path}")
        set(_qmldir_content "module ${_qml_uri}\n")
        foreach(_entry ${_qmldir_entries})
            string(APPEND _qmldir_content "${_entry}\n")
        endforeach()
        file(WRITE "${QML_DEST_DIR}/${_qml_path}/qmldir" "${_qmldir_content}")
        message(STATUS "[qml] Generated qmldir for ${_qml_uri} with ${_qml_files|length} types")
    elseif (_qml_dir)
        # Copy generated qmldir
        file(COPY "${_qml_dir}/qmldir" DESTINATION "${QML_DEST_DIR}/${_qml_path}")
        message(STATUS "[qml] Copied qmldir for ${_qml_uri}")
    endif()

    # Copy the plugin library if it exists (for C++ QML plugins)
    get_property(_plugin TARGET ${_target} PROPERTY QML_PLUGIN)
    if (_plugin AND TARGET ${_plugin})
        get_target_property(_plugin_type ${_plugin} TYPE)
        if (_plugin_type MATCHES "SHARED_LIBRARY|MODULE_LIBRARY")
            get_target_property(_plugin_location ${_plugin} LOCATION)
            if (_plugin_location AND EXISTS "${_plugin_location}")
                file(COPY "${_plugin_location}" DESTINATION "${QML_DEST_DIR}/${_qml_path}")
                message(STATUS "[qml] Copied plugin ${_plugin} for ${_qml_uri}")
            endif()
        endif()
    endif()
endforeach()

message(STATUS "[qml] QML module copy complete")
