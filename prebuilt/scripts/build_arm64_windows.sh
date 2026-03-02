#!/bin/bash
# ============================================================================
# build_arm64_windows.sh
# Cross-compile wsjt_fort + FFTW3 for Android ARM64 using ARM GNU Toolchain
# on Windows (MSYS2/Git Bash) - NO WSL2/Docker required!
#
# Prerequisites:
#   - ARM GNU Toolchain extracted to prebuilt/toolchain/
#     (aarch64-none-linux-gnu-gfortran, etc.)
#   - MSYS2 with make, wget (or Git Bash)
#
# Usage:
#   bash build_arm64_windows.sh [--source /path/to/Decodium3]
#
# Output: prebuilt/android-arm64-v8a/{libwsjt_fort.a, libfftw3f.a, libgfortran.a}
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FFTW_VERSION=3.3.10
FFTW_URL="http://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)  SOURCE_DIR="$2"; shift 2 ;;
        --jobs|-j) JOBS="$2"; shift 2 ;;
        *)         shift ;;
    esac
done

# Paths
TOOLCHAIN_DIR="${SOURCE_DIR}/prebuilt/toolchain"
BUILD_DIR="${SOURCE_DIR}/prebuilt/build-arm64"
OUTPUT_DIR="${SOURCE_DIR}/prebuilt/android-arm64-v8a"
OBJ_DIR="${BUILD_DIR}/obj"
FFTW_BUILD="${BUILD_DIR}/fftw3"

# Detect job count
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}

# Ensure make is in PATH (MSYS2)
if ! command -v make >/dev/null 2>&1; then
    if [[ -f /c/msys64/usr/bin/make.exe ]]; then
        export PATH="/c/msys64/usr/bin:$PATH"
    fi
fi

# Fix temp directory for cross-compiler assembler on Windows
export TMPDIR="${TMPDIR:-/tmp}"
export TMP="$TMPDIR" TEMP="$TMPDIR"
mkdir -p "$TMPDIR" 2>/dev/null || true

# Colors
G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; C='\033[0;36m'; N='\033[0m'
log()  { echo -e "${G}[BUILD]${N} $*"; }
warn() { echo -e "${Y}[WARN]${N} $*"; }
err()  { echo -e "${R}[ERROR]${N} $*" >&2; }
info() { echo -e "${C}[INFO]${N} $*"; }

# ── Find toolchain ──
find_toolchain() {
    # Search for the toolchain
    local search_dirs=(
        "${TOOLCHAIN_DIR}"
        "${SOURCE_DIR}/prebuilt/arm-gnu-toolchain"*
        "$HOME/arm-gnu-toolchain"*
        "/c/arm-gnu-toolchain"*
    )

    for dir in "${search_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local fc=$(find "$dir" -name 'aarch64-none-linux-gnu-gfortran.exe' -o -name 'aarch64-none-linux-gnu-gfortran' 2>/dev/null | head -1)
            if [[ -n "$fc" ]]; then
                TOOLCHAIN_BIN="$(dirname "$fc")"
                return 0
            fi
        fi
    done

    err "ARM GNU Toolchain not found!"
    err "Expected: ${TOOLCHAIN_DIR}/bin/aarch64-none-linux-gnu-gfortran"
    err ""
    err "Download from: https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads"
    err "Extract to: ${TOOLCHAIN_DIR}/"
    exit 1
}

# ── Compiler variables ──
setup_compilers() {
    find_toolchain

    FC="${TOOLCHAIN_BIN}/aarch64-none-linux-gnu-gfortran"
    CC="${TOOLCHAIN_BIN}/aarch64-none-linux-gnu-gcc"
    CXX="${TOOLCHAIN_BIN}/aarch64-none-linux-gnu-g++"
    AR="${TOOLCHAIN_BIN}/aarch64-none-linux-gnu-ar"
    RANLIB="${TOOLCHAIN_BIN}/aarch64-none-linux-gnu-ranlib"

    # Add .exe extension on Windows if needed
    for var in FC CC CXX AR RANLIB; do
        eval "local val=\$$var"
        if [[ ! -f "$val" ]] && [[ -f "${val}.exe" ]]; then
            eval "$var=${val}.exe"
        fi
    done

    # Verify
    for tool in FC CC CXX AR; do
        eval "local val=\$$tool"
        if [[ ! -f "$val" ]]; then
            err "Tool not found: $val"
            exit 1
        fi
    done

    info "FC:  $($FC --version 2>&1 | head -1)"
    info "CC:  $($CC --version 2>&1 | head -1)"
    info "CXX: $($CXX --version 2>&1 | head -1)"
    info "AR:  $AR"
}

# ============================================================================
# Step 1: Cross-compile FFTW3
# ============================================================================
build_fftw3() {
    log "Step 1: Cross-compiling FFTW3 ${FFTW_VERSION}..."

    if [[ -f "${OUTPUT_DIR}/libfftw3f.a" ]]; then
        warn "FFTW3 already built, skipping"
        return
    fi

    mkdir -p "${FFTW_BUILD}"
    cd "${FFTW_BUILD}"

    if [[ ! -f "fftw-${FFTW_VERSION}.tar.gz" ]]; then
        log "Downloading FFTW3..."
        curl -L -o "fftw-${FFTW_VERSION}.tar.gz" "${FFTW_URL}"
    fi

    if [[ ! -d "fftw-${FFTW_VERSION}" ]]; then
        tar xzf "fftw-${FFTW_VERSION}.tar.gz"
    fi

    cd "fftw-${FFTW_VERSION}"

    # On Windows, autotools configure fails for cross-compilation (can't link executables).
    # Instead, compile FFTW3 source files directly with the cross-compiler.
    local FFTW_SRC="${FFTW_BUILD}/fftw-${FFTW_VERSION}"

    # Generate config.h manually
    cat > "${FFTW_SRC}/config.h" << 'CFGEOF'
#define PACKAGE "fftw"
#define VERSION "3.3.10"
#define FFTW_SINGLE 1
#define BENCHFFT_SINGLE 1
#define HAVE_UNISTD_H 1
#define HAVE_STRING_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STDIO_H 1
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_MEMORY_H 1
#define HAVE_MATH_H 1
#define HAVE_DRAND48 1
#define HAVE_SQRT 1
#define HAVE_MEMSET 1
#define HAVE_POSIX_MEMALIGN 1
#define HAVE_MEMALIGN 1
#define HAVE_ABORT 1
#define HAVE_SINL 1
#define HAVE_COSL 1
#define HAVE_SNPRINTF 1
#define HAVE_MEMMOVE 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_ISNAN 1
#define SIZEOF_INT 4
#define SIZEOF_LONG_LONG 8
#define SIZEOF_SIZE_T 8
#define SIZEOF_PTRDIFF_T 8
#define SIZEOF_FLOAT 4
#define SIZEOF_DOUBLE 8
#define SIZEOF_FFTW_R2R_KIND 4
#define HAVE_UINTPTR_T 1
#define USING_POSIX_THREADS 1
CFGEOF

    local FFTW_CFLAGS="-fPIC -O2 -DHAVE_CONFIG_H -I${FFTW_SRC} -I${FFTW_SRC}/api -I${FFTW_SRC}/kernel -I${FFTW_SRC}/dft -I${FFTW_SRC}/rdft -I${FFTW_SRC}/reodft -I${FFTW_SRC}/simd-support -I${FFTW_SRC}/threads -I${FFTW_SRC}/dft/scalar -I${FFTW_SRC}/rdft/scalar -Wno-implicit-function-declaration -Wno-int-conversion"
    local FFTW_OBJ="${FFTW_BUILD}/obj"
    mkdir -p "$FFTW_OBJ"

    # Compile all .c files in the key directories
    local fftw_dirs=(
        kernel api
        dft dft/scalar dft/scalar/codelets
        rdft rdft/scalar rdft/scalar/r2cf rdft/scalar/r2cb rdft/scalar/r2r
        reodft threads simd-support
    )

    local fftw_count=0
    for dir in "${fftw_dirs[@]}"; do
        local full_dir="${FFTW_SRC}/${dir}"
        [[ -d "$full_dir" ]] || continue
        # Use directory-prefixed object names to avoid basename collisions
        # e.g. kernel/conf.c -> kernel_conf.o, dft/conf.c -> dft_conf.o
        local dir_prefix="${dir//\//_}"   # replace / with _
        for src in "$full_dir"/*.c; do
            [[ -f "$src" ]] || continue
            local bn=$(basename "$src" .c)
            # Skip test/bench files
            case "$bn" in bench*|test*|fftw-bench*) continue ;; esac
            local obj="${FFTW_OBJ}/${dir_prefix}_${bn}.o"
            if "$CC" $FFTW_CFLAGS -c "$src" -o "$obj" 2>/dev/null; then
                ((fftw_count++)) || true
            fi
        done
    done

    info "Compiled ${fftw_count} FFTW3 source files"

    # Archive (use find+xargs to avoid "Argument list too long")
    rm -f "${OUTPUT_DIR}/libfftw3f.a"
    find "${FFTW_OBJ}" -name "*.o" -print0 | xargs -0 "$AR" rcs "${OUTPUT_DIR}/libfftw3f.a"
    "$RANLIB" "${OUTPUT_DIR}/libfftw3f.a" 2>/dev/null || true

    log "FFTW3 done: $(du -h "${OUTPUT_DIR}/libfftw3f.a" | cut -f1)"
}

# ============================================================================
# Step 2: Collect source files
# ============================================================================
collect_sources() {
    log "Step 2: Collecting source files..."

    LIB="${SOURCE_DIR}/lib"

    # ── Fortran sources ──
    FORT_SOURCES=()
    local fort_dirs=(
        "$LIB" "$LIB/ft2" "$LIB/ft4" "$LIB/ft8" "$LIB/fst4"
        "$LIB/77bit" "$LIB/ft8var" "$LIB/ftrsd"
        "$LIB/superfox" "$LIB/superfox/qpc"
        "$LIB/qso50" "$LIB/wsprcode" "$LIB/qra/q65" "$LIB/wsprd"
    )

    for dir in "${fort_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for f in "$dir"/*.f90; do
            [[ -f "$f" ]] || continue
            FORT_SOURCES+=("$f")
        done
    done

    # Exclusion lists (from CMakeLists.txt)
    local -A EXCLUDE_MAP
    local exclude_names=(
        # Patterns
        sim Sim SIM test Test allsim chkfft calibrate ldpcsim
        # Standalone programs
        allcall jt9 map65 cablog code426 contest72 count4
        EchoCallSim emedop fcal fer65 fersum fixwav fmtave genmet
        jt4code jt65 jt65code jt9code jt9w msk144code mskber
        psk_parse rtty_spec q65params qra64code stats timefft
        ft2 ft4code ft8code ft8d chkdec twq q65code sfrx sftx
        wsprcode WSPRcode t2 bodide mfsk prob
        encode77 call_to_c28 hash22calc nonstd_to_c58 test28 free_text
        # Include files (not compilable)
        constants conv232 fftw3 fil61 fmeasure jt4a jt9com jt9sync
        pfx prcom testmsg wqdecode avg4 msk144_testmsg
        ldpc_128_90_b_generator ldpc_128_90_b_reordered_parity
        ldpc_128_90_generator ldpc_128_90_reordered_parity
        sfrsd fst280_decode
        ft2_params gcom1 cdatetime ft4_params ft4_testmsg
        ft8_params ft8_testmsg h1
        ldpc_174_87_params ldpc_174_91_c_colorder
        ldpc_174_91_c_generator ldpc_174_91_c_parity
        ldpc_174_91_c_reordered_parity
        baddatavar call_q callsign_q syncdist
        fst4_params gtag
        ldpc_240_101_generator ldpc_240_101_parity
        ldpc_240_74_generator ldpc_240_74_parity
        wspr_params
    )
    for name in "${exclude_names[@]}"; do
        EXCLUDE_MAP["$name"]=1
    done

    # Filter
    local FILTERED=()
    for src in "${FORT_SOURCES[@]}"; do
        local bn=$(basename "$src" .f90)
        local skip=0

        # Exact match
        [[ -n "${EXCLUDE_MAP[$bn]+x}" ]] && skip=1

        # Pattern match (sim, test in name)
        if [[ $skip -eq 0 ]]; then
            case "$bn" in
                *[Ss]im*|*test*|*ldpcsim*) skip=1 ;;
            esac
        fi

        # Check for 'program' statement
        if [[ $skip -eq 0 ]]; then
            if grep -qiE '^\s*program\s' "$src" 2>/dev/null; then
                skip=1
            fi
        fi

        [[ $skip -eq 0 ]] && FILTERED+=("$src")
    done
    FORT_SOURCES=("${FILTERED[@]}")

    # ── C sources ──
    C_SOURCES=()
    for f in "$LIB"/*.c; do
        [[ -f "$f" ]] || continue
        local bn=$(basename "$f")
        case "$bn" in *sim*|*test*|tstrig.c|ptt.c|rig_control.c) continue ;; esac
        C_SOURCES+=("$f")
    done

    # C subdirectories
    local c_subdirs=("$LIB/qra/q65" "$LIB/qra/qracodes" "$LIB/wsprd" "$LIB/superfox/qpc")
    local c_exclude="main.c|normrnd.c|npfwht.c|pdmath.c|qracodes.c|wsprd.c|gran.c|tab.c|WSPRcode.c"
    for dir in "${c_subdirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for f in "$dir"/*.c; do
            [[ -f "$f" ]] || continue
            local bn=$(basename "$f")
            if echo "$bn" | grep -qE "($c_exclude|sim|test)"; then continue; fi
            C_SOURCES+=("$f")
        done
    done

    # ── C++ sources (crc*.cpp) ──
    CXX_SOURCES=()
    for f in "$LIB"/crc1[0-9].cpp; do
        [[ -f "$f" ]] && CXX_SOURCES+=("$f")
    done

    info "${#FORT_SOURCES[@]} Fortran, ${#C_SOURCES[@]} C, ${#CXX_SOURCES[@]} C++ files"
}

# ============================================================================
# Step 3: Compile Fortran (multi-pass for module dependencies)
# ============================================================================
compile_fortran() {
    log "Step 3: Compiling ${#FORT_SOURCES[@]} Fortran files..."

    mkdir -p "$OBJ_DIR"

    local FFLAGS="-fPIC -O2 -cpp -fno-second-underscore -fno-range-check"
    FFLAGS+=" -ffixed-line-length-none -fallow-argument-mismatch -fopenmp"

    local INCS=(
        "-I${LIB}" "-I${LIB}/ft2" "-I${LIB}/ft4" "-I${LIB}/ft8"
        "-I${LIB}/ft8var" "-I${LIB}/fst4" "-I${LIB}/77bit"
        "-I${LIB}/ftrsd" "-I${LIB}/superfox" "-I${LIB}/superfox/qpc"
        "-I${LIB}/qso50" "-I${LIB}/wsprcode" "-I${LIB}/wsprd"
        "-I${LIB}/qra/q65" "-I${LIB}/qra/qracodes"
        "-J${OBJ_DIR}" "-I${OBJ_DIR}"
    )

    # FFTW3 headers
    if [[ -d "${FFTW_BUILD}/install/include" ]]; then
        INCS+=("-I${FFTW_BUILD}/install/include")
    fi

    # Compile omp_lib stub (ARM toolchain doesn't ship omp_lib.mod for Fortran)
    local OMP_STUB="${SCRIPT_DIR}/omp_lib_stub.f90"
    if [[ -f "$OMP_STUB" ]] && [[ ! -f "${OBJ_DIR}/omp_lib.mod" ]]; then
        info "Compiling omp_lib stub..."
        "$FC" -fPIC -O2 -J"${OBJ_DIR}" -c "$OMP_STUB" -o "${OBJ_DIR}/omp_lib_stub.o" 2>&1
    fi

    local COMPILED=0 TOTAL=${#FORT_SOURCES[@]}
    local REMAINING=("${FORT_SOURCES[@]}")

    # Build map of unique object names (handle duplicate basenames across subdirs)
    declare -A OBJ_NAME_MAP
    declare -A SEEN_NAMES
    for src in "${FORT_SOURCES[@]}"; do
        local bn=$(basename "$src" .f90)
        if [[ -n "${SEEN_NAMES[$bn]+x}" ]]; then
            # Duplicate basename: prefix with parent dir name
            local parent=$(basename "$(dirname "$src")")
            OBJ_NAME_MAP["$src"]="${parent}_${bn}"
        else
            OBJ_NAME_MAP["$src"]="$bn"
            SEEN_NAMES["$bn"]=1
        fi
    done

    for pass in 1 2 3 4 5 6; do
        local NEXT=()
        local PASS_OK=0

        for src in "${REMAINING[@]}"; do
            local objname="${OBJ_NAME_MAP[$src]}"
            local obj="${OBJ_DIR}/${objname}.o"
            [[ -f "$obj" ]] && continue

            if "$FC" $FFLAGS "${INCS[@]}" -c "$src" -o "$obj" 2>/dev/null; then
                ((PASS_OK++)) || true
                ((COMPILED++)) || true
            else
                NEXT+=("$src")
            fi
        done

        info "Pass ${pass}: +${PASS_OK} compiled (${COMPILED}/${TOTAL})"

        [[ ${#NEXT[@]} -eq 0 ]] && break
        [[ $PASS_OK -eq 0 ]] && {
            warn "${#NEXT[@]} files with compile errors:"
            for src in "${NEXT[@]:0:10}"; do
                warn "  $(basename "$src") ($(dirname "$src" | sed "s|.*/||"))"
                "$FC" $FFLAGS "${INCS[@]}" -c "$src" -o /dev/null 2>&1 | head -3 || true
            done
            break
        }
        REMAINING=("${NEXT[@]}")
    done

    log "Fortran: ${COMPILED}/${TOTAL} compiled"
}

# ============================================================================
# Step 4: Compile C/C++
# ============================================================================
compile_c() {
    log "Step 4: Compiling C/C++ files..."

    local CFLAGS="-fPIC -O2 -std=gnu89 -Wno-implicit-function-declaration"
    CFLAGS+=" -Wno-int-conversion -Wno-incompatible-pointer-types"
    local CXXFLAGS="-fPIC -O2"

    local INCS=(
        "-I${LIB}" "-I${LIB}/ft2" "-I${LIB}/ft4" "-I${LIB}/ft8"
        "-I${LIB}/fst4" "-I${LIB}/77bit" "-I${LIB}/ftrsd"
        "-I${LIB}/superfox" "-I${LIB}/superfox/qpc"
        "-I${LIB}/qso50" "-I${LIB}/wsprcode" "-I${LIB}/wsprd"
        "-I${LIB}/qra/q65" "-I${LIB}/qra/qracodes"
    )

    if [[ -d "${FFTW_BUILD}/install/include" ]]; then
        INCS+=("-I${FFTW_BUILD}/install/include")
    fi

    # C files
    local ok=0
    for src in "${C_SOURCES[@]}"; do
        local bn=$(basename "$src" .c)
        local obj="${OBJ_DIR}/${bn}.o"
        if "$CC" $CFLAGS "${INCS[@]}" -c "$src" -o "$obj" 2>/dev/null; then
            ((ok++)) || true
        else
            warn "FAIL: $(basename "$src")"
        fi
    done
    info "C: ${ok}/${#C_SOURCES[@]}"

    # CRC functions: use standalone C implementation instead of Boost C++.
    # Boost headers from MSYS2 include Windows-specific headers (corecrt.h)
    # that are incompatible with the ARM64 cross-compiler.
    local CRC_SRC="${SCRIPT_DIR}/crc_standalone.c"
    if [[ -f "$CRC_SRC" ]]; then
        local obj="${OBJ_DIR}/crc_standalone.o"
        if "$CC" $CFLAGS "${INCS[@]}" -c "$CRC_SRC" -o "$obj" 2>&1; then
            info "CRC: crc_standalone.c compiled (crc10+crc13+crc14)"
        else
            warn "FAIL: crc_standalone.c"
        fi
    else
        warn "crc_standalone.c not found at ${CRC_SRC}"
        warn "CRC functions will be missing from the library"
    fi
}

# ============================================================================
# Step 5: Archive
# ============================================================================
archive() {
    log "Step 5: Creating libwsjt_fort.a..."

    local count=$(find "$OBJ_DIR" -name '*.o' | wc -l)
    [[ $count -eq 0 ]] && { err "No object files!"; exit 1; }

    "$AR" rcs "${OUTPUT_DIR}/libwsjt_fort.a" "${OBJ_DIR}"/*.o
    "$RANLIB" "${OUTPUT_DIR}/libwsjt_fort.a" 2>/dev/null || true

    log "libwsjt_fort.a: $(du -h "${OUTPUT_DIR}/libwsjt_fort.a" | cut -f1) (${count} objects)"
}

# ============================================================================
# Step 6: Copy runtime libs
# ============================================================================
copy_runtime() {
    log "Step 6: Copying runtime libraries..."

    local SYSROOT
    SYSROOT=$("$FC" -print-sysroot 2>/dev/null || echo "")

    # libgfortran.a
    local gf=$("$FC" -print-file-name=libgfortran.a 2>/dev/null)
    if [[ -f "$gf" ]]; then
        cp "$gf" "${OUTPUT_DIR}/libgfortran.a"
        log "libgfortran.a: $(du -h "${OUTPUT_DIR}/libgfortran.a" | cut -f1)"
    else
        warn "libgfortran.a not found"
        # Search manually
        local found=$(find "${TOOLCHAIN_BIN}/.." -name 'libgfortran.a' 2>/dev/null | head -1)
        if [[ -n "$found" ]]; then
            cp "$found" "${OUTPUT_DIR}/libgfortran.a"
            log "Found: $found"
        fi
    fi

    # libquadmath.a
    local qm=$("$FC" -print-file-name=libquadmath.a 2>/dev/null)
    if [[ -f "$qm" ]]; then
        cp "$qm" "${OUTPUT_DIR}/libquadmath.a"
        log "libquadmath.a: $(du -h "${OUTPUT_DIR}/libquadmath.a" | cut -f1)"
    fi

    # libgcc.a
    local gc=$("$CC" -print-file-name=libgcc.a 2>/dev/null)
    if [[ -f "$gc" ]]; then
        cp "$gc" "${OUTPUT_DIR}/libgcc.a"
        log "libgcc.a"
    fi
}

# ============================================================================
# Step 7: Verify
# ============================================================================
verify() {
    log "Step 7: Verifying outputs..."
    echo ""

    local ok=1
    for f in libwsjt_fort.a libfftw3f.a libgfortran.a; do
        local p="${OUTPUT_DIR}/$f"
        if [[ -f "$p" ]]; then
            local sz=$(du -h "$p" | cut -f1)
            local n=$("$AR" t "$p" 2>/dev/null | wc -l)
            echo -e "  ${G}OK${N}  $f  ($sz, $n objects)"
        else
            echo -e "  ${R}MISS${N}  $f"
            ok=0
        fi
    done

    echo ""
    if [[ $ok -eq 1 ]]; then
        log "=========================================="
        log " BUILD SUCCESSFUL"
        log " Output: ${OUTPUT_DIR}"
        log "=========================================="
    else
        err "Some libraries missing!"
        exit 1
    fi
}

# ============================================================================
# Main
# ============================================================================
log "============================================"
log " Decodium3 ARM64 Cross-Compilation"
log " (ARM GNU Toolchain on Windows)"
log "============================================"
info "Source: ${SOURCE_DIR}"
info "Output: ${OUTPUT_DIR}"
echo ""

mkdir -p "$OUTPUT_DIR" "$BUILD_DIR" "$OBJ_DIR"

setup_compilers
build_fftw3
collect_sources
compile_fortran
compile_c
archive
copy_runtime
verify
