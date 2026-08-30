if(NOT CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
    return()
endif()
# WebAssembly deploy target - SDL3 + OpenGL (WebGL2) + Dear ImGui demo.

add_executable(05_webassembly main.cpp)
set_target_properties(05_webassembly PROPERTIES SUFFIX ".html")
target_compile_features(05_webassembly PRIVATE cxx_std_23)

target_link_libraries(
    05_webassembly
    PRIVATE warnings
            SDL3::SDL3-static
            ct::imgui_sdl3_opengl3
            Microsoft.GSL::GSL)

target_link_options(
    05_webassembly
    PRIVATE
    "SHELL:--shell-file ${CMAKE_CURRENT_LIST_DIR}/shell.html"
    -sUSE_WEBGL2=1
    -sMIN_WEBGL_VERSION=2
    -sMAX_WEBGL_VERSION=2
    -sFULL_ES3=1
    -sALLOW_MEMORY_GROWTH=1
    "$<$<CONFIG:Debug>:-sASSERTIONS=2>"
    "$<$<CONFIG:Debug>:-sGL_ASSERTIONS=1>")
