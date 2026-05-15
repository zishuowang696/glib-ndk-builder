#!/bin/bash
# build-glib.sh — Cross-compile GLib + dependencies (libffi, gettext) for Android aarch64
# Uses Android NDK Clang toolchain — target: aarch64-linux-android (API 21)
set -euo pipefail

# ============================================================
# Configuration
# ============================================================
NDK_VERSION="r28"
GLIB_VERSION="2.82.5"
LIBFFI_VERSION="3.4.7"
GETTEXT_VERSION="0.23.1"

TARGET_ARCH="aarch64"
TARGET_HOST="${TARGET_ARCH}-linux-android"
TARGET_API="21"
TARGET_TRIPLE="${TARGET_HOST}${TARGET_API}"

JOBS="$(nproc)"

# Directories
ROOT_DIR="$(pwd)"
SRC_DIR="${ROOT_DIR}/src"
PREFIX="${ROOT_DIR}/prefix"
BUILD_DIR="${ROOT_DIR}/build"
OUTPUT_DIR="${ROOT_DIR}/output"

NDK_ZIP="android-ndk-${NDK_VERSION}-linux.zip"
NDK_DIR="${ROOT_DIR}/android-ndk-${NDK_VERSION}"
TOOLCHAIN="${NDK_DIR}/toolchains/llvm/prebuilt/linux-x86_64"

# ============================================================
# Clean & prepare
# ============================================================
rm -rf "${SRC_DIR}" "${PREFIX}" "${BUILD_DIR}" "${OUTPUT_DIR}"
mkdir -p "${SRC_DIR}" "${PREFIX}" "${BUILD_DIR}" "${OUTPUT_DIR}"

# ============================================================
# Download NDK + source tarballs
# ============================================================
download() {
    local url="$1"
    local dest="$2"
    if [ ! -f "${dest}" ]; then
        echo "==> Downloading ${dest}..."
        wget -q --show-progress "${url}" -O "${dest}"
    else
        echo "==> ${dest} already exists, skipping download"
    fi
}

download "https://dl.google.com/android/repository/${NDK_ZIP}"          "${SRC_DIR}/${NDK_ZIP}"
download "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz" \
                                                                         "${SRC_DIR}/libffi-${LIBFFI_VERSION}.tar.gz"
download "https://ftp.gnu.org/pub/gnu/gettext/gettext-${GETTEXT_VERSION}.tar.gz" \
                                                                         "${SRC_DIR}/gettext-${GETTEXT_VERSION}.tar.gz"
download "https://download.gnome.org/sources/glib/${GLIB_VERSION%.*}/glib-${GLIB_VERSION}.tar.xz" \
                                                                         "${SRC_DIR}/glib-${GLIB_VERSION}.tar.xz"

# ============================================================
# Extract NDK
# ============================================================
echo "==> Extracting NDK..."
if [ ! -d "${NDK_DIR}" ]; then
    unzip -q "${SRC_DIR}/${NDK_ZIP}" -d "${ROOT_DIR}"
fi

export PATH="${TOOLCHAIN}/bin:${PATH}"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="${PREFIX}"

CC="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-clang"
CXX="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-clang++"
LD="${TOOLCHAIN}/bin/ld.lld"
AR="${TOOLCHAIN}/bin/llvm-ar"
RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
STRIP="${TOOLCHAIN}/bin/llvm-strip"
NM="${TOOLCHAIN}/bin/llvm-nm"
OBJCOPY="${TOOLCHAIN}/bin/llvm-objcopy"
READELF="${TOOLCHAIN}/bin/llvm-readelf"
AS="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-clang"

CFLAGS="-O2 -fPIC -DANDROID"
CXXFLAGS="-O2 -fPIC -DANDROID"
LDFLAGS="-L${PREFIX}/lib"

# ============================================================
# Build libffi
# ============================================================
echo ""
echo "========================================"
echo "Building libffi ${LIBFFI_VERSION}..."
echo "========================================"
cd "${BUILD_DIR}"
rm -rf "libffi-${LIBFFI_VERSION}"
tar xf "${SRC_DIR}/libffi-${LIBFFI_VERSION}.tar.gz"
cd "libffi-${LIBFFI_VERSION}"

./configure \
    --host="${TARGET_TRIPLE}" \
    --prefix="${PREFIX}" \
    --enable-shared \
    --disable-static \
    --disable-docs \
    CC="${CC}" \
    CXX="${CXX}" \
    LD="${LD}" \
    AR="${AR}" \
    RANLIB="${RANLIB}" \
    STRIP="${STRIP}" \
    NM="${NM}" \
    OBJCOPY="${OBJCOPY}" \
    READELF="${READELF}" \
    AS="${AS}" \
    CFLAGS="${CFLAGS}" \
    CXXFLAGS="${CXXFLAGS}" \
    LDFLAGS="${LDFLAGS}"

make -j"${JOBS}"
make install

# ============================================================
# Build gettext (libintl only — runtime subproject)
# ============================================================
echo ""
echo "========================================"
echo "Building gettext ${GETTEXT_VERSION} (libintl)..."
echo "========================================"
cd "${BUILD_DIR}"
rm -rf "gettext-${GETTEXT_VERSION}"
tar xf "${SRC_DIR}/gettext-${GETTEXT_VERSION}.tar.gz"
cd "gettext-${GETTEXT_VERSION}"

# Only build gettext-runtime (contains libintl)
cd gettext-runtime
./configure \
    --host="${TARGET_TRIPLE}" \
    --prefix="${PREFIX}" \
    --enable-shared \
    --disable-static \
    --disable-libasprintf \
    --disable-java \
    --disable-native-java \
    --disable-csharp \
    --disable-libstdcxx \
    CC="${CC}" \
    CXX="${CXX}" \
    LD="${LD}" \
    AR="${AR}" \
    RANLIB="${RANLIB}" \
    STRIP="${STRIP}" \
    NM="${NM}" \
    CFLAGS="${CFLAGS}" \
    CXXFLAGS="${CXXFLAGS}" \
    LDFLAGS="${LDFLAGS}"

make -j"${JOBS}"
make install

# ============================================================
# Build GLib
# ============================================================
echo ""
echo "========================================"
echo "Building GLib ${GLIB_VERSION}..."
echo "========================================"

# Write meson cross-compile file
cat > "${BUILD_DIR}/meson-cross-android.txt" << EOF
[binaries]
c = '${CC}'
cpp = '${CXX}'
ar = '${AR}'
strip = '${STRIP}'
pkgconfig = 'pkg-config'

[built-in options]
c_args = ['${CFLAGS}']
c_link_args = ['${LDFLAGS}']
cpp_args = ['${CXXFLAGS}']
cpp_link_args = ['${LDFLAGS}']

[host_machine]
system = 'android'
cpu_family = '${TARGET_ARCH}'
cpu = '${TARGET_ARCH}'
endian = 'little'
EOF

cd "${BUILD_DIR}"
rm -rf "glib-${GLIB_VERSION}"
tar xf "${SRC_DIR}/glib-${GLIB_VERSION}.tar.xz"
cd "glib-${GLIB_VERSION}"

# meson must be available on the system (install via pip if needed)
if ! command -v meson &>/dev/null; then
    echo "==> meson not found, installing via pip..."
    pip3 install --user meson ninja
    export PATH="${HOME}/.local/bin:${PATH}"
fi

# Clean meson build
rm -rf builddir

meson setup builddir \
    --cross-file "${BUILD_DIR}/meson-cross-android.txt" \
    --prefix="${PREFIX}" \
    --libdir=lib \
    --default-library=shared \
    -Diconv=auto \
    -Dlibmount=disabled \
    -Dman=false \
    -Dgtk_doc=false \
    -Dtests=false \
    -Dglib_assert=false \
    -Dglib_checks=false \
    -Dnls=auto

ninja -C builddir -j"${JOBS}"
ninja -C builddir install

# ============================================================
# Package
# ============================================================
echo ""
echo "========================================"
echo "Packaging..."
echo "========================================"
cd "${ROOT_DIR}"

OUTPUT_FILE="glib-${GLIB_VERSION}-${TARGET_HOST}.tar.gz"

# Remove libtool archives and pkgconfig from output
rm -f "${PREFIX}"/lib/*.la
# But keep .pc files so users can pkg-config against it

cd "${PREFIX}"
tar czf "${OUTPUT_DIR}/${OUTPUT_FILE}" \
    --transform="s|^./||" \
    .

echo ""
echo "========================================"
echo "Build complete!"
echo "Output: ${OUTPUT_DIR}/${OUTPUT_FILE}"
echo "========================================"
ls -lh "${OUTPUT_DIR}/${OUTPUT_FILE}"
