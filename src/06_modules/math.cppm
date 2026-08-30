module;

#include <cstdint>
#include <string>

export module cxx_project.math;

export import :operations;

export namespace cxx_project
{
struct version final
{
    std::uint32_t major{};
    std::uint32_t minor{};
    std::uint32_t patch{};
};

[[nodiscard]] std::string to_string(const version& value);
} // namespace cxx_project
