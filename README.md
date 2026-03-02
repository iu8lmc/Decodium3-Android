# Decodium3 Android

**FT2 / FT4 / FT8 decoder for Android** — Qt6 + QML fork of WSJT-X 3.0 with WiFi audio bridge.

Operate FT8, FT4 and the new FT2 mode from your Android phone, with your radio connected to a PC via the WiFi bridge.

## Architecture

```
┌─────────────────────────┐    WiFi (WebSocket)    ┌─────────────────────────┐
│   Android Phone         │◄══════════════════════►│   PC + Radio            │
│                         │   PCM audio 12 kHz     │                         │
│  Decodium3 App          │   CAT commands         │  DecodiumBridge         │
│  • QML touchscreen UI   │   Spectrum data        │  • Soundcard capture RX │
│  • Fortran FT decoder   │                        │  • Soundcard playback TX│
│  • Waterfall display    │                        │  • Hamlib CAT relay     │
│  • TX encoder + GFSK    │                        │  • UDP auto-discovery   │
└─────────────────────────┘                        └─────────────────────────┘
```

**RX path:** Radio → PC soundcard → DecodiumBridge (48→12 kHz) → WiFi → Android Detector → Fortran decoder → QML display
**TX path:** Android Modulator → WiFi → DecodiumBridge → PC soundcard → Radio
**CAT:** Android UI → WiFi → DecodiumBridge → Hamlib → Radio

WiFi bandwidth: ~120 KB/s — Latency: ~55 ms (irrelevant for FT2/FT8 timing)

## Features

- **Modes:** FT8 (15 s), FT4 (7.5 s), FT2 (3.75 s), JT65, JT9, WSPR
- **Bands:** 160 m – 70 cm with standard dial frequencies
- **Decoder:** Full WSJT-X 3.0 Fortran decoder chain (`multimode_decoder`)
- **TX encoding:** `genft8` / `genft2` / `genft4` → `itone[]` → GFSK/4-FSK modulator
- **Waterfall:** Real-time FFT spectrum via `symspec` (0–5000 Hz)
- **AP decoding:** Assisted Protocol with 2-pass, deep search levels 0–3
- **WiFi bridge:** WebSocket binary protocol, UDP LAN auto-discovery
- **CAT control:** Frequency, mode, PTT relay via Hamlib
- **Mobile UI:** 22 QML files, responsive layout, hamburger menu, touch-friendly

## Project Structure

```
Decodium3/
├── main.cpp                    # App entry, controller wiring, TX encoding
├── CMakeLists.txt              # Build system (Desktop + Android)
├── commons.h                   # Shared dec_data_t structure (Fortran ↔ C++)
│
├── controllers/                # QML ↔ Backend bridge
│   ├── AppController           # Callsign, grid, settings
│   ├── AudioController         # Audio I/O, WiFi bridge client
│   ├── DecoderController       # Fortran decoder + FFT spectrum
│   ├── RadioController         # Mode, frequency, band selection
│   ├── TxController            # TX message queue, sequencing
│   ├── WaterfallController     # Waterfall display state
│   ├── LogController           # QSO logging
│   └── DecodeListModel         # Decode results model
│
├── qml/                        # User interface (22 files)
│   ├── main.qml                # Main window + hamburger drawer
│   ├── Theme.qml               # Responsive theme (mobile/desktop)
│   ├── components/             # HeaderBar, FrequencyDisplay, BandButton, ...
│   ├── panels/                 # WaterfallPanel, DecodePanel, StatusBar, ...
│   └── dialogs/                # SettingsDialog (WiFi tab), LogQSODialog, About
│
├── Audio/                      # Audio subsystem
│   ├── NetworkAudioInput       # WebSocket RX client → Detector
│   ├── NetworkAudioOutput      # Modulator → WebSocket TX
│   ├── soundin / soundout      # Local audio (QAudioSource/Sink)
│   └── AudioDevice / BWFFile   # Base classes
│
├── Detector/                   # RX sample writer → dec_data.d2[]
├── Modulator/                  # TX tone generator (reads itone[])
├── Decoder/                    # Decoded text parser
│
├── bridge/                     # DecodiumBridge PC-side app
│   ├── BridgeServer            # WebSocket server (port 52178)
│   ├── AudioCapture            # RX capture + 48→12 kHz downsample
│   ├── AudioPlayback           # TX playback from phone
│   ├── CatRelay                # Hamlib CAT relay
│   ├── DiscoveryService        # UDP broadcast (port 52179)
│   └── BridgeProtocol.hpp      # Binary packet format (magic 0xDEC0D10A)
│
├── lib/                        # WSJT-X 3.0 Fortran/C sources (518 .f90)
│   ├── ft2/ ft4/ ft8/          # Mode-specific decoders
│   ├── 77bit/                  # Message packing (packjt77)
│   ├── ftrsd/                  # Reed-Solomon soft-decision codec
│   └── ...                     # FFT, LDPC, QRA, SuperFox, etc.
│
├── android/                    # Android packaging
│   ├── AndroidManifest.xml     # Permissions: INTERNET, WIFI, RECORD_AUDIO
│   └── res/                    # Icon, styles, network security config
│
├── prebuilt/                   # Cross-compiled ARM64 libraries
│   ├── android-arm64-v8a/      # libwsjt_fort.a, libfftw3f.a, libgfortran.a
│   └── scripts/                # Build scripts (WSL2, Docker, CI)
│
├── Transceiver/                # Hamlib, HRD, DXLab, OmniRig, TCI
├── Network/                    # PSK Reporter, Cloudlog, NTP
├── models/                     # Bands, Modes, Frequencies
└── translations/               # i18n (es, it, da, ja, zh, ru, ...)
```

## Build

### Prerequisites

| Component | Version | Notes |
|-----------|---------|-------|
| Qt6       | 6.2+    | Core, Gui, Qml, Quick, Multimedia, Network, WebSockets |
| CMake     | 3.16+   | |
| GCC / gfortran | 13+ | MinGW64 on Windows, GCC on Linux |
| FFTW3     | 3.3+    | Single precision + threads |
| Boost     | 1.62+   | log, log_setup (desktop only) |
| Hamlib    | 4.x     | Optional, for bridge CAT relay |

### Desktop (Windows — MSYS2 MinGW64)

```bash
# Install dependencies
pacman -S mingw-w64-x86_64-{cmake,gcc,gcc-fortran,fftw,boost,qt6-base,qt6-declarative,qt6-multimedia,qt6-serialport,qt6-websockets,qt6-svg}

# Configure
mkdir build && cd build
cmake .. -G "MinGW Makefiles" \
    -DCMAKE_MAKE_PROGRAM=mingw32-make.exe

# Build (use -j1 for first build — Fortran module dependencies)
mingw32-make -j1 wsjt_fort
mingw32-make -j4 decodium3
```

### Desktop (Linux)

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt install build-essential gfortran cmake \
    qt6-base-dev qt6-declarative-dev qt6-multimedia-dev \
    qt6-websockets-dev qt6-svg-dev \
    libfftw3-dev libboost-log-dev libhamlib-dev

# Build
mkdir build && cd build
cmake ..
make -j$(nproc)
```

### DecodiumBridge (PC-side WiFi relay)

```bash
cd bridge
mkdir build && cd build
cmake .. -G "MinGW Makefiles"
mingw32-make -j4
```

Requires: Qt6 (Core, Multimedia, Network, WebSockets) + Hamlib (optional).

### Android APK

**Step 1:** Cross-compile Fortran libraries for ARM64 (or use prebuilt):

```bash
# Using the build script (requires WSL2 or Docker)
cd prebuilt/scripts
./build_android_arm64.sh

# Output: prebuilt/android-arm64-v8a/lib*.a
```

**Step 2:** Build APK with Qt for Android:

```bash
export QT_ANDROID=$HOME/Qt/6.7.0/android_arm64_v8a
export QT_HOST=$HOME/Qt/6.7.0/gcc_64
export NDK=$HOME/Android/Sdk/ndk/27.0.12077973

$QT_ANDROID/bin/qt-cmake \
    -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_NATIVE_API_LEVEL=24 \
    -DQT_HOST_PATH=$QT_HOST \
    -S . -B build-android

cmake --build build-android --target apk
```

APK output: `build-android/android-build/build/outputs/apk/debug/android-build-debug.apk`

## WiFi Bridge Protocol

WebSocket binary on port **52178**, UDP discovery on port **52179**.

Each packet starts with an 8-byte header:

| Offset | Size | Field |
|--------|------|-------|
| 0 | 4 | Magic: `0xDEC0D10A` |
| 4 | 1 | Packet type |
| 5 | 1 | Reserved |
| 6 | 2 | Payload length |

**Packet types:**

| Type | Name | Direction | Payload |
|------|------|-----------|---------|
| 0x01 | AUDIO_RX | PC → Phone | PCM Int16 mono 12 kHz (40 ms chunks) |
| 0x02 | AUDIO_TX | Phone → PC | PCM Int16 mono 48 kHz |
| 0x03 | CAT_FREQ | Phone → PC | uint64 frequency (Hz) |
| 0x04 | CAT_MODE | Phone → PC | UTF-8 mode string |
| 0x05 | CAT_PTT | Phone → PC | uint8 (0/1) |
| 0x06 | CAT_STATUS | PC → Phone | freq + mode + PTT + S-meter |
| 0x07 | SPECTRUM | PC → Phone | float32[] FFT bins |
| 0x08 | HEARTBEAT | Both | uint32 timestamp |

## Usage

1. **Start DecodiumBridge** on the PC connected to the radio
2. **Launch Decodium3** on Android
3. Open **Settings → WiFi Bridge** — scan or enter bridge IP
4. Tap **Connect** — waterfall starts showing RX signals
5. Select **band** and **mode** (FT8 / FT4 / FT2)
6. **Double-tap** a decoded station to start a QSO
7. TX messages are automatically sequenced

## License

Based on [WSJT-X](https://wsjt.sourceforge.io/) by Joe Taylor K1JT et al.
Licensed under the **GNU General Public License v3.0**.

## Credits

- **WSJT-X 3.0** — Joe Taylor K1JT, Bill Somerville G4WJS, Steve Franke K9AN
- **FT2 mode** — Joe Taylor K1JT
- **Decodium3** — IU8LMC
- **Android port & WiFi bridge** — Built with Claude Code (Anthropic)

73 de IU8LMC
