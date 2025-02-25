#
# Minilua build tool
#
add_executable(LuaJIT_minilua "${CMAKE_CURRENT_SOURCE_DIR}/host/minilua.c")

target_compile_definitions(LuaJIT_minilua PRIVATE LUAJIT_COMPILE_DEFS)

set_target_properties(LuaJIT_minilua PROPERTIES
        OUTPUT_NAME "minilua"
        ARCHIVE_OUTPUT_DIRECTORY        "${CMAKE_BINARY_DIR}/luajit"
        LIBRARY_OUTPUT_DIRECTORY        "${CMAKE_BINARY_DIR}/luajit"
        RUNTIME_OUTPUT_DIRECTORY        "${CMAKE_BINARY_DIR}/luajit"
        PDB_OUTPUT_DIRECTORY            "${CMAKE_BINARY_DIR}/luajit"
        COMPILE_PDB_OUTPUT_DIRECTORY    "${CMAKE_BINARY_DIR}/luajit")

if (UNIX)
    target_link_libraries(LuaJIT_minilua PUBLIC m dl)
endif()

#
# Host DASC compilation
#
add_custom_command(OUTPUT ${LuaJIT_HOST_DIR}/buildvm_arch.h
        COMMAND LuaJIT_minilua "${LuaJIT_DYNASM_DIR}/dynasm.lua" -LN ${LUAJIT_DASM_FLAGS} -o "${LuaJIT_HOST_DIR}/buildvm_arch.h" "${CMAKE_CURRENT_SOURCE_DIR}/${LuaJIT_DASC}"
        DEPENDS LuaJIT_minilua
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Running dynasm.lua..."
        VERBATIM
)

add_custom_target(LuaJIT_DynASM
        DEPENDS ${LuaJIT_HOST_DIR}/buildvm_arch.h
)

#
# Version Generation
#

# TODO: Make this compile-time, not gen-time
# TODO: Handle cases where git isn't shipped as part of this?

add_custom_command(OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/luajit.h
        COMMAND ${CMAKE_COMMAND} -D SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR} -P ${CMAKE_CURRENT_SOURCE_DIR}/generate_version.cmake
        COMMAND LuaJIT_minilua "${LuaJIT_HOST_DIR}/genversion.lua"
        DEPENDS LuaJIT_minilua
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMENT "Running genversion.lua..."
        VERBATIM
)

add_custom_target(LuaJIT_GenVersion
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/luajit.h
)

#
# buildvm Tool
#
file(GLOB_RECURSE LuaJIT_BuildVM_SRCS
        "${CMAKE_CURRENT_SOURCE_DIR}/host/buildvm*.c"
)

add_executable(LuaJIT_BuildVM ${LuaJIT_BuildVM_SRCS})

target_include_directories(LuaJIT_BuildVM PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${LuaJIT_DYNASM_DIR})

set_target_properties(LuaJIT_BuildVM PROPERTIES
        OUTPUT_NAME "buildvm"
        ARCHIVE_OUTPUT_DIRECTORY        "${CMAKE_BINARY_DIR}/luajit"
        LIBRARY_OUTPUT_DIRECTORY        "${CMAKE_BINARY_DIR}/luajit"
        RUNTIME_OUTPUT_DIRECTORY        "${CMAKE_BINARY_DIR}/luajit"
        PDB_OUTPUT_DIRECTORY            "${CMAKE_BINARY_DIR}/luajit"
        COMPILE_PDB_OUTPUT_DIRECTORY    "${CMAKE_BINARY_DIR}/luajit")

add_dependencies(LuaJIT_BuildVM LuaJIT_GenVersion LuaJIT_DynASM)

#
# buildvm
#
set(LuaJIT_ALL_LIB lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c lib_buffer.c)

function(add_buildvm_command)
    cmake_parse_arguments(BuildVM "" "MODE;OUTPUT" "INPUTS" ${ARGN})

    add_custom_command(
            OUTPUT ${CMAKE_CURRENT_SOURCE_DIR}/${BuildVM_OUTPUT}
            COMMAND LuaJIT_BuildVM -m ${BuildVM_MODE} -o "${CMAKE_CURRENT_SOURCE_DIR}/${BuildVM_OUTPUT}" ${BuildVM_INPUTS}
            DEPENDS LuaJIT_BuildVM LuaJIT_GenVersion
            COMMENT "Running buildvm on ${BuildVM_OUTPUT}..."
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            VERBATIM
    )

    set(BuildVM_GENERATED_FILES "${CMAKE_CURRENT_SOURCE_DIR}/${BuildVM_OUTPUT}" ${BuildVM_GENERATED_FILES} PARENT_SCOPE)
endfunction()

if (WIN32)
    add_buildvm_command(MODE peobj OUTPUT lj_vm.obj)
elseif(APPLE)
    add_buildvm_command(MODE machasm OUTPUT lj_vm.S)
elseif(UNIX AND NOT APPLE)
    add_buildvm_command(MODE elfasm OUTPUT lj_vm.S)
else()
    message(FATAL "Unknown platform, not UNIX, APPLE, or WIN32!")
endif()

add_buildvm_command(MODE bcdef OUTPUT lj_bcdef.h INPUTS ${LuaJIT_ALL_LIB})
add_buildvm_command(MODE ffdef OUTPUT lj_ffdef.h INPUTS ${LuaJIT_ALL_LIB})
add_buildvm_command(MODE libdef OUTPUT lj_libdef.h INPUTS ${LuaJIT_ALL_LIB})
add_buildvm_command(MODE recdef OUTPUT lj_recdef.h INPUTS ${LuaJIT_ALL_LIB})
add_buildvm_command(MODE vmdef OUTPUT jit/vmdef.h INPUTS ${LuaJIT_ALL_LIB})
add_buildvm_command(MODE folddef OUTPUT lj_folddef.h INPUTS lj_opt_fold.c)

add_custom_target(LuaJIT_BuildVM_Generation
        DEPENDS ${BuildVM_GENERATED_FILES}
)

#
# LuaJIT shared and static libraries
#

if (LuaJIT_AMALGAM)
    list(APPEND LuaJIT_LIB_SRCS "ljamalg.c")
else()
    file(GLOB_RECURSE LuaJIT_LIB_SRCS
            "${CMAKE_CURRENT_SOURCE_DIR}/lj_*.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/lib_*.c"
    )
endif()

# Handles case where gen-files aren't ready yet but needed
list(APPEND LuaJIT_LIB_SRCS ${BuildVM_GENERATED_FILES})
list(REMOVE_DUPLICATES LuaJIT_LIB_SRCS)

if (LuaJIT_STATIC)
    add_library(LuaJIT STATIC ${LuaJIT_LIB_SRCS})
else()
    add_library(LuaJIT SHARED ${LuaJIT_LIB_SRCS})

    if (WIN32)
        target_compile_definitions(LuaJIT PUBLIC "LUA_BUILD_AS_DLL")
    endif()
endif()

if (UNIX AND NOT APPLE) # Sorry - This is naive but honestly I cba to replicate the step atm :(
    target_compile_definitions(LuaJIT PUBLIC "LUAJIT_UNWIND_EXTERNAL")
endif()

add_dependencies(LuaJIT LuaJIT_BuildVM_Generation)
set_target_properties(LuaJIT PROPERTIES OUTPUT_NAME ${LuaJIT_LIB_NAME} PREFIX "")

target_include_directories(LuaJIT PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

if (UNIX AND NOT APPLE)
    target_compile_options(LuaJIT PUBLIC "-fPIC")
    target_link_libraries(LuaJIT PRIVATE "m" "dl")
endif()

#
# LuaJIT runtime
#
add_executable(LuaJIT_app "luajit.c")

target_link_libraries(LuaJIT_app LuaJIT)

set_target_properties(LuaJIT_app PROPERTIES OUTPUT_NAME "luajit")
