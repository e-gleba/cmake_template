// Consumer of the named modules. "import" loads the compiler-generated
// BMI — no textual inclusion, so macros and include paths from the
// module units never leak into this file. Classic #include and import
// mix freely in one translation unit.

#include <cstdio>
#include <cstdlib>
#include <string>

import cxx_project;
import cxx_project.utility;

// constexpr across the module boundary: these fold at compile time from
// the BMI, proving the exported bodies reached this importer.
static_assert(cxx_project::fibonacci(10) == 55);
static_assert(cxx_project::clamp(42, 0, 100) == 42);
static_assert(cxx_project::clamp(-5, 0, 100) == 0);

int main()
{
    constexpr cxx_project::version_info version{ .major = 1,
                                                 .minor = 0,
                                                 .patch = 0 };

    const std::string text = cxx_project::describe(version);

    std::printf("describe()           = %s\n", text.c_str());
    std::printf("fibonacci(10)        = %llu\n",
                static_cast<unsigned long long>(cxx_project::fibonacci(10)));
    std::printf("clamp(3.5, 0.0, 1.0) = %f\n",
                cxx_project::clamp(3.5, 0.0, 1.0));
    std::printf("encode_version()     = %u\n",
                cxx_project::encode_version(version));

    const bool ok = text == "1.0.0" && cxx_project::fibonacci(10) == 55
                    && cxx_project::clamp(3.5, 0.0, 1.0) == 1.0
                    && cxx_project::encode_version(version) == 10000U;

    // flush both stdio buffers before checking for write errors
    std::fflush(stdout);
    if (!ok || std::ferror(stdout) != 0) {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
