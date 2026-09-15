if(NOT TARGET SDL3::SDL3-shared)
    return()
endif()

if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    add_library(piped_mcp SHARED)
else()
    add_executable(piped_mcp)
endif()

target_sources(
    piped_mcp
    PRIVATE
        main.cpp
        mcp_server.cpp
    PRIVATE
        FILE_SET HEADERS
        FILES mcp_server.hpp
)

target_compile_features(piped_mcp PRIVATE cxx_std_23)

target_link_libraries(
    piped_mcp
    PRIVATE
        SDL3::SDL3-shared
        Microsoft.GSL::GSL
        warnings
)

target_link_options(
    piped_mcp PRIVATE
    "$<$<AND:$<PLATFORM_ID:Windows>,$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>,$<CXX_COMPILER_FRONTEND_VARIANT:GNU>>:$<LINK_ONLY:-static>>"
)

if(CMAKE_SYSTEM_NAME MATCHES "Android|Emscripten")
    return()
endif()

install(
    TARGETS piped_mcp
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    COMPONENT runtime
)

set_target_properties(
    piped_mcp
    PROPERTIES
        INSTALL_RPATH "$<IF:$<PLATFORM_ID:Darwin,iOS>,@executable_path,$ORIGIN>/../${CMAKE_INSTALL_LIBDIR}"
        BUILD_RPATH_USE_ORIGIN ON
)

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    add_custom_command(
        TARGET piped_mcp
        POST_BUILD
        COMMAND
            ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:piped_mcp>
            $<TARGET_RUNTIME_DLLS:piped_mcp>
        COMMAND_EXPAND_LISTS
    )
endif()
