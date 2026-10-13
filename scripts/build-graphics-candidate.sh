#!/usr/bin/env bash
# An explicit patched-library experiment; packaged binaries remain untouched.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
source scripts/rootfs-common.sh
rootfs_require cmake ninja git g++ aarch64-linux-gnu-g++ pkg-config patch
[[ -d $ROOTFS_TREE/usr/include/aquamarine ]] || rootfs_fail 'build the signed rootfs first'
mkdir -p src build/graphics-candidate artifacts/graphics-candidate logs
while read -r name url revision; do
    if [[ ! -d src/$name/.git ]]; then
        git init "src/$name"
        git -C "src/$name" remote add origin "$url"
    fi
    [[ -z $(git -C "src/$name" status --porcelain --untracked-files=no) ]] || rootfs_fail "dirty upstream: $name"
    git -C "src/$name" fetch --depth 1 origin "$revision"
    git -C "src/$name" checkout --detach "$revision"
done < config/graphics-build.lock
prefix="$PWD/build/graphics-candidate/native"
cmake -S src/hyprwayland-scanner -B build/graphics-candidate/scanner -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" > logs/graphics-scanner.log 2>&1
cmake --build build/graphics-candidate/scanner -j2 >> logs/graphics-scanner.log 2>&1
cmake --install build/graphics-candidate/scanner >> logs/graphics-scanner.log 2>&1
source_dir="$PWD/build/graphics-candidate/source"
rm -rf -- "$source_dir"
mkdir -p "$source_dir"
git -C src/aquamarine archive HEAD | tar -xf - -C "$source_dir"
patch -d "$source_dir" -p1 < config/aquamarine-gbm-fallback.patch
# pkg-config sysroots compiler flags, but not arbitrary pkgdatadir variables.
sed -i '/pkg_get_variable(WAYLAND_PROTOCOLS_DIR /a set(WAYLAND_PROTOCOLS_DIR "${CMAKE_SYSROOT}${WAYLAND_PROTOCOLS_DIR}")' "$source_dir/CMakeLists.txt"
sed -i '/pkg_get_variable(WAYLAND_SCANNER_PKGDATA_DIR /a set(WAYLAND_SCANNER_PKGDATA_DIR "${CMAKE_SYSROOT}${WAYLAND_SCANNER_PKGDATA_DIR}")' "$source_dir/CMakeLists.txt"
sed -i '/pkg_get_variable(HWDATA_DIR /a set(HWDATA_DIR "${CMAKE_SYSROOT}${HWDATA_DIR}")' "$source_dir/CMakeLists.txt"
cat > build/graphics-candidate/toolchain.cmake <<CONF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_SYSROOT "$ROOTFS_TREE")
set(CMAKE_FIND_ROOT_PATH "$ROOTFS_TREE")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
CONF
export PATH="$prefix/bin:$PATH"
export PKG_CONFIG_SYSROOT_DIR="$ROOTFS_TREE"
export PKG_CONFIG_LIBDIR="$ROOTFS_TREE/usr/lib/pkgconfig:$ROOTFS_TREE/usr/share/pkgconfig"
cmake -S "$source_dir" -B build/graphics-candidate/library -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$PWD/build/graphics-candidate/toolchain.cmake" \
    -Dhyprwayland-scanner_DIR="$prefix/lib/cmake/hyprwayland-scanner" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr > logs/graphics-candidate-config.log 2>&1
cmake --build build/graphics-candidate/library --target aquamarine -j2 > logs/graphics-candidate-build.log 2>&1
cp -a build/graphics-candidate/library/libaquamarine.so* artifacts/graphics-candidate/
cp src/aquamarine/LICENSE artifacts/graphics-candidate/LICENSE
cp config/graphics-build.lock config/aquamarine-gbm-fallback.patch artifacts/graphics-candidate/
sha256sum artifacts/graphics-candidate/libaquamarine.so.* config/graphics-build.lock config/aquamarine-gbm-fallback.patch > artifacts/graphics-candidate/SHA256SUMS
echo 'Separate Aquamarine GBM fallback candidate built; virtual and native scanout require validation.'
