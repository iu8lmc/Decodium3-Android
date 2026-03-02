cmake_minimum_required(VERSION 3.16)
project(DecodiumBridge VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core Multimedia Network WebSockets)

# Hamlib (optional)
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

add_executable(decodium_bridge
    main.cpp
    BridgeServer.cpp
    AudioCapture.cpp
    AudioPlayback.cpp
    CatRelay.cpp
    DiscoveryService.cpp
)

target_link_libraries(decodium_bridge PRIVATE
    Qt6::Core
    Qt6::Multimedia
    Qt6::Network
    Qt6::WebSockets
)

if(HAMLIB_FOUND)
    if(TARGET PkgConfig::HAMLIB)
        target_link_libraries(decodium_bridge PRIVATE PkgConfig::HAMLIB)
    else()
        target_include_directories(decodium_bridge PRIVATE ${HAMLIB_INCLUDE_DIRS})
        target_link_libraries(decodium_bridge PRIVATE ${HAMLIB_LIBRARIES})
    endif()
    target_compile_definitions(decodium_bridge PRIVATE HAVE_HAMLIB)
endif()

install(TARGETS decodium_bridge RUNTIME DESTINATION bin)
