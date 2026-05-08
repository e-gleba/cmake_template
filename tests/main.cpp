#include <functional>
#include <print>
#include <ranges>
#include <span>

// Enable doctest introspection
#define DOCTEST_CONFIG_IMPLEMENT
#include <doctest/doctest.h>

int main(int argc, char* argv[], char* envp[])
{
    std::println("-- doctest runner --");
    std::println("argc: {}", argc);

    std::println("argv:");
    for (std::size_t i = 0;
         auto*       s : std::span{ argv, static_cast<std::size_t>(argc) }) {
        std::println("  [{:>2}] {}", i++, s);
    }

    std::println("envp (first 10 non-null):");
    for (std::size_t i = 0;
         auto*       e :
         std::span{ envp, 10 } | std::views::take_while(std::identity{})) {
        std::println("  [{:>2}] {}", i++, e);
    }

    doctest::Context ctx{ argc, argv };
    ctx.setOption("duration", true);

    return ctx.run();
}

namespace egleba::doctest {
    [[nodiscard]] auto get_all_tests() -> std::set<std::string> {
        const std::set<::doctest::detail::TestCase> &registered =
                ::doctest::detail::getRegisteredTests();

        auto names = registered | std::views::transform([](const auto &tc) {
            return std::string{tc.m_name};
        });

#if __cplusplus >= 202302L
        return std::ranges::to<std::set>(names);
#else
        return { std::ranges::begin(names), std::ranges::end(names) };
#endif
    }
}
