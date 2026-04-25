#include "main.hpp"

// Enable doctest introspection
#define DOCTEST_CONFIG_IMPLEMENT
#include <doctest/doctest.h>

#include <algorithm>           // std::ranges::transform
#include <iterator>            // std::inserter
#include <ranges>

[[nodiscard]] auto get_all_tests() -> std::set<std::string> {
    const std::set<doctest::detail::TestCase> &registered = doctest::detail::getRegisteredTests();

    auto names = registered
                 | std::views::transform(
            [](const auto &tc) { return std::string{tc.m_name}; });

#if __cplusplus >= 202302L
    return std::ranges::to<std::set>(names);
#else
    return {std::ranges::begin(names), std::ranges::end(names)};
#endif
}

int main()
{
    doctest::Context ctx;
    ctx.setOption("duration", true);

    return ctx.run();
}
