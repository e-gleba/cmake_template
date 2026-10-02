#include <build_info.hpp>

#include <cstdlib>
#include <iostream>

int main()
{
    std::cout << tb::build_info::get_build_report() << '\n';
    return std::cout.good() ? EXIT_SUCCESS : EXIT_FAILURE;
}
