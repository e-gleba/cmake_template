// Consumer of the named modules. "import" loads the compiler-generated
// BMI - no textual inclusion, so macros and include paths from the
// module units never leak into this file. Classic #include (SDL3 below)
// and import mix freely in one translation unit.

#include <SDL3/SDL.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <type_traits>

import cxx_project;
import cxx_project.utility;

// constexpr across the module boundary: these fold at compile time from
// the BMI, proving the exported bodies reached this importer.
static_assert(cxx_project::fibonacci(10) == 55);
static_assert(cxx_project::clamp(42, 0, 100) == 42);
static_assert(cxx_project::clamp(-5, 0, 100) == 0);

namespace {

// gsl::finally, ten lines: runs f at scope exit, whatever the path.
template <typename F>
struct [[nodiscard]] scope_exit final
{
    F f;
    scope_exit(const scope_exit&)            = delete;
    scope_exit& operator=(const scope_exit&) = delete;
    ~scope_exit() noexcept(std::is_nothrow_invocable_v<F>) { f(); }
};
template <typename F>
scope_exit(F) -> scope_exit<F>;

// SDL3 hello world: a window titled from the module, cleared to a color
// fed by module math. Returns false when no display exists (headless
// CI), so main falls back to plain CLI output.
[[nodiscard]] bool run_window(const std::string& title)
{
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        return false;
    }
    const auto quit_sdl = scope_exit{ &SDL_Quit };

    auto* window = SDL_CreateWindow(title.c_str(), 640, 360, 0);
    if (window == nullptr) {
        return false;
    }
    const auto destroy_window =
        scope_exit{ [&] { SDL_DestroyWindow(window); } };

    auto* renderer = SDL_CreateRenderer(window, nullptr);
    if (renderer == nullptr) {
        return false;
    }
    const auto destroy_renderer =
        scope_exit{ [&] { SDL_DestroyRenderer(renderer); } };

    bool open = true;
    for (std::int32_t frame{ 0 }; frame < 180 && open; ++frame) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                open = false;
            }
        }
        const auto glow =
            static_cast<std::uint8_t>(cxx_project::clamp(frame, 0, 255));
        SDL_SetRenderDrawColor(renderer, glow, 40, 80, 255);
        SDL_RenderClear(renderer);
        SDL_RenderPresent(renderer);
        SDL_Delay(16); // ~3 s total at 60 fps, then the window closes
    }
    return true;
}

} // namespace

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

    if (!run_window("06_modules - cxx_project " + text)) {
        std::printf("no display - CLI only (SDL: %s)\n", SDL_GetError());
    }

    // flush both stdio buffers before checking for write errors
    std::fflush(stdout);
    if (!ok || std::ferror(stdout) != 0) {
        return EXIT_FAILURE;
    }
    return EXIT_SUCCESS;
}
