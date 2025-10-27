set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

# set(TOOLCHAIN_ROOT "/opt/codex/rm2/4.0.117-1")

# set(TOOLCHAIN_ROOT "/opt/codex/rm11x/3.1.2")

if(NOT DEFINED ENV{TOOLCHAIN_ROOT})
  set(TOOLCHAIN_ROOT "/opt/codex/rm2/5.0.58-dirty")
else()
  set(TOOLCHAIN_ROOT $ENV{TOOLCHAIN_ROOT})
endif()
message(STATUS "Toolchain root: ${TOOLCHAIN_ROOT}")

set(CMAKE_SYSROOT
    "${TOOLCHAIN_ROOT}/sysroots/cortexa7hf-neon-remarkable-linux-gnueabi")

set(ENV{PKG_CONFIG_DIR} "")
set(ENV{PKG_CONFIG_LIBDIR}
    "${CMAKE_SYSROOT}/usr/lib/pkgconfig:${CMAKE_SYSROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} ${CMAKE_SYSROOT})

set(host_root "${TOOLCHAIN_ROOT}/sysroots/x86_64-codexsdk-linux")
set(triple "arm-remarkable-linux-gnueabi")
set(tools "${host_root}/usr/bin/${triple}")
set(prefix "${tools}/${triple}-")

set(PKG_CONFIG_EXECUTABLE "${host_root}/usr/bin/pkg-config")

set(CMAKE_C_COMPILER "${prefix}gcc")
set(CMAKE_C_COMPILER_AR "${prefix}gcc-ar")
set(CMAKE_C_COMPILER_RANLIB "${prefix}gcc-ranlib")
set(CMAKE_C_COMPILER_ARG1
    "-mfpu=neon -mfloat-abi=hard -mcpu=cortex-a7 -D_TIME_BITS=64 -D_FILE_OFFSET_BITS=64"
)

set(CMAKE_CXX_COMPILER "${prefix}g++")
set(CMAKE_CXX_COMPILER_AR "${prefix}gcc-ar")
set(CMAKE_CXX_COMPILER_RANLIB "${prefix}gcc-ranlib")
set(CMAKE_CXX_COMPILER_ARG1
    "-mfpu=neon -mfloat-abi=hard -mcpu=cortex-a7 -D_TIME_BITS=64 -D_FILE_OFFSET_BITS=64"
)

set(CMAKE_ADDR2LINE "${prefix}addr2line")
set(CMAKE_AR "${prefix}ar")
set(CMAKE_NM "${prefix}nm")
set(CMAKE_OBJCOPY "${prefix}objcopy")
set(CMAKE_OBJDUMP "${prefix}objdump")
set(CMAKE_RANLIB "${prefix}ranlib")
set(CMAKE_READELF "${prefix}readelf")
set(CMAKE_STRIP "${prefix}strip")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
set(CMAKE_INSTALL_RPATH "${OPT_PREFIX}lib")
