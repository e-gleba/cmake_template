#include "main.h"

// Enable doctest introspection
#define DOCTEST_CONFIG_IMPLEMENT
#include <doctest/doctest.h>

[[nodiscard]] std::set<std::string> get_all_tests()
{
    std::set<std::string> names;
    for (const auto& test : doctest::detail::getRegisteredTests())
    {
        names.insert(test.m_name);
    }
    return names;
}

int main()
{
    doctest::Context ctx;
    ctx.setOption("duration", true);

    return ctx.run();
}
