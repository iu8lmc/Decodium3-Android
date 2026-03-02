# Pre-built Libraries for Android ARM64

This directory contains pre-built static libraries for cross-compiling
Decodium3 for Android ARM64 (aarch64).

## Directory Structure

```
prebuilt/
├── android-arm64-v8a/    # ARM64 libraries (phone)
│   ├── libwsjt_fort.a    # Fortran decoders (518 .f90 + 67 .c + crc*.cpp)
│   ├── libfftw3f.a       # FFTW3 single precision + threads
│   ├── libgfortran.a     # GNU Fortran runtime
│   ├── libquadmath.a     # Quad-precision math (if available)
│   └── libgcc.a          # GCC runtime
├── android-x86_64/       # x86_64 libraries (emulator) [optional]
└── scripts/
    ├── build_android_arm64.sh   # Main build script (Linux/WSL2)
    ├── build_android_arm64.ps1  # Windows wrapper (WSL2/Docker)
    ├── ci_build_arm64.yml       # GitHub Actions workflow
    └── Dockerfile.arm64         # Docker image for build
```

## How to Build

### Option 1: PowerShell (Windows, auto-detects WSL2/Docker)
```powershell
cd Decodium3
.\prebuilt\scripts\build_android_arm64.ps1
```

### Option 2: WSL2 Ubuntu (direct)
```bash
cd /mnt/c/Users/.../Decodium3
bash prebuilt/scripts/build_android_arm64.sh --source .
```

### Option 3: Docker
```bash
cd Decodium3
docker build -t arm64-builder -f prebuilt/scripts/Dockerfile.arm64 .
docker run --rm -v "$(pwd):/src" arm64-builder \
    /src/prebuilt/scripts/build_android_arm64.sh --source /src --skip-deps
```

### Option 4: GitHub Actions
Copy `prebuilt/scripts/ci_build_arm64.yml` to `.github/workflows/` and push.
Download the artifact `prebuilt-android-arm64-v8a` from the Actions tab.

## Prerequisites

The build script automatically installs (on Ubuntu/Debian):
- `gfortran-aarch64-linux-gnu` - Fortran cross-compiler
- `gcc-aarch64-linux-gnu` - C cross-compiler
- `g++-aarch64-linux-gnu` - C++ cross-compiler (for crc*.cpp)
- `libboost-dev` - Boost headers (for boost/crc.hpp)
- `wget` - to download FFTW3 source

## Build Process

1. **FFTW3**: Downloads source, configures with `--host=aarch64-linux-gnu --enable-single --enable-threads`
2. **Fortran**: Multi-pass compilation of ~430 .f90 files with module dependency resolution
3. **C/C++**: Compiles ~67 .c files (Phil Karn RS codec, etc.) and crc*.cpp (Boost CRC)
4. **Archive**: `aarch64-linux-gnu-ar rcs libwsjt_fort.a *.o`
5. **Runtime**: Copies `libgfortran.a` from cross-compiler sysroot

## After Building

Install the Android NDK and Qt6 Android kit, then build the APK:

```bash
# Install NDK
sdkmanager "ndk;27.0.12077973"

# Install Qt6 Android kit
aqt install-qt linux android 6.8.0 android_arm64_v8a

# Configure
$QT_ANDROID/bin/qt-cmake \
    -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a -DANDROID_NATIVE_API_LEVEL=24 \
    -DQT_HOST_PATH=$QT_HOST -S Decodium3 -B build-android

# Build APK
cmake --build build-android --target apk
```
