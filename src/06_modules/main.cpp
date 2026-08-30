#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <string>

import cxx_project.math;

static_assert(cxx_project::fibonacci(10) == 55);
static_assert(cxx_project::clamp(42, 0, 100) == 42);

int main()
{
    constexpr cxx_project::version value{
        .major = 1,
        .minor = 2,
        .patch = 3,
    };

    const std::string text{cxx_project::to_string(value)};
    const bool features_work = text == "1.2.3"
                               && cxx_project::fibonacci(10) == 55
                               && cxx_project::clamp(150, 0, 100) == 100;

    std::cout << "C++ modules: " << text << '\n';
    return features_work && std::cout.good() ? EXIT_SUCCESS : EXIT_FAILURE;
}
