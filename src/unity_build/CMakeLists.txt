add_executable(unity_test app.cpp greet.cpp)

target_link_libraries(
    unity_test PRIVATE SDL3::SDL3-shared Microsoft.GSL::GSL warnings
)
target_compile_features(unity_test PRIVATE cxx_std_23)

# ── Unity build: the whole point of this project ─────────────────────
# Batch size 0 = merge ALL sources into one translation unit.
set_target_properties(unity_test PROPERTIES UNITY_BUILD ON
                                            UNITY_BUILD_BATCH_SIZE 0)
