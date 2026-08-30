// Module interface partition "cxx_project:math".
//
// Partitions split one module into focused units. A partition is visible
// only inside its own module unless the primary interface unit
// re-exports it — see "export import :math;" in cxx_project.cppm.
//
// Ref: https://en.cppreference.com/w/cpp/language/modules

module; // global module fragment: only preprocessor directives may appear

#include <cstdint>
#include <type_traits>

export module cxx_project:math;

namespace cxx_project {

// Concepts export like any other declaration: the constraint travels
// with the template through the BMI to every importer.
export template <typename T>
concept arithmetic = std::is_arithmetic_v<T>;

export template <arithmetic T>
[[nodiscard]] constexpr T clamp(T value, T lo, T hi) noexcept
{
    return value < lo ? lo : (hi < value ? hi : value);
}

// constexpr in an interface unit: importers constant-fold calls straight
// from the BMI (see the static_asserts in main.cpp).
export [[nodiscard]] constexpr std::uint64_t fibonacci(
    std::uint32_t n) noexcept
{
    std::uint64_t prev{ 0 };
    std::uint64_t cur{ 1 };
    for (std::uint32_t i{ 0 }; i < n; ++i) {
        const std::uint64_t next = prev + cur;
        prev = cur;
        cur  = next;
    }
    return prev;
}

} // namespace cxx_project
