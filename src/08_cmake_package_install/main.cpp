#include <build_info.hpp>

#include <cstdlib>
#include <fmt/format.h>

auto main() -> int
{
    try {
        fmt::print("{}\n", tb::build_info::get_build_report());
    } catch (...) {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
