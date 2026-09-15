if(NOT TARGET SDL3::SDL3-shared)
    return()
endif()

# Piped MCP (Model Context Protocol) stdio implementation
add_library(piped_mcp STATIC)

target_sources(
    piped_mcp
    PRIVATE
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
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    COMPONENT development
)

install(
    FILES mcp_server.hpp
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/piped_mcp
    COMPONENT development
)
