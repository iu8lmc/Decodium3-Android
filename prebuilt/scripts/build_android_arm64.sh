#!/bin/bash
# ============================================================================
# build_android_arm64.sh
# Cross-compile wsjt_fort + FFTW3 for Android ARM64 (aarch64)
#
# Runs in: WSL2 Ubuntu, native Linux, or Docker container
#
# Prerequisites (auto-installed if missing):
#   - gfortran-aarch64-linux-gnu  (Fortran cross-compiler)
#   - gcc-aarch64-linux-gnu       (C cross-compiler, fallback)
#   - g++-aarch64-linux-gnu       (C++ cross-compiler for crc*.cpp)
#   - libboost-dev                (Boost headers for crc14.cpp)
#   - wget, make, ar
#
# Usage:
#   ./build_android_arm64.sh [--ndk-path /path/to/ndk] [--source /path/to/Decodium3]
#
# Output: prebuilt/android-arm64-v8a/{libwsjt_fort.a, libfftw3f.a, libgfortran.a, libquadmath.a}
# ============================================================================

set -euo pipefail

# ── Configuration ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SOURCE="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANDROID_API=24
ARCH=aarch64
ABI=arm64-v8a
FFTW_VERSION=3.3.10
FFTW_URL="http://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz"
JOBS=$(nproc 2>/dev/null || echo 4)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }

# ── Parse arguments ──
SOURCE_DIR="$DEFAULT_SOURCE"
NDK_PATH=""
SKIP_DEPS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ndk-path)   NDK_PATH="$2"; shift 2 ;;
        --source)     SOURCE_DIR="$2"; shift 2 ;;
        --skip-deps)  SKIP_DEPS=1; shift ;;
        --jobs|-j)    JOBS="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--ndk-path PATH] [--source PATH] [--skip-deps] [--jobs N]"
            exit 0 ;;
        *)            err "Unknown option: $1"; exit 1 ;;
    esac
done

BUILD_DIR="${SOURCE_DIR}/prebuilt/build-${ABI}"
OUTPUT_DIR="${SOURCE_DIR}/prebuilt/android-${ABI}"
FFTW_BUILD_DIR="${BUILD_DIR}/fftw3"
FORT_BUILD_DIR="${BUILD_DIR}/wsjt_fort"

log "============================================"
log " Decodium3 Android ARM64 Cross-Compilation"
log "============================================"
info "Source:  ${SOURCE_DIR}"
info "Output:  ${OUTPUT_DIR}"
info "Jobs:    ${JOBS}"
echo ""

# ============================================================================
# Step 0: Install prerequisites
# ============================================================================
install_prerequisites() {
    log "Step 0: Checking prerequisites..."

    local PACKAGES=()

    command -v aarch64-linux-gnu-gfortran >/dev/null 2>&1 || PACKAGES+=(gfortran-aarch64-linux-gnu)
    command -v aarch64-linux-gnu-gcc      >/dev/null 2>&1 || PACKAGES+=(gcc-aarch64-linux-gnu)
    command -v aarch64-linux-gnu-g++      >/dev/null 2>&1 || PACKAGES+=(g++-aarch64-linux-gnu)
    command -v aarch64-linux-gnu-ar       >/dev/null 2>&1 || PACKAGES+=(binutils-aarch64-linux-gnu)
    command -v wget                       >/dev/null 2>&1 || PACKAGES+=(wget)
    command -v make                       >/dev/null 2>&1 || PACKAGES+=(make)

    # Check for Boost headers
    if ! dpkg -s libboost-dev >/dev/null 2>&1; then
        PACKAGES+=(libboost-dev)
    fi

    if [[ ${#PACKAGES[@]} -gt 0 ]]; then
        log "Installing: ${PACKAGES[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${PACKAGES[@]}"
    else
        log "All prerequisites already installed"
    fi

    # Verify critical tools
    for tool in aarch64-linux-gnu-gfortran aarch64-linux-gnu-gcc aarch64-linux-gnu-g++ aarch64-linux-gnu-ar; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            err "Required tool not found: $tool"
            exit 1
        fi
    done

    # Show versions
    info "gfortran: $(aarch64-linux-gnu-gfortran --version | head -1)"
    info "gcc:      $(aarch64-linux-gnu-gcc --version | head -1)"
    info "g++:      $(aarch64-linux-gnu-g++ --version | head -1)"
}

# ============================================================================
# Step 1: Cross-compile FFTW3 (single precision + threads)
# ============================================================================
build_fftw3() {
    log "Step 1: Cross-compiling FFTW3 ${FFTW_VERSION} for ${ABI}..."

    if [[ -f "${OUTPUT_DIR}/libfftw3f.a" ]]; then
        warn "FFTW3 already built, skipping (delete to rebuild)"
        return
    fi

    mkdir -p "${FFTW_BUILD_DIR}"
    cd "${FFTW_BUILD_DIR}"

    # Download if needed
    if [[ ! -f "fftw-${FFTW_VERSION}.tar.gz" ]]; then
        log "Downloading FFTW3..."
        wget -q "${FFTW_URL}" -O "fftw-${FFTW_VERSION}.tar.gz"
    fi

    # Extract
    if [[ ! -d "fftw-${FFTW_VERSION}" ]]; then
        tar xzf "fftw-${FFTW_VERSION}.tar.gz"
    fi

    cd "fftw-${FFTW_VERSION}"

    # Determine C compiler: prefer NDK Clang, fallback to cross-gcc
    local CC_CROSS
    local EXTRA_CFLAGS=""
    if [[ -n "$NDK_PATH" ]] && [[ -d "$NDK_PATH" ]]; then
        local NDK_TOOLCHAIN="${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64"
        CC_CROSS="${NDK_TOOLCHAIN}/bin/aarch64-linux-android${ANDROID_API}-clang"
        if [[ ! -f "$CC_CROSS" ]]; then
            warn "NDK Clang not found at $CC_CROSS, using cross-gcc"
            CC_CROSS="aarch64-linux-gnu-gcc"
        fi
    else
        CC_CROSS="aarch64-linux-gnu-gcc"
    fi
    EXTRA_CFLAGS="-fPIC -O2"

    log "Building FFTW3 with: $CC_CROSS"

    # Configure for single precision + threads
    ./configure \
        --host=aarch64-linux-gnu \
        --prefix="${FFTW_BUILD_DIR}/install" \
        --enable-single \
        --enable-threads \
        --enable-static \
        --disable-shared \
        --disable-fortran \
        --with-pic \
        CC="$CC_CROSS" \
        CFLAGS="$EXTRA_CFLAGS"

    make -j"${JOBS}" clean 2>/dev/null || true
    make -j"${JOBS}"
    make install

    # Copy output
    cp "${FFTW_BUILD_DIR}/install/lib/libfftw3f.a" "${OUTPUT_DIR}/"
    cp "${FFTW_BUILD_DIR}/install/lib/libfftw3f_threads.a" "${OUTPUT_DIR}/" 2>/dev/null || true

    log "FFTW3 built: ${OUTPUT_DIR}/libfftw3f.a"
}

# ============================================================================
# Step 2: Collect Fortran source files (mirroring CMakeLists.txt logic)
# ============================================================================
collect_fortran_sources() {
    log "Step 2: Collecting Fortran source files..."

    local LIB_DIR="${SOURCE_DIR}/lib"
    local SOURCES=()

    # ── Glob all .f90 from each directory ──
    local dirs=(
        "$LIB_DIR"
        "$LIB_DIR/ft2"
        "$LIB_DIR/ft4"
        "$LIB_DIR/ft8"
        "$LIB_DIR/fst4"
        "$LIB_DIR/77bit"
        "$LIB_DIR/ft8var"
        "$LIB_DIR/ftrsd"
        "$LIB_DIR/superfox"
        "$LIB_DIR/superfox/qpc"
        "$LIB_DIR/qso50"
        "$LIB_DIR/wsprcode"
        "$LIB_DIR/qra/q65"
        "$LIB_DIR/wsprd"
    )

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            for f in "$dir"/*.f90; do
                [[ -f "$f" ]] && SOURCES+=("$f")
            done
        fi
    done

    # ── Exclude patterns (matching CMakeLists.txt) ──

    # Files containing 'program' statement (standalone executables)
    local EXCLUDE_PATTERNS=(
        '[Ss]im'           # all sim files
        'test'             # all test files
        'allsim'
        'chkfft'
        'calibrate'
        'ldpcsim'
    )

    # Named standalone programs
    local EXCLUDE_NAMES=(
        allcall jt9 map65 cablog code426 contest72 count4
        EchoCallSim emedop fcal fer65 fersum fixwav fmtave genmet
        jt4code jt65 jt65code jt9code jt9w msk144code mskber
        psk_parse rtty_spec q65params qra64code stats timefft
        ft2 ft4code ft8code ft8d chkdec twq q65code sfrx sftx
        wsprcode WSPRcode genmet t2 bodide mfsk prob
        encode77 call_to_c28 hash22calc nonstd_to_c58 test28 free_text
    )

    # Include/data files (not compilable standalone)
    local EXCLUDE_INCLUDES=(
        constants conv232 fftw3 fil61 fmeasure jt4a jt9com jt9sync
        pfx prcom testmsg wqdecode avg4 msk144_testmsg
        ldpc_128_90_b_generator ldpc_128_90_b_reordered_parity
        ldpc_128_90_generator ldpc_128_90_reordered_parity
        sfrsd fst280_decode
        ft2_params gcom1 cdatetime
        ft4_params ft4_testmsg
        ft8_params ft8_testmsg h1
        ldpc_174_87_params ldpc_174_91_c_colorder
        ldpc_174_91_c_generator ldpc_174_91_c_parity
        ldpc_174_91_c_reordered_parity
        baddatavar call_q callsign_q syncdist
        fst4_params
        gtag
        ldpc_240_101_generator ldpc_240_101_parity
        ldpc_240_74_generator ldpc_240_74_parity
        wspr_params
    )

    # Apply exclusions
    local FILTERED=()
    for src in "${SOURCES[@]}"; do
        local basename=$(basename "$src" .f90)
        local skip=0

        # Check pattern exclusions
        for pat in "${EXCLUDE_PATTERNS[@]}"; do
            if [[ "$basename" =~ $pat ]]; then
                skip=1
                break
            fi
        done

        # Check named exclusions
        if [[ $skip -eq 0 ]]; then
            for name in "${EXCLUDE_NAMES[@]}"; do
                if [[ "$basename" == "$name" ]]; then
                    skip=1
                    break
                fi
            done
        fi

        # Check include exclusions
        if [[ $skip -eq 0 ]]; then
            for name in "${EXCLUDE_INCLUDES[@]}"; do
                if [[ "$basename" == "$name" ]]; then
                    skip=1
                    break
                fi
            done
        fi

        [[ $skip -eq 0 ]] && FILTERED+=("$src")
    done

    # Also check for 'program' statement in remaining files
    local FINAL=()
    for src in "${FILTERED[@]}"; do
        if grep -qi '^\s*program\s' "$src" 2>/dev/null; then
            warn "Excluding standalone program: $(basename "$src")"
        else
            FINAL+=("$src")
        fi
    done

    FORT_SOURCES=("${FINAL[@]}")
    info "Found ${#FORT_SOURCES[@]} Fortran source files to compile"
}

# ============================================================================
# Step 3: Collect C source files
# ============================================================================
collect_c_sources() {
    log "Step 3: Collecting C source files..."

    local LIB_DIR="${SOURCE_DIR}/lib"
    C_SOURCES=()
    CXX_SOURCES=()

    # C files from lib/
    for f in "$LIB_DIR"/*.c; do
        [[ -f "$f" ]] || continue
        local bn=$(basename "$f")
        # Exclude sim, test, standalone
        case "$bn" in
            *sim*|*test*|tstrig.c|ptt.c|rig_control.c) continue ;;
        esac
        C_SOURCES+=("$f")
    done

    # C files from subdirectories
    local c_subdirs=(
        "$LIB_DIR/qra/q65"
        "$LIB_DIR/qra/qracodes"
        "$LIB_DIR/wsprd"
        "$LIB_DIR/superfox/qpc"
    )
    for dir in "${c_subdirs[@]}"; do
        if [[ -d "$dir" ]]; then
            for f in "$dir"/*.c; do
                [[ -f "$f" ]] || continue
                local bn=$(basename "$f")
                case "$bn" in
                    *sim*|*test*|main.c|normrnd.c|npfwht.c|pdmath.c|qracodes.c) continue ;;
                    wsprd.c|gran.c|tab.c|WSPRcode.c) continue ;;
                esac
                C_SOURCES+=("$f")
            done
        fi
    done

    # C++ files (crc*.cpp need Boost headers)
    CXX_SOURCES+=("$LIB_DIR/crc14.cpp")
    [[ -f "$LIB_DIR/crc10.cpp" ]] && CXX_SOURCES+=("$LIB_DIR/crc10.cpp")
    [[ -f "$LIB_DIR/crc13.cpp" ]] && CXX_SOURCES+=("$LIB_DIR/crc13.cpp")

    info "Found ${#C_SOURCES[@]} C files and ${#CXX_SOURCES[@]} C++ files"
}

# ============================================================================
# Step 4: Cross-compile Fortran sources
# ============================================================================
compile_fortran() {
    log "Step 4: Cross-compiling ${#FORT_SOURCES[@]} Fortran files..."

    mkdir -p "${FORT_BUILD_DIR}/obj"

    local FC="aarch64-linux-gnu-gfortran"
    local FFLAGS="-fPIC -O2 -cpp -fno-second-underscore -fno-range-check -ffixed-line-length-none -fallow-argument-mismatch"

    # Include paths for Fortran modules
    local INCLUDES=(
        "-I${SOURCE_DIR}/lib"
        "-I${SOURCE_DIR}/lib/ft2"
        "-I${SOURCE_DIR}/lib/ft4"
        "-I${SOURCE_DIR}/lib/ft8"
        "-I${SOURCE_DIR}/lib/ft8var"
        "-I${SOURCE_DIR}/lib/fst4"
        "-I${SOURCE_DIR}/lib/77bit"
        "-I${SOURCE_DIR}/lib/ftrsd"
        "-I${SOURCE_DIR}/lib/superfox"
        "-I${SOURCE_DIR}/lib/superfox/qpc"
        "-I${SOURCE_DIR}/lib/qso50"
        "-I${SOURCE_DIR}/lib/wsprcode"
        "-I${SOURCE_DIR}/lib/wsprd"
        "-I${SOURCE_DIR}/lib/qra/q65"
        "-I${SOURCE_DIR}/lib/qra/qracodes"
    )

    # FFTW3 include path
    if [[ -d "${FFTW_BUILD_DIR}/install/include" ]]; then
        INCLUDES+=("-I${FFTW_BUILD_DIR}/install/include")
    fi

    # Module output directory
    FFLAGS+=" -J${FORT_BUILD_DIR}/obj"
    INCLUDES+=("-I${FORT_BUILD_DIR}/obj")

    local COMPILED=0
    local FAILED=0
    local TOTAL=${#FORT_SOURCES[@]}

    # Compile one at a time (Fortran module dependencies require sequential build)
    # We do multiple passes to resolve inter-module dependencies
    local MAX_PASSES=5
    local REMAINING=("${FORT_SOURCES[@]}")

    for pass in $(seq 1 $MAX_PASSES); do
        local STILL_REMAINING=()
        local PASS_COMPILED=0

        for src in "${REMAINING[@]}"; do
            local basename=$(basename "$src" .f90)
            local objfile="${FORT_BUILD_DIR}/obj/${basename}.o"

            # Skip if already compiled
            [[ -f "$objfile" ]] && continue

            if $FC $FFLAGS "${INCLUDES[@]}" -c "$src" -o "$objfile" 2>/dev/null; then
                ((PASS_COMPILED++))
                ((COMPILED++))
            else
                STILL_REMAINING+=("$src")
            fi
        done

        info "Pass ${pass}: compiled ${PASS_COMPILED} files (${COMPILED}/${TOTAL} total)"

        if [[ ${#STILL_REMAINING[@]} -eq 0 ]]; then
            break
        fi

        if [[ $PASS_COMPILED -eq 0 ]]; then
            # No progress - remaining files have real errors
            warn "No progress in pass ${pass}, ${#STILL_REMAINING[@]} files with errors:"
            for src in "${STILL_REMAINING[@]}"; do
                warn "  $(basename "$src")"
                # Show the actual error
                $FC $FFLAGS "${INCLUDES[@]}" -c "$src" -o /dev/null 2>&1 | head -3 || true
            done
            FAILED=${#STILL_REMAINING[@]}
            break
        fi

        REMAINING=("${STILL_REMAINING[@]}")
    done

    log "Fortran compilation: ${COMPILED} succeeded, ${FAILED} failed out of ${TOTAL}"
}

# ============================================================================
# Step 5: Cross-compile C/C++ sources
# ============================================================================
compile_c_sources() {
    log "Step 5: Cross-compiling C/C++ sources..."

    mkdir -p "${FORT_BUILD_DIR}/obj"

    # Determine C/C++ compiler
    local CC CXX
    if [[ -n "$NDK_PATH" ]] && [[ -d "$NDK_PATH" ]]; then
        local TC="${NDK_PATH}/toolchains/llvm/prebuilt/linux-x86_64/bin"
        CC="${TC}/aarch64-linux-android${ANDROID_API}-clang"
        CXX="${TC}/aarch64-linux-android${ANDROID_API}-clang++"
        if [[ ! -f "$CC" ]]; then
            CC="aarch64-linux-gnu-gcc"
            CXX="aarch64-linux-gnu-g++"
        fi
    else
        CC="aarch64-linux-gnu-gcc"
        CXX="aarch64-linux-gnu-g++"
    fi

    local CFLAGS="-fPIC -O2 -std=gnu89 -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types"
    local CXXFLAGS="-fPIC -O2"

    local INCLUDES=(
        "-I${SOURCE_DIR}/lib"
        "-I${SOURCE_DIR}/lib/ft2"
        "-I${SOURCE_DIR}/lib/ft4"
        "-I${SOURCE_DIR}/lib/ft8"
        "-I${SOURCE_DIR}/lib/fst4"
        "-I${SOURCE_DIR}/lib/77bit"
        "-I${SOURCE_DIR}/lib/ftrsd"
        "-I${SOURCE_DIR}/lib/superfox"
        "-I${SOURCE_DIR}/lib/superfox/qpc"
        "-I${SOURCE_DIR}/lib/qso50"
        "-I${SOURCE_DIR}/lib/wsprcode"
        "-I${SOURCE_DIR}/lib/wsprd"
        "-I${SOURCE_DIR}/lib/qra/q65"
        "-I${SOURCE_DIR}/lib/qra/qracodes"
    )

    # FFTW3 headers
    if [[ -d "${FFTW_BUILD_DIR}/install/include" ]]; then
        INCLUDES+=("-I${FFTW_BUILD_DIR}/install/include")
    fi

    # Compile C files
    local count=0
    for src in "${C_SOURCES[@]}"; do
        local bn=$(basename "$src" .c)
        local obj="${FORT_BUILD_DIR}/obj/${bn}.o"
        if $CC $CFLAGS "${INCLUDES[@]}" -c "$src" -o "$obj" 2>/dev/null; then
            ((count++))
        else
            warn "C compile failed: $(basename "$src")"
            $CC $CFLAGS "${INCLUDES[@]}" -c "$src" -o "$obj" 2>&1 | head -3 || true
        fi
    done
    info "Compiled ${count}/${#C_SOURCES[@]} C files"

    # Compile C++ files (need Boost headers)
    count=0
    local BOOST_INC=""
    # Find Boost headers
    for d in /usr/include /usr/local/include; do
        if [[ -f "$d/boost/crc.hpp" ]]; then
            BOOST_INC="-I$d"
            break
        fi
    done

    for src in "${CXX_SOURCES[@]}"; do
        local bn=$(basename "$src" .cpp)
        local obj="${FORT_BUILD_DIR}/obj/${bn}.o"
        if $CXX $CXXFLAGS "${INCLUDES[@]}" $BOOST_INC -c "$src" -o "$obj" 2>/dev/null; then
            ((count++))
        else
            warn "C++ compile failed: $(basename "$src")"
            $CXX $CXXFLAGS "${INCLUDES[@]}" $BOOST_INC -c "$src" -o "$obj" 2>&1 | head -3 || true
        fi
    done
    info "Compiled ${count}/${#CXX_SOURCES[@]} C++ files"
}

# ============================================================================
# Step 6: Archive into static library
# ============================================================================
archive_library() {
    log "Step 6: Creating libwsjt_fort.a..."

    local AR="aarch64-linux-gnu-ar"
    local OBJ_DIR="${FORT_BUILD_DIR}/obj"
    local OBJ_COUNT=$(find "$OBJ_DIR" -name '*.o' 2>/dev/null | wc -l)

    if [[ $OBJ_COUNT -eq 0 ]]; then
        err "No object files found!"
        exit 1
    fi

    info "Archiving ${OBJ_COUNT} object files..."

    # Create archive
    $AR rcs "${OUTPUT_DIR}/libwsjt_fort.a" "${OBJ_DIR}"/*.o

    log "Created: ${OUTPUT_DIR}/libwsjt_fort.a ($(du -h "${OUTPUT_DIR}/libwsjt_fort.a" | cut -f1))"
}

# ============================================================================
# Step 7: Copy Fortran runtime libraries
# ============================================================================
copy_runtime_libs() {
    log "Step 7: Copying Fortran runtime libraries..."

    # Find the cross-compiler's library directory
    local GFORTRAN_PATH=$(aarch64-linux-gnu-gfortran -print-file-name=libgfortran.a 2>/dev/null)
    local QUADMATH_PATH=$(aarch64-linux-gnu-gfortran -print-file-name=libquadmath.a 2>/dev/null)

    if [[ -f "$GFORTRAN_PATH" ]]; then
        cp "$GFORTRAN_PATH" "${OUTPUT_DIR}/libgfortran.a"
        log "Copied: libgfortran.a ($(du -h "${OUTPUT_DIR}/libgfortran.a" | cut -f1))"
    else
        # Build libgfortran from GCC source would be needed
        warn "libgfortran.a not found at: $GFORTRAN_PATH"
        warn "You may need to install a more complete cross-toolchain"

        # Try alternative locations
        local ALT_PATHS=(
            "/usr/lib/gcc-cross/aarch64-linux-gnu"
            "/usr/aarch64-linux-gnu/lib"
        )
        for base in "${ALT_PATHS[@]}"; do
            local found=$(find "$base" -name 'libgfortran.a' 2>/dev/null | head -1)
            if [[ -n "$found" ]]; then
                cp "$found" "${OUTPUT_DIR}/libgfortran.a"
                log "Found and copied: $found"
                break
            fi
        done
    fi

    if [[ -f "$QUADMATH_PATH" ]]; then
        cp "$QUADMATH_PATH" "${OUTPUT_DIR}/libquadmath.a"
        log "Copied: libquadmath.a"
    else
        warn "libquadmath.a not found (may not be needed on ARM64)"
    fi

    # Also copy libgcc if available
    local LIBGCC_PATH=$(aarch64-linux-gnu-gcc -print-file-name=libgcc.a 2>/dev/null)
    if [[ -f "$LIBGCC_PATH" ]]; then
        cp "$LIBGCC_PATH" "${OUTPUT_DIR}/libgcc.a"
        log "Copied: libgcc.a"
    fi
}

# ============================================================================
# Step 8: Verify outputs
# ============================================================================
verify_outputs() {
    log "Step 8: Verifying outputs..."
    echo ""

    local ALL_OK=1
    local FILES=(libwsjt_fort.a libfftw3f.a libgfortran.a)

    for f in "${FILES[@]}"; do
        local path="${OUTPUT_DIR}/$f"
        if [[ -f "$path" ]]; then
            local size=$(du -h "$path" | cut -f1)
            local count=$(aarch64-linux-gnu-ar t "$path" 2>/dev/null | wc -l)
            echo -e "  ${GREEN}OK${NC}  $f  ($size, $count objects)"

            # Verify architecture
            local first_obj=$(aarch64-linux-gnu-ar t "$path" 2>/dev/null | head -1)
            if [[ -n "$first_obj" ]]; then
                local arch_check=$(aarch64-linux-gnu-ar p "$path" "$first_obj" 2>/dev/null | file - 2>/dev/null)
                if echo "$arch_check" | grep -qi "aarch64\|ARM aarch64"; then
                    echo -e "       Architecture: ${GREEN}aarch64${NC}"
                else
                    echo -e "       Architecture: ${YELLOW}$(echo "$arch_check" | head -1)${NC}"
                fi
            fi
        else
            echo -e "  ${RED}MISSING${NC}  $f"
            ALL_OK=0
        fi
    done

    echo ""
    if [[ $ALL_OK -eq 1 ]]; then
        log "============================================"
        log " BUILD SUCCESSFUL"
        log " Output directory: ${OUTPUT_DIR}"
        log "============================================"
        log ""
        log "Next steps:"
        log "  1. Install Android NDK: sdkmanager 'ndk;27.0.12077973'"
        log "  2. Install Qt 6.8 Android: aqt install-qt linux android 6.8.0 android_arm64_v8a"
        log "  3. Build APK:"
        log "     qt-cmake -DCMAKE_TOOLCHAIN_FILE=\$NDK/build/cmake/android.toolchain.cmake \\"
        log "       -DANDROID_ABI=arm64-v8a -DANDROID_NATIVE_API_LEVEL=24 \\"
        log "       -DQT_HOST_PATH=\$QT_HOST -S Decodium3 -B build-android"
        log "     cmake --build build-android --target apk"
    else
        err "Some libraries are missing! Check errors above."
        exit 1
    fi
}

# ============================================================================
# Main
# ============================================================================
main() {
    # Validate source directory
    if [[ ! -f "${SOURCE_DIR}/CMakeLists.txt" ]]; then
        err "Source directory not found: ${SOURCE_DIR}"
        err "Use --source /path/to/Decodium3"
        exit 1
    fi

    if [[ ! -d "${SOURCE_DIR}/lib" ]]; then
        err "lib/ directory not found in source"
        exit 1
    fi

    # Create output directory
    mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}"

    # Run build steps
    if [[ $SKIP_DEPS -eq 0 ]]; then
        install_prerequisites
    fi

    build_fftw3
    collect_fortran_sources
    collect_c_sources
    compile_fortran
    compile_c_sources
    archive_library
    copy_runtime_libs
    verify_outputs
}

main "$@"
