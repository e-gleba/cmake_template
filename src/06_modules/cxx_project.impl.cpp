// Module implementation unit of "cxx_project".
//
// No "export": the unit implicitly imports the primary module interface
// and contributes definitions only. Plain .cpp extension on purpose —
// some compilers treat module-style extensions (.cppm/.ixx) as interface
// units. And the declaration must be "module cxx_project;": writing
// "module cxx_project:part;" here would declare an internal partition,
// which only MSVC accepts — CMake errors on it with other compilers.
//
// Ref: https://cmake.org/cmake/help/latest/manual/cmake-cxxmodules.7.html

module; // global module fragment

#include <format>
#include <string>

module cxx_project;

namespace cxx_project {

std::string describe(const version_info& version)
{
    return std::format("{}.{}.{}", version.major, version.minor,
                       version.patch);
}

} // namespace cxx_project
