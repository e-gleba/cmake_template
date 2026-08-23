if(NOT TARGET SDL3::SDL3-shared)
    return()
endif()

if(NOT TARGET Tracy::TracyClient)
    return()
endif()

ct_add_executable(04_tracy_profiler)

target_sources(04_tracy_profiler PRIVATE main.cpp)

target_compile_features(04_tracy_profiler PRIVATE cxx_std_23)
target_link_libraries(
    04_tracy_profiler
    PRIVATE SDL3::SDL3-shared
            Tracy::TracyClient
            Microsoft.GSL::GSL
            warnings)
