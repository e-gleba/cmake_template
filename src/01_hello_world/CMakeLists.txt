add_executable(01_hello_world main.cpp)
target_compile_features(01_hello_world PRIVATE cxx_std_23)
target_link_libraries(01_hello_world PRIVATE warnings)

# Steam depot: no shipped libc++.dll / libunwind.dll. Windows GNU-frontend
# exes only — MSVC / clang-cl (MSVC frontend) and non-Windows never match.
target_link_options(
    01_hello_world PRIVATE
    "$<$<AND:$<PLATFORM_ID:Windows>,$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>,$<C_COMPILER_FRONTEND_VARIANT:GNU>>:$<LINK_ONLY:-static>>")

install(TARGETS 01_hello_world RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                       COMPONENT runtime)
