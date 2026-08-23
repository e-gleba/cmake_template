add_executable(01_hello_world main.cpp)
target_compile_features(01_hello_world PRIVATE cxx_std_23)
target_link_libraries(01_hello_world PRIVATE warnings)

install(TARGETS 01_hello_world RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                       COMPONENT runtime)
