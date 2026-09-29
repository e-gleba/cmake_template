#include "rt_build_info.hpp"

#include <format>
#include <iostream>
#include <ranges>
#include <stdexcept>
#include <string>
#include <string_view>
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

void print_status()
{
    std::vector<int> values{ 3, 1, 2 };
    std::cout << std::format("name={}\n", rt::k_name);
    std::cout << std::format("version={}\n", rt::k_project_version);
    std::cout << std::format("vector_size={}\n", values.size());
    std::cout << std::format("unwind_probe={}\n", probe_exceptions());
#if defined(_LIBCPP_VERSION)
    std::cout << std::format("stdlib=libc++ {}\n", _LIBCPP_VERSION);
#elif defined(__GLIBCXX__)
    std::cout << "stdlib=libstdc++\n";
#else
    std::cout << "stdlib=unknown\n";
#endif
    std::cout << std::format("compiler={}\n", __VERSION__);
    std::cout << std::format("compiler_id={}\n", rt::k_cxx_compiler_id);
    std::cout << std::format("compiler_version={}\n",
                             rt::k_cxx_compiler_version);
    std::cout << std::format("compiler_path={}\n", rt::k_cxx_compiler);
    std::cout << std::format("build_type={}\n", rt::k_build_type);
    std::cout << std::format("system={}\n", rt::k_system);
    std::cout << std::format("arch={}\n", rt::k_arch);
    std::cout << std::format("cxx_standard={}\n", __cplusplus);
    std::cout << std::format("cmake={}\n", rt::k_cmake_version);
    std::cout << std::format("generator={}\n", rt::k_generator);
    std::cout << std::format("linker={}\n", rt::k_linker);
    std::cout << std::format("linker_version={}\n", rt::k_linker_version);
#ifdef __clang__
    std::cout << std::format("clang_version={}.{}.{}\n",
                             __clang_major__,
                             __clang_minor__,
                             __clang_patchlevel__);
#endif
#ifdef __GNUC__
    std::cout << std::format("gnuc_version={}.{}.{}\n",
                             __GNUC__,
                             __GNUC_MINOR__,
                             __GNUC_PATCHLEVEL__);
#endif
#ifdef _LIBCPP_ABI_VERSION
    std::cout << std::format("libcxx_abi={}\n", _LIBCPP_ABI_VERSION);
#endif
}

void print_list(std::string_view key, char const* items)
{
    std::string_view const all{ items };
    if (all.empty()) {
        std::cout << std::format("{}_count=0\n", key);
        return;
    }
    auto        parts = all | std::views::split(';');
    std::size_t count{ 0 };
    for ([[maybe_unused]] auto const entry : parts) {
        ++count;
    }
    std::cout << std::format("{}_count={}\n", key, count);
    for (auto const entry : parts) {
        std::cout << std::format(
            "{}={}\n", key, std::string_view{ entry.begin(), entry.end() });
    }
}

void print_version()
{
    print_status();
    print_list("include_dir", rt::k_cxx_implicit_include_dirs);
    print_list("link_dir", rt::k_cxx_implicit_link_dirs);
}

} // namespace

auto main(int argc, char** argv) -> int
{
    for (int i{ 1 }; i < argc; ++i) {
        std::string_view const arg{ argv[i] };
        if (arg == "--version" || arg == "-V") {
            print_version();
            return 0;
        }
    }
    print_status();
    return 0;
}
