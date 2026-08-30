module;

#include <format>
#include <string>

module cxx_project.math;

namespace cxx_project
{
std::string to_string(const version& value)
{
    return std::format("{}.{}.{}", value.major, value.minor, value.patch);
}
} // namespace cxx_project
