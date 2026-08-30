# Opt-in C++20 named modules demo (issue #5). Entered only when
# configured with -DCMAKE_CXX_USE_MODULES=ON — keeps module scanning
# costs and toolchain requirements out of default builds.
if(NOT CMAKE_CXX_USE_MODULES)
    return()
endif()

add_executable(06_modules)

# The root project sets CMAKE_CXX_SCAN_FOR_MODULES=OFF (no modules = no
# scan cost). This target opts back in: scanning is what orders BMI
# compilation of the units below before main.cpp imports them.
set_target_properties(06_modules PROPERTIES CXX_SCAN_FOR_MODULES ON)

# Plain sources: the module implementation unit (cxx_project.impl.cpp)
# and the consumer (main.cpp). Keep module-style extensions (.cppm/.ixx)
# off implementation units — some compilers treat them as interface
# units, which breaks the build.
target_sources(06_modules PRIVATE main.cpp cxx_project.impl.cpp)

# Module-providing sources must live in a FILE_SET of type CXX_MODULES —
# the file set, not the extension, marks a unit as a module interface.
target_sources(
    06_modules
    PRIVATE FILE_SET CXX_MODULES
            FILES cxx_project.cppm cxx_project-math.cppm
                  cxx_project.utility.cppm)

target_compile_features(06_modules PRIVATE cxx_std_23)
target_link_libraries(06_modules PRIVATE warnings)

install(TARGETS 06_modules RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
                                 COMPONENT runtime)
