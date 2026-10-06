module;

#include <concepts>
#include <cstdint>

export module cxx_project.math:operations;

export namespace cxx_project
{
template <typename type>
concept number = std::integral<type> || std::floating_point<type>;

template <number type>
[[nodiscard]] constexpr type clamp(type value, type lower, type upper) noexcept
{
    return value < lower ? lower : (upper < value ? upper : value);
}

[[nodiscard]] constexpr std::uint64_t fibonacci(std::uint32_t count) noexcept
{
    std::uint64_t previous{};
    std::uint64_t current{1};

    for (std::uint32_t index{}; index < count; ++index) {
        const std::uint64_t next{previous + current};
        previous = current;
        current = next;
    }

    return previous;
}
} // namespace cxx_project
