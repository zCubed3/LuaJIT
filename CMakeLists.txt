cmake_minimum_required(VERSION 3.20)
project(LuaJIT C ASM)

set(CMAKE_C_STANDARD 99)

#
# Options
#
option(LuaJIT_NOGC64 "Disable LJ_GC64 mode for x64" OFF)
option(LuaJIT_AMALGAM "Amalgamated build" OFF)
option(LuaJIT_STATIC "Static Library" OFF)

message("LuaJIT NoGC64 = ${LuaJIT_NOGC64}")
message("LuaJIT Amalgam = ${LuaJIT_AMALGAM}")
message("LuaJIT Static = ${LuaJIT_STATIC}")

if (WIN32)
    list(APPEND LUAJIT_COMPILE_DEFS
            "_CRT_SECURE_NO_DEPRECATE"
            "_CRT_STDIO_INLINE=__declspec(dllexport)__inline")

    # TODO: This is windows specific, please fix
    set(LUAJIT_DASM_FLAGS "-D" "WIN" "-D" "JIT" "-D" "ENDIAN_LE" "-D" "FPU" "-D" "P64")
endif()

if (CMAKE_SIZEOF_VOID_P EQUAL 8) # 64-bit target

    if (CMAKE_SYSTEM_PROCESSOR STREQUAL "AMD64")
        set(LuaJIT_ARCH "x64")
        set(LuaJIT_DASC "vm_x64.dasc")

        if (NOGC64)
            set(LuaJIT_DASC "vm_x86.dasc")
        endif()
    endif()

    if (CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64")
        set(LuaJIT_ARCH "arm64")
        set(LuaJIT_DASC "vm_arm64.dasc")
    endif()

    # TODO: Support everything else

else()

    # TODO: Support everything other than x86
    if (CMAKE_SYSTEM_PROCESSOR STREQUAL "X86")
        set(LuaJIT_ARCH "x86")
        set(LuaJIT_DASC "vm_x86.dasc")
    endif()

endif()

if (NOT DEFINED LuaJIT_ARCH)
    message(FATAL_ERROR "Unknown ARCH! System processor is ${CMAKE_SYSTEM_PROCESSOR}")
endif()

if (NOT DEFINED LuaJIT_DASC)
    message(FATAL_ERROR "Unknown DASC!")
endif()

set(LuaJIT_LIB_NAME "lua51")
set(LuaJIT_DYNASM_DIR "${CMAKE_CURRENT_SOURCE_DIR}/dynasm")
set(LuaJIT_HOST_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/host")

add_subdirectory(src)

#
# Alias targets
#

add_library(LuaJIT::LuaJIT ALIAS LuaJIT)