#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

auto probe_exceptions() -> std::string
{
    // Throw + catch forces real unwind tables, so the link actually
    // depends on the toolchain's unwinder (libgcc_s vs libunwind) and
    // C++ ABI lib (libstdc++ vs libc++abi). A bare
    // std::cout-only binary can hide a broken runtime setup.
    try {
        throw std::runtime_error{ "unwind-probe" };
    } catch (std::runtime_error const& caught) {
        return caught.what();
    }
}

} // namespace

auto main() -> int
{
    std::vector<int> values{ 3, 1, 2 };
    std::cout << "rt_demo size=" << values.size()
              << " probe=" << probe_exceptions() << '\n';
#if defined(_LIBCPP_VERSION)
    std::cout << "stdlib=libc++ " << _LIBCPP_VERSION << '\n';
#elif defined(__GLIBCXX__)
    std::cout << "stdlib=libstdc++\n";
#else
    std::cout << "stdlib=unknown\n";
#endif
    std::cout << "compiler=" << __VERSION__ << '\n';
    return 0;
}
