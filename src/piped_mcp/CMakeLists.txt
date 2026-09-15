if(NOT TARGET SDL3::SDL3-shared)
    return()
endif()

# Piped MCP (Model Context Protocol) stdio implementation
add_executable(piped_mcp)

target_sources(
    piped_mcp
    PRIVATE
        main.cpp
        mcp_server.hpp
        mcp_server.cpp
)

target_compile_features(piped_mcp PRIVATE cxx_std_23)

target_link_libraries(
    piped_mcp
    PRIVATE
        SDL3::SDL3-shared
        Microsoft.GSL::GSL
        warnings
)

# Install rules
install(
    TARGETS piped_mcp
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    COMPONENT runtime
)

# ── RPATH: find libSDL3 at runtime after install ──
set_target_properties(
    piped_mcp
    PROPERTIES
        INSTALL_RPATH "$<IF:$<PLATFORM_ID:Darwin,iOS>,@executable_path,$ORIGIN>/../${CMAKE_INSTALL_LIBDIR}"
        BUILD_RPATH_USE_ORIGIN ON
)

# Windows: stage runtime DLLs next to the .exe for build-tree runs
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
