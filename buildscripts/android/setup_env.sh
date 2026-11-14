#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies
#
# Sets up the Android build environment for MuseScore Studio:
# host Qt (Linux) + Qt for Android + Android SDK/NDK.
#
# Environment inputs:
#   QT_VERSION      (default 6.10.0)
#   QT_HOST_DIR     (default /opt/Qt/host)
#   QT_ANDROID_DIR  (default /opt/Qt/android)
#   ANDROID_HOME    (default /opt/android)
#   ANDROID_NDK_VERSION (default 27.0.12077973)
#   ANDROID_PLATFORM    (default android-26)

set -euo pipefail

QT_VERSION="${QT_VERSION:-6.10.0}"
QT_HOST_DIR="${QT_HOST_DIR:-/opt/Qt/host}"
QT_ANDROID_DIR="${QT_ANDROID_DIR:-/opt/Qt/android}"
ANDROID_HOME="${ANDROID_HOME:-/opt/android}"
ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-27.0.12077973}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-26}"
QT_HOST_NAME="gcc_64"
QT_TAG="qt6_$(echo "${QT_VERSION}" | tr -d '.')"

echo "== Setting up Android build environment =="
echo "   Qt ${QT_VERSION}, NDK ${ANDROID_NDK_VERSION}, platform ${ANDROID_PLATFORM}"

# Fast path: a prebuilt bundle of the host and android Qt trees
# (e.g. a GitHub release asset), used when the Qt repositories are unreachable.
QT_BUNDLE_URL="${QT_BUNDLE_URL:-}"
if [ -n "${QT_BUNDLE_URL}" ] && { [ ! -x "${QT_HOST_DIR}/bin/qmake6" ] || [ ! -f "${QT_ANDROID_DIR}/lib/libQt6Core_arm64-v8a.so" ]; }; then
    echo "== Downloading Qt bundle =="
    mkdir -p /tmp/qt-bundle /opt/Qt
    curl -fL --retry 5 --retry-all-errors --max-time 1800 -o /tmp/qt-bundle/qt.tar.zst "${QT_BUNDLE_URL}" \
        || { echo "ERROR: failed to download the Qt bundle"; exit 1; }
    tar --zstd -xf /tmp/qt-bundle/qt.tar.zst -C /opt
fi

mkdir -p "${QT_HOST_DIR}" "${QT_ANDROID_DIR}" /tmp/qt-download
cd /tmp/qt-download

# The main Qt repository redirects to geographic mirrors which are not always
# reliable from CI hosts, so several mirrors are tried in turn.
QT_REPOS=(
    "https://download.qt.io/online/qtsdkrepository"
    "https://mirrors.ocf.berkeley.edu/qt/online/qtsdkrepository"
    "https://ftp.nluug.nl/languages/qt/online/qtsdkrepository"
    "https://qt.mirror.constant.com/online/qtsdkrepository"
)

fetch() {
    local path="$1" out="$2"
    if [ ! -s "${out}" ]; then
        echo "Downloading $(basename "${out}")"
        for base in "${QT_REPOS[@]}"; do
            if curl -fL --retry 3 --retry-all-errors --max-time 900 -o "${out}" "${base}/${path}"; then
                return 0
            fi
        done
        echo "ERROR: failed to download ${path}"; exit 1
    fi
}

listing() {
    local path="$1" body=""
    for base in "${QT_REPOS[@]}"; do
        if body=$(curl -fsSL --retry 3 --retry-all-errors --max-time 120 "${base}/${path}"); then
            echo "${body}"
            return 0
        fi
    done
    echo "ERROR: failed to fetch listing ${path}"; exit 1
}

extract() {
    python3 - "$1" "$2" <<'PYEOF'
import sys, py7zr
archive, dest = sys.argv[1], sys.argv[2]
with py7zr.SevenZipFile(archive) as z:
    z.extractall(dest)
PYEOF
}

# ---------------- Qt host (linux x86_64, provides build tools) ---------------
QT_HOST_REPO_PATH="linux_x64/desktop/${QT_TAG}/${QT_TAG}"
if [ ! -x "${QT_HOST_DIR}/bin/qmake6" ]; then
    echo "== Installing host Qt ${QT_VERSION} (${QT_HOST_NAME}) =="
    HOST_ARCHIVES=$(listing "${QT_HOST_REPO_PATH}/qt.qt6.${QT_TAG}.linux_gcc_64/" | grep -o 'href="[^"]*\.7z"' | sed 's/href="//;s/"//' | grep -v meta)
    for a in ${HOST_ARCHIVES}; do
        fetch "${QT_HOST_REPO_PATH}/qt.qt6.${QT_TAG}.linux_gcc_64/${a}" "$(basename "${a}")"
        extract "$(basename "${a}")" "${QT_HOST_DIR}"
    done
    # addons required by the app
    for addon in qt5compat qtshadertools; do
        ADDON_ARCHIVES=$(listing "${QT_HOST_REPO_PATH}/qt.qt6.${QT_TAG}.addons.${addon}.linux_gcc_64/" | grep -o 'href="[^"]*\.7z"' | sed 's/href="//;s/"//' | grep -v meta)
        for a in ${ADDON_ARCHIVES}; do
            fetch "${QT_HOST_REPO_PATH}/qt.qt6.${QT_TAG}.addons.${addon}.linux_gcc_64/${a}" "$(basename "${a}")"
            extract "$(basename "${a}")" "${QT_HOST_DIR}"
        done
    done
    # icu libs are shipped separately at the repo root
    ICU_ARCHIVE=$(listing "${QT_HOST_REPO_PATH}/qt.qt6.${QT_TAG}.linux_gcc_64/" | grep -o 'href="[^"]*icu[^"]*\.7z"' | sed 's/href="//;s/"//' | head -1)
    if [ -n "${ICU_ARCHIVE}" ]; then
        fetch "${QT_HOST_REPO_PATH}/qt.qt6.${QT_TAG}.linux_gcc_64/${ICU_ARCHIVE}" "$(basename "${ICU_ARCHIVE}")"
        extract "$(basename "${ICU_ARCHIVE}")" "${QT_HOST_DIR}"
        mv "${QT_HOST_DIR}"/libicu*.so* "${QT_HOST_DIR}/lib/" 2>/dev/null || true
    fi
fi

# ---------------- Qt for Android (arm64-v8a target libs) ---------------------
QT_ANDROID_REPO_PATH="all_os/android/${QT_TAG}/${QT_TAG}_arm64_v8a"
if [ ! -f "${QT_ANDROID_DIR}/lib/libQt6Core_arm64-v8a.so" ]; then
    echo "== Installing Qt for Android ${QT_VERSION} (arm64-v8a) =="
    AND_ARCHIVES=$(listing "${QT_ANDROID_REPO_PATH}/qt.qt6.${QT_TAG}.android_arm64_v8a/" | grep -o 'href="[^"]*\.7z"' | sed 's/href="//;s/"//' | grep -v meta)
    for a in ${AND_ARCHIVES}; do
        fetch "${QT_ANDROID_REPO_PATH}/qt.qt6.${QT_TAG}.android_arm64_v8a/${a}" "$(basename "${a}")"
        extract "$(basename "${a}")" "${QT_ANDROID_DIR}"
    done
    for addon in qt5compat qtshadertools; do
        ADDON_ARCHIVES=$(listing "${QT_ANDROID_REPO_PATH}/qt.qt6.${QT_TAG}.addons.${addon}.android_arm64_v8a/" | grep -o 'href="[^"]*\.7z"' | sed 's/href="//;s/"//' | grep -v meta)
        for a in ${ADDON_ARCHIVES}; do
            fetch "${QT_ANDROID_REPO_PATH}/qt.qt6.${QT_TAG}.addons.${addon}.android_arm64_v8a/${a}" "$(basename "${a}")"
            extract "$(basename "${a}")" "${QT_ANDROID_DIR}"
        done
    done
fi

# Patch the generated wrappers so they point at our host Qt and set rpath
find "${QT_ANDROID_DIR}/bin" -maxdepth 1 -type f \( -name "qmake6" -o -name "qtpaths6" \) -exec sed -i "s|/opt/Qt/${QT_VERSION}/gcc_64|${QT_HOST_DIR}|g" {} \; || true
find "${QT_ANDROID_DIR}/bin" -maxdepth 1 -type f -name "target_qt.conf" -exec sed -i "s|HostPrefix=.*|HostPrefix=${QT_HOST_DIR}|g; s|HostLibraryExecutables=.*|HostLibraryExecutables=${QT_HOST_DIR}/libexec|g; s|HostData=.*|HostData=${QT_ANDROID_DIR}|g" {} \; || true

# make sure host tools can load their shared libs
if command -v patchelf >/dev/null 2>&1; then
    for f in "${QT_HOST_DIR}/bin/"* "${QT_HOST_DIR}/libexec/"*; do
        if file "$f" 2>/dev/null | grep -q ELF; then
            patchelf --set-rpath '$ORIGIN/../lib' "$f" 2>/dev/null || true
        fi
    done
fi

# ---------------- Android SDK / NDK ------------------------------------------
"${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --sdk_root="${ANDROID_HOME}" "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;${ANDROID_NDK_VERSION}" > /dev/null

export ANDROID_HOME
export ANDROID_SDK_ROOT="${ANDROID_HOME}"
export ANDROID_NDK_ROOT="${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}"
export QT_HOST_PATH="${QT_HOST_DIR}"
export QT_ROOT_DIR="${QT_ANDROID_DIR}"
export PATH="${QT_HOST_DIR}/bin:${QT_ANDROID_DIR}/bin:${PATH}"

cat > /tmp/qt-android-env.sh <<ENVEOF
export ANDROID_HOME="${ANDROID_HOME}"
export ANDROID_SDK_ROOT="${ANDROID_HOME}"
export ANDROID_NDK_ROOT="${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}"
export QT_HOST_PATH="${QT_HOST_DIR}"
export QT_ROOT_DIR="${QT_ANDROID_DIR}"
export QT_HOST_DIR="${QT_HOST_DIR}"
export QT_ANDROID_DIR="${QT_ANDROID_DIR}"
export ANDROID_PLATFORM="${ANDROID_PLATFORM}"
export PATH="${QT_HOST_DIR}/bin:\${PATH}"
ENVEOF

echo "== Environment ready =="
echo "   host Qt:    ${QT_HOST_DIR}"
echo "   android Qt: ${QT_ANDROID_DIR}"
echo "   SDK:        ${ANDROID_HOME}"
echo "   NDK:        ${ANDROID_NDK_ROOT}"
