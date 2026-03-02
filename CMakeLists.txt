cmake_minimum_required(VERSION 3.16)

# Detect Android before project() via command-line variable
if(ANDROID_ABI OR CMAKE_SYSTEM_NAME STREQUAL "Android")
    project(Decodium3 VERSION 3.0.0 LANGUAGES CXX C)
else()
    project(Decodium3 VERSION 3.0.0 LANGUAGES CXX C Fortran)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# CMake module path for FindHamlib, FindFFTW3, etc.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/CMake/Modules)

# ============================================================
# Qt6
# ============================================================
if(ANDROID)
    find_package(Qt6 REQUIRED COMPONENTS
        Core Gui Qml Quick QuickControls2
        Multimedia Sql Network WebSockets Svg)
else()
    find_package(Qt6 REQUIRED COMPONENTS
        Core Gui Widgets Qml Quick QuickControls2
        Multimedia SerialPort Sql Network WebSockets Svg)
endif()

if(WIN32)
    find_package(Qt6 COMPONENTS AxContainer)
endif()

# ============================================================
# External dependencies
# ============================================================
if(NOT ANDROID)
    find_package(FFTW3 COMPONENTS single threads REQUIRED)
endif()

# Boost for logging (not needed on Android)
if(NOT ANDROID)
    find_package(Boost 1.62 COMPONENTS log_setup log)
endif()

# Hamlib - try pkg-config first, then manual (not needed on Android)
if(NOT ANDROID)
    find_package(PkgConfig QUIET)
    if(PKG_CONFIG_FOUND)
        pkg_check_modules(HAMLIB IMPORTED_TARGET hamlib)
    endif()
    if(NOT HAMLIB_FOUND)
        find_library(HAMLIB_LIBRARIES NAMES hamlib)
        find_path(HAMLIB_INCLUDE_DIRS hamlib/rig.h)
        if(HAMLIB_LIBRARIES AND HAMLIB_INCLUDE_DIRS)
            set(HAMLIB_FOUND TRUE)
        endif()
    endif()
endif()

# ============================================================
# Fortran compiler flags
# ============================================================
if(CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
    set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -cpp -fno-second-underscore -fno-range-check -ffixed-line-length-none -fallow-argument-mismatch")
    set(CMAKE_Fortran_FLAGS_RELEASE "-O2")
    set(CMAKE_Fortran_FLAGS_DEBUG "-g -O0 -Wall -Wno-unused-variable")
endif()

# ============================================================
# Fortran source files - decoder backend
# ============================================================
file(GLOB FORT_LIB_SOURCES lib/*.f90)
file(GLOB FORT_FT2_SOURCES lib/ft2/*.f90)
file(GLOB FORT_FT4_SOURCES lib/ft4/*.f90)
file(GLOB FORT_FT8_SOURCES lib/ft8/*.f90)
file(GLOB FORT_FST4_SOURCES lib/fst4/*.f90)
file(GLOB FORT_77BIT_SOURCES lib/77bit/*.f90)
file(GLOB FORT_FT8VAR_SOURCES lib/ft8var/*.f90)
file(GLOB FORT_FTRSD_SOURCES lib/ftrsd/*.f90)
file(GLOB FORT_FTRSD_C_SOURCES lib/ftrsd/*.c)
# NOTE: ftrsd/ RS codec files (init_rs.c, encode_rs.c, decode_rs.c) are KEPT here.
# They define init_rs_int/encode_rs_int/decode_rs_int when compiled with BIGSYM=1.
# The lib/ versions are EXCLUDED below (same approach as WSJT-X upstream).
file(GLOB FORT_SUPERFOX_SOURCES lib/superfox/*.f90)
file(GLOB FORT_SUPERFOX_QPC_SOURCES lib/superfox/qpc/*.f90)
file(GLOB FORT_SUPERFOX_QPC_C_SOURCES lib/superfox/qpc/*.c)
file(GLOB FORT_QSO50_SOURCES lib/qso50/*.f90)
file(GLOB FORT_WSPRCODE_SOURCES lib/wsprcode/*.f90)
file(GLOB FORT_QRA_Q65_SOURCES lib/qra/q65/*.f90)
file(GLOB FORT_QRA_Q65_C_SOURCES lib/qra/q65/*.c)
file(GLOB FORT_QRA_CODES_C_SOURCES lib/qra/qracodes/*.c)
file(GLOB FORT_WSPRD_SOURCES lib/wsprd/*.f90)
file(GLOB FORT_WSPRD_C_SOURCES lib/wsprd/*.c)

# Exclude standalone test programs and sim programs from library
list(FILTER FORT_LIB_SOURCES EXCLUDE REGEX ".*[Ss]im.*\\.f90$")
list(FILTER FORT_LIB_SOURCES EXCLUDE REGEX ".*test.*\\.f90$")
list(FILTER FORT_LIB_SOURCES EXCLUDE REGEX ".*allsim\\.f90$")
list(FILTER FORT_LIB_SOURCES EXCLUDE REGEX ".*chkfft.*\\.f90$")
list(FILTER FORT_LIB_SOURCES EXCLUDE REGEX ".*calibrate\\.f90$")
list(FILTER FORT_LIB_SOURCES EXCLUDE REGEX ".*ldpcsim.*\\.f90$")
# Exclude Fortran include/data files (no subroutine/module, not standalone compilable)
set(FORT_INCLUDE_FILES
    constants conv232 fftw3 fil61 fmeasure jt4a jt9com jt9sync
    pfx prcom testmsg avg4 msk144_testmsg
    ldpc_128_90_b_generator ldpc_128_90_b_reordered_parity
    ldpc_128_90_generator ldpc_128_90_reordered_parity
    sfrsd fst280_decode
)
foreach(_f ${FORT_INCLUDE_FILES})
    list(FILTER FORT_LIB_SOURCES EXCLUDE REGEX ".*/${_f}\\.f90$")
endforeach()

# Exclude standalone programs (files with 'program' statement that define MAIN__)
set(FORT_STANDALONE_PROGRAMS
    allcall jt9 map65
    cablog code426 contest72 count4
    EchoCallSim emedop fcal fer65 fersum
    fixwav fmtave genmet jt4code
    jt65 jt65code jt9code jt9w
    msk144code mskber psk_parse
    rtty_spec q65params qra64code stats timefft
)
foreach(_f ${FORT_STANDALONE_PROGRAMS})
    list(FILTER FORT_LIB_SOURCES EXCLUDE REGEX ".*/${_f}\\.f90$")
endforeach()
# Exclude sim/test from subdirectories
list(FILTER FORT_FT8_SOURCES EXCLUDE REGEX ".*[Ss]im.*\\.f90$")
list(FILTER FORT_FT8_SOURCES EXCLUDE REGEX ".*test.*\\.f90$")
list(FILTER FORT_FT4_SOURCES EXCLUDE REGEX ".*[Ss]im.*\\.f90$")
list(FILTER FORT_FT4_SOURCES EXCLUDE REGEX ".*test.*\\.f90$")
list(FILTER FORT_FT2_SOURCES EXCLUDE REGEX ".*[Ss]im.*\\.f90$")
list(FILTER FORT_FST4_SOURCES EXCLUDE REGEX ".*[Ss]im.*\\.f90$")
list(FILTER FORT_FST4_SOURCES EXCLUDE REGEX ".*ldpcsim.*\\.f90$")

# Exclude Fortran include/parameter files from ALL subdirectories
# (files with no module/subroutine, included by other files)
set(FORT_SUBDIR_INCLUDE_FILES
    # ft2 includes
    ft2_params gcom1 cdatetime
    # ft4 includes
    ft4_params ft4_testmsg
    # ft8 includes
    ft8_params ft8_testmsg h1
    ldpc_174_87_params ldpc_174_91_c_colorder
    ldpc_174_91_c_generator ldpc_174_91_c_parity
    # ft8var includes
    baddatavar call_q callsign_q syncdist
    ldpc_174_91_c_reordered_parity
    # fst4 includes
    fst4_params
    # superfox includes
    gtag
    ldpc_240_101_generator ldpc_240_101_parity
    ldpc_240_74_generator ldpc_240_74_parity
)
foreach(_f ${FORT_SUBDIR_INCLUDE_FILES})
    list(FILTER FORT_FT2_SOURCES EXCLUDE REGEX ".*/${_f}\\.f90$")
    list(FILTER FORT_FT4_SOURCES EXCLUDE REGEX ".*/${_f}\\.f90$")
    list(FILTER FORT_FT8_SOURCES EXCLUDE REGEX ".*/${_f}\\.f90$")
    list(FILTER FORT_FST4_SOURCES EXCLUDE REGEX ".*/${_f}\\.f90$")
    list(FILTER FORT_FT8VAR_SOURCES EXCLUDE REGEX ".*/${_f}\\.f90$")
    list(FILTER FORT_SUPERFOX_SOURCES EXCLUDE REGEX ".*/${_f}\\.f90$")
endforeach()

# Exclude sim/test from additional subdirectories
list(FILTER FORT_FT8VAR_SOURCES EXCLUDE REGEX ".*[Ss]im.*\\.f90$")
list(FILTER FORT_SUPERFOX_SOURCES EXCLUDE REGEX ".*[Ss]im.*\\.f90$")
list(FILTER FORT_FTRSD_SOURCES EXCLUDE REGEX ".*test\\.f90$")

# Exclude standalone programs from subdirectories
# ft2: ft2.f90 is a standalone test program
list(FILTER FORT_FT2_SOURCES EXCLUDE REGEX ".*/ft2\\.f90$")
# ft4: ft4code.f90
list(FILTER FORT_FT4_SOURCES EXCLUDE REGEX ".*/ft4code\\.f90$")
# ft8: ft8code.f90, ft8d.f90, chkdec.f90
list(FILTER FORT_FT8_SOURCES EXCLUDE REGEX ".*/ft8code\\.f90$")
list(FILTER FORT_FT8_SOURCES EXCLUDE REGEX ".*/ft8d\\.f90$")
list(FILTER FORT_FT8_SOURCES EXCLUDE REGEX ".*/chkdec\\.f90$")
# qso50: twq.f90
list(FILTER FORT_QSO50_SOURCES EXCLUDE REGEX ".*/twq\\.f90$")
# qra/q65: q65code.f90
list(FILTER FORT_QRA_Q65_SOURCES EXCLUDE REGEX ".*/q65code\\.f90$")
# superfox: sfrx.f90, sftx.f90
list(FILTER FORT_SUPERFOX_SOURCES EXCLUDE REGEX ".*/sfrx\\.f90$")
list(FILTER FORT_SUPERFOX_SOURCES EXCLUDE REGEX ".*/sftx\\.f90$")
# wsprcode: wsprcode.f90, wspr_old_subs.f90 (not in WSJT-X build, calls nhash_ unresolved)
list(FILTER FORT_WSPRCODE_SOURCES EXCLUDE REGEX ".*/wsprcode\\.f90$")
list(FILTER FORT_WSPRCODE_SOURCES EXCLUDE REGEX ".*/wspr_old_subs\\.f90$")
# wsprd: genmet.f90, t2.f90, WSPRcode.f90
list(FILTER FORT_WSPRD_SOURCES EXCLUDE REGEX ".*/genmet\\.f90$")
list(FILTER FORT_WSPRD_SOURCES EXCLUDE REGEX ".*/t2\\.f90$")
list(FILTER FORT_WSPRD_SOURCES EXCLUDE REGEX ".*/WSPRcode\\.f90$")
# ftrsd/ftrsd_paper subdirectory (bodide, mfsk, prob) - not globbed but exclude if present
list(FILTER FORT_FTRSD_SOURCES EXCLUDE REGEX ".*/bodide\\.f90$")
list(FILTER FORT_FTRSD_SOURCES EXCLUDE REGEX ".*/mfsk\\.f90$")
list(FILTER FORT_FTRSD_SOURCES EXCLUDE REGEX ".*/prob\\.f90$")
# 77bit standalone programs
list(FILTER FORT_77BIT_SOURCES EXCLUDE REGEX ".*/encode77\\.f90$")
list(FILTER FORT_77BIT_SOURCES EXCLUDE REGEX ".*/call_to_c28\\.f90$")
list(FILTER FORT_77BIT_SOURCES EXCLUDE REGEX ".*/hash22calc\\.f90$")
list(FILTER FORT_77BIT_SOURCES EXCLUDE REGEX ".*/nonstd_to_c58\\.f90$")
list(FILTER FORT_77BIT_SOURCES EXCLUDE REGEX ".*/test28\\.f90$")
list(FILTER FORT_77BIT_SOURCES EXCLUDE REGEX ".*/free_text\\.f90$")

# qra/q65: exclude sim/test
list(FILTER FORT_QRA_Q65_SOURCES EXCLUDE REGEX ".*sim\\.f90$")
list(FILTER FORT_QRA_Q65_SOURCES EXCLUDE REGEX ".*test.*\\.f90$")
# qra/q65 C: exclude test program
list(FILTER FORT_QRA_Q65_C_SOURCES EXCLUDE REGEX ".*test.*\\.c$")
# qra/qracodes: exclude main program and duplicates with qra/q65
list(FILTER FORT_QRA_CODES_C_SOURCES EXCLUDE REGEX ".*/main\\.c$")
list(FILTER FORT_QRA_CODES_C_SOURCES EXCLUDE REGEX ".*/normrnd\\.c$")
list(FILTER FORT_QRA_CODES_C_SOURCES EXCLUDE REGEX ".*/npfwht\\.c$")
list(FILTER FORT_QRA_CODES_C_SOURCES EXCLUDE REGEX ".*/pdmath\\.c$")
list(FILTER FORT_QRA_CODES_C_SOURCES EXCLUDE REGEX ".*/qracodes\\.c$")
# wsprd: exclude sim/test and include files
list(FILTER FORT_WSPRD_SOURCES EXCLUDE REGEX ".*sim.*\\.f90$")
list(FILTER FORT_WSPRD_SOURCES EXCLUDE REGEX ".*test.*\\.f90$")
list(FILTER FORT_WSPRD_SOURCES EXCLUDE REGEX ".*/wspr_params\\.f90$")
# wsprd C: exclude standalone programs and duplicates
list(FILTER FORT_WSPRD_C_SOURCES EXCLUDE REGEX ".*sim.*\\.c$")
list(FILTER FORT_WSPRD_C_SOURCES EXCLUDE REGEX ".*/wsprd\\.c$")
list(FILTER FORT_WSPRD_C_SOURCES EXCLUDE REGEX ".*/gran\\.c$")
list(FILTER FORT_WSPRD_C_SOURCES EXCLUDE REGEX ".*/tab\\.c$")

# C sources in lib (exclude standalone test programs)
file(GLOB FORT_C_SOURCES lib/*.c)
list(FILTER FORT_C_SOURCES EXCLUDE REGEX ".*sim.*\\.c$")
list(FILTER FORT_C_SOURCES EXCLUDE REGEX ".*/tstrig\\.c$")
list(FILTER FORT_C_SOURCES EXCLUDE REGEX ".*/ptt\\.c$")
list(FILTER FORT_C_SOURCES EXCLUDE REGEX ".*/rig_control\\.c$")
# Exclude lib/ RS codec files — ftrsd/ versions are used instead (like WSJT-X upstream)
list(FILTER FORT_C_SOURCES EXCLUDE REGEX ".*/init_rs\\.c$")
list(FILTER FORT_C_SOURCES EXCLUDE REGEX ".*/encode_rs\\.c$")
list(FILTER FORT_C_SOURCES EXCLUDE REGEX ".*/decode_rs\\.c$")

# ============================================================
# Android: use pre-built Fortran library
# ============================================================
if(ANDROID)
    add_library(wsjt_fort STATIC IMPORTED)
    set_target_properties(wsjt_fort PROPERTIES
        IMPORTED_LOCATION "${CMAKE_SOURCE_DIR}/prebuilt/android-${ANDROID_ABI}/libwsjt_fort.a")

    # Pre-built FFTW3 for Android
    add_library(fftw3f STATIC IMPORTED)
    set_target_properties(fftw3f PROPERTIES
        IMPORTED_LOCATION "${CMAKE_SOURCE_DIR}/prebuilt/android-${ANDROID_ABI}/libfftw3f.a")

    # Pre-built Fortran runtime
    add_library(gfortran STATIC IMPORTED)
    set_target_properties(gfortran PROPERTIES
        IMPORTED_LOCATION "${CMAKE_SOURCE_DIR}/prebuilt/android-${ANDROID_ABI}/libgfortran.a")

    # Android compatibility shim (glibc->Bionic, FFTW Fortran, OpenMP stubs)
    add_library(android_compat STATIC
        "${CMAKE_SOURCE_DIR}/prebuilt/scripts/android_compat.c")
    target_link_libraries(android_compat PRIVATE m)
endif()

# ============================================================
# Desktop: compile Fortran from source
# ============================================================
if(NOT ANDROID)
add_library(wsjt_fort STATIC
    lib/crc14.cpp
    ${FORT_LIB_SOURCES}
    ${FORT_FT2_SOURCES}
    ${FORT_FT4_SOURCES}
    ${FORT_FT8_SOURCES}
    ${FORT_FST4_SOURCES}
    ${FORT_77BIT_SOURCES}
    ${FORT_FT8VAR_SOURCES}
    ${FORT_FTRSD_SOURCES}
    ${FORT_FTRSD_C_SOURCES}
    ${FORT_SUPERFOX_SOURCES}
    ${FORT_SUPERFOX_QPC_SOURCES}
    ${FORT_SUPERFOX_QPC_C_SOURCES}
    ${FORT_QSO50_SOURCES}
    ${FORT_WSPRCODE_SOURCES}
    ${FORT_QRA_Q65_SOURCES}
    ${FORT_QRA_Q65_C_SOURCES}
    ${FORT_QRA_CODES_C_SOURCES}
    ${FORT_WSPRD_SOURCES}
    ${FORT_WSPRD_C_SOURCES}
    ${FORT_C_SOURCES}
)
set_target_properties(wsjt_fort PROPERTIES AUTOMOC OFF AUTORCC OFF)
target_include_directories(wsjt_fort PUBLIC
    ${CMAKE_SOURCE_DIR}/lib
    ${CMAKE_SOURCE_DIR}/lib/ft2
    ${CMAKE_SOURCE_DIR}/lib/ft4
    ${CMAKE_SOURCE_DIR}/lib/ft8
    ${CMAKE_SOURCE_DIR}/lib/ft8var
    ${CMAKE_SOURCE_DIR}/lib/fst4
    ${CMAKE_SOURCE_DIR}/lib/77bit
    ${CMAKE_SOURCE_DIR}/lib/ftrsd
    ${CMAKE_SOURCE_DIR}/lib/superfox
    ${CMAKE_SOURCE_DIR}/lib/superfox/qpc
    ${CMAKE_SOURCE_DIR}/lib/qso50
    ${CMAKE_SOURCE_DIR}/lib/wsprcode
    ${CMAKE_SOURCE_DIR}/lib/wsprd
    ${CMAKE_SOURCE_DIR}/lib/qra/q65
    ${CMAKE_SOURCE_DIR}/lib/qra/qracodes
)

# Boost headers needed for crc14.cpp
if(Boost_FOUND)
    target_include_directories(wsjt_fort PRIVATE ${Boost_INCLUDE_DIRS})
endif()

# BIGSYM=1: RS codec uses int.h (int symbols) instead of char.h
# This is required for init_rs_int/encode_rs_int/decode_rs_int symbols
target_compile_definitions(wsjt_fort PRIVATE BIGSYM=1)

# Legacy C code (Phil Karn RS codec, etc.) needs C89 mode for GCC 15+
# which treats implicit function declarations and type conflicts as errors
if(CMAKE_C_COMPILER_ID MATCHES "GNU")
    target_compile_options(wsjt_fort PRIVATE
        $<$<COMPILE_LANGUAGE:C>:-std=gnu89 -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types>)
endif()

endif() # NOT ANDROID (end of desktop Fortran build)

# ============================================================
# C++ backend library
# ============================================================

# Common sources shared by Android and Desktop
set(BACKEND_SOURCES
    # Audio subsystem (Qt6 ported)
    Audio/AudioDevice.cpp
    Audio/BWFFile.cpp
    Audio/soundin.cpp
    Audio/soundout.cpp

    # Network Audio (WiFi bridge)
    Audio/NetworkAudioInput.cpp
    Audio/NetworkAudioOutput.cpp
    bridge/DiscoveryService.cpp

    # Detector / Modulator
    Detector/Detector.cpp
    Modulator/Modulator.cpp

    # Decoder
    Decoder/decodedtext.cpp

    # Core utilities (no Widgets, no Boost.Log)
    Radio.cpp
    RadioMetaType.cpp
    helper_functions.cpp
    qt_helpers.cpp
    revision_utils.cpp
    TraceFile.cpp
    getfile.cpp
    otpgenerator.cpp
)

if(NOT ANDROID)
    # Desktop-only sources (require Qt Widgets, Boost.Log, etc.)
    list(APPEND BACKEND_SOURCES
        # Network
        Network/Cloudlog.cpp
        Network/FileDownload.cpp
        Network/FoxVerifier.cpp
        Network/LotWUsers.cpp
        Network/MessageClient.cpp
        Network/NetworkAccessManager.cpp
        Network/NetworkMessage.cpp
        Network/NetworkServerLookup.cpp
        Network/NtpClient.cpp
        Network/PSKReporter.cpp
        Network/wsprnet.cpp

        # Models
        models/Bands.cpp
        models/CabrilloLog.cpp
        models/DecodeHighlightingModel.cpp
        models/FoxLog.cpp
        models/FrequencyList.cpp
        models/IARURegions.cpp
        models/Modes.cpp
        models/StationList.cpp

        # Logbook
        logbook/AD1CCty.cpp
        logbook/countriesworked.cpp
        logbook/logbook.cpp
        logbook/Multiplier.cpp
        logbook/WorkedBefore.cpp

        # Validators
        validators/CallsignValidator.cpp
        validators/LiveFrequencyValidator.cpp
        validators/MaidenheadLocatorValidator.cpp

        # Item delegates
        item_delegates/CallsignDelegate.cpp
        item_delegates/CandidateKeyFilter.cpp
        item_delegates/ForeignKeyDelegate.cpp
        item_delegates/FrequencyDelegate.cpp
        item_delegates/FrequencyDeltaDelegate.cpp
        item_delegates/MaidenheadLocatorDelegate.cpp
        item_delegates/MessageItemDelegate.cpp
        item_delegates/SQLiteDateTimeDelegate.cpp

        # Transceiver
        Transceiver/Transceiver.cpp
        Transceiver/TransceiverBase.cpp
        Transceiver/TransceiverFactory.cpp
        Transceiver/PollingTransceiver.cpp
        # Transceiver/HamlibTransceiver.cpp  # requires hamlib, added conditionally below
        Transceiver/HRDTransceiver.cpp
        Transceiver/DXLabSuiteCommanderTransceiver.cpp
        Transceiver/EmulateSplitTransceiver.cpp
        Transceiver/TCITransceiver.cpp

        # SampleDownloader
        SampleDownloader/Directory.cpp
        SampleDownloader/DirectoryDelegate.cpp
        SampleDownloader/FileNode.cpp
        SampleDownloader/RemoteFile.cpp

        # Top-level backend (desktop)
        Configuration.cpp
        Logger.cpp
        MetaDataRegistry.cpp
        MultiSettings.cpp
        GetUserId.cpp
        NonInheritingProcess.cpp
        killbyname.cpp
        L10nLoader.cpp
        WFPalette.cpp
        DisplayManual.cpp
        # EqualizationToolsDialog.cpp  # requires qcustomplot, disabled

        # Widgets with painting logic
        widgets/plotter.cpp
        widgets/meterwidget.cpp
        widgets/signalmeter.cpp
        widgets/displaytext.cpp
    )
endif()

# Add OmniRig on Windows
if(WIN32 AND NOT ANDROID)
    list(APPEND BACKEND_SOURCES Transceiver/OmniRigTransceiver.cpp)
endif()

add_library(wsjt_backend STATIC ${BACKEND_SOURCES})
target_include_directories(wsjt_backend PUBLIC
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/Audio
    ${CMAKE_SOURCE_DIR}/Detector
    ${CMAKE_SOURCE_DIR}/Modulator
    ${CMAKE_SOURCE_DIR}/Network
    ${CMAKE_SOURCE_DIR}/models
    ${CMAKE_SOURCE_DIR}/logbook
    ${CMAKE_SOURCE_DIR}/Decoder
    ${CMAKE_SOURCE_DIR}/Transceiver
    ${CMAKE_SOURCE_DIR}/validators
    ${CMAKE_SOURCE_DIR}/item_delegates
    ${CMAKE_SOURCE_DIR}/SampleDownloader
    ${CMAKE_SOURCE_DIR}/widgets
    ${CMAKE_SOURCE_DIR}/contrib
)

if(HAMLIB_FOUND)
    target_sources(wsjt_backend PRIVATE Transceiver/HamlibTransceiver.cpp)
    if(TARGET PkgConfig::HAMLIB)
        target_link_libraries(wsjt_backend PUBLIC PkgConfig::HAMLIB)
    else()
        target_include_directories(wsjt_backend PUBLIC ${HAMLIB_INCLUDE_DIRS})
        target_link_libraries(wsjt_backend PUBLIC ${HAMLIB_LIBRARIES})
    endif()
    target_compile_definitions(wsjt_backend PUBLIC HAVE_HAMLIB)
endif()

if(ANDROID)
    target_link_libraries(wsjt_backend PUBLIC
        Qt6::Core Qt6::Gui Qt6::Multimedia
        Qt6::Sql Qt6::Network Qt6::WebSockets Qt6::Svg
    )
else()
    target_link_libraries(wsjt_backend PUBLIC
        Qt6::Core Qt6::Gui Qt6::Multimedia Qt6::SerialPort
        Qt6::Sql Qt6::Network Qt6::WebSockets Qt6::Svg
        Qt6::Widgets
    )
endif()

if(Boost_FOUND)
    target_link_libraries(wsjt_backend PUBLIC Boost::log_setup Boost::log)
endif()

if(WIN32 AND TARGET Qt6::AxContainer)
    target_link_libraries(wsjt_backend PUBLIC Qt6::AxContainer)
endif()

if(FFTW3_FOUND)
    target_link_libraries(wsjt_backend PUBLIC ${FFTW3_LIBRARIES})
    target_include_directories(wsjt_backend PUBLIC ${FFTW3_INCLUDE_DIRS})
elseif(FFTW3F_FOUND)
    target_link_libraries(wsjt_backend PUBLIC ${FFTW3F_LIBRARIES})
endif()

# ============================================================
# QML Resources
# ============================================================
qt6_add_resources(QML_RESOURCES qml.qrc)

# ============================================================
# Decodium3 Application
# ============================================================
set(APP_SOURCES
    main.cpp

    # Controllers (bridge QML <-> Backend)
    controllers/AppController.cpp
    controllers/RadioController.cpp
    controllers/DecoderController.cpp
    controllers/AudioController.cpp
    controllers/TxController.cpp
    controllers/LogController.cpp
    controllers/WaterfallController.cpp
    controllers/DecodeListModel.cpp

    # QML items
    qmlitems/WaterfallItem.cpp

    ${QML_RESOURCES}
)

add_executable(decodium3 ${APP_SOURCES})

target_include_directories(decodium3 PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/controllers
    ${CMAKE_SOURCE_DIR}/qmlitems
)

target_link_libraries(decodium3 PRIVATE
    wsjt_backend
    -Wl,--start-group wsjt_fort -Wl,--end-group
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Qml
    Qt6::Gui
    Qt6::Core
)

# Android-specific configuration
if(ANDROID)
    target_link_libraries(decodium3 PRIVATE android_compat fftw3f gfortran)
    # libgfortran.a from ARM GNU Toolchain lacks -fPIC;
    # allow text relocations (OK for minSdk 24, blocked only from API 31+)
    target_link_options(decodium3 PRIVATE "LINKER:-z,notext")
    set_target_properties(decodium3 PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_SOURCE_DIR}/android"
        QT_ANDROID_MIN_SDK_VERSION 24
        QT_ANDROID_TARGET_SDK_VERSION 34
    )
endif()

# Windows-specific libraries
if(WIN32)
    target_link_libraries(decodium3 PRIVATE ws2_32 winmm)
    target_link_libraries(wsjt_fort PRIVATE ws2_32)
endif()

# OpenMP for decoder (used by decoder.f90 multi-threaded decode)
find_package(OpenMP QUIET)
if(OpenMP_Fortran_FOUND AND NOT ANDROID)
    target_link_libraries(wsjt_fort PUBLIC OpenMP::OpenMP_Fortran)
elseif(NOT ANDROID)
    # Fallback: link gomp directly for MinGW
    target_link_libraries(decodium3 PRIVATE -lgomp)
endif()

# ============================================================
# Install
# ============================================================
install(TARGETS decodium3 RUNTIME DESTINATION bin)

# ============================================================
# Version info
# ============================================================
target_compile_definitions(decodium3 PRIVATE
    DECODIUM_VERSION="${PROJECT_VERSION}"
    DECODIUM_NAME="Decodium 3 FT2"
)
target_compile_definitions(wsjt_backend PRIVATE
    DECODIUM_VERSION="${PROJECT_VERSION}"
    WSJT_RIG_NONE_CAN_SPLIT=0
    WSJT_SSID_NONE=0
    WSJT_STANDARD_FILE_LOCATIONS=1
)
