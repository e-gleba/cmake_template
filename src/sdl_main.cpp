#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include <cstdlib>
#include <gsl/gsl>
#include <print>

int main([[maybe_unused]] int argc, [[maybe_unused]] char* argv[])
{
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        std::println(stderr, "sdl_init failed: {}", SDL_GetError());
        return EXIT_FAILURE;
    }
    auto _ = gsl::finally([] { SDL_Quit(); });

    constexpr std::array buttons = {
        SDL_MessageBoxButtonData{ .flags =
                                      SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
                                  .buttonID = 0,
                                  .text     = "OK" },
        SDL_MessageBoxButtonData{ .flags =
                                      SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT,
                                  .buttonID = 1,
                                  .text     = "Exit" },
    };

    const SDL_MessageBoxData box = {
        .flags       = SDL_MESSAGEBOX_INFORMATION,
        .window      = nullptr,
        .title       = "Hello World",
        .message     = "SDL3 + C++23",
        .numbuttons  = gsl::narrow_cast<int>(buttons.size()),
        .buttons     = buttons.data(),
        .colorScheme = nullptr,
    };

    int button_id = -1;
    if (!SDL_ShowMessageBox(&box, &button_id)) {
        std::println(stderr, "show_message_box failed: {}", SDL_GetError());
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
