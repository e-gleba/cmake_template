if(NOT TARGET SDL3::SDL3-shared)
    return()
endif()

ct_add_executable(03_unity_build)

target_sources(03_unity_build PRIVATE greet.cpp main.cpp)

target_link_libraries(03_unity_build PRIVATE SDL3::SDL3-shared
                                             Microsoft.GSL::GSL warnings)
target_compile_features(03_unity_build PRIVATE cxx_std_23)

# ── Unity build: the whole point of this project ─────────────────────
# Batch size 0 = merge ALL sources into one translation unit.
set_target_properties(03_unity_build PROPERTIES UNITY_BUILD ON
                                                UNITY_BUILD_BATCH_SIZE 0)
