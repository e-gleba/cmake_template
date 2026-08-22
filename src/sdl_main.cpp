// SDL_main.h reads this macro at include time to select the callback entry
// model; it cannot be a constexpr.
// NOLINTNEXTLINE(cppcoreguidelines-macro-usage)
#define SDL_MAIN_USE_CALLBACKS 1
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include <array>
#include <cstdlib>
#include <gsl/gsl>

/// Application state carried through SDL3 callbacks.
/// SDL passes this opaque pointer to every callback after init.
struct app_state final
{
    bool done_{ false };
};

/// Called once at startup. Initializes SDL video and shows a message box.
/// @param appstate  [out] Pointer to application state; SDL manages lifetime.
/// @param argc      Argument count forwarded from the platform entry point.
/// @param argv      Argument vector forwarded from the platform entry point.
/// @return SDL_APP_CONTINUE on success, SDL_APP_FAILURE on error.
// NOLINTNEXTLINE(readability-identifier-naming) - SDL_main callback: name fixed by SDL_main.h
SDL_AppResult SDL_AppInit(void**                 appstate,
                          [[maybe_unused]] int   argc,
                          [[maybe_unused]] char* argv[])
{
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        // NOLINTNEXTLINE(cppcoreguidelines-pro-type-vararg) - SDL_Log* is the C varargs SDL logging API
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_Init failed: %s",
                     SDL_GetError());
        return SDL_APP_FAILURE;
    }

    // Ownership crosses the C callback boundary as void*; gsl::owner marks
    // both ends so cppcoreguidelines-owning-memory accepts the transfer.
    // NOLINTNEXTLINE(readability-redundant-casting) - gsl::owner annotation, not a redundant cast
    auto* state = gsl::owner<app_state*>{ new (std::nothrow) app_state{} };
    if (state == nullptr) {
        // NOLINTNEXTLINE(cppcoreguidelines-pro-type-vararg) - SDL_Log* is the C varargs SDL logging API
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Failed to allocate app_state");
        return SDL_APP_FAILURE;
    }
    *appstate = state;

    // --- Message box ---
    constexpr std::array buttons{
        SDL_MessageBoxButtonData{ .flags =
                                      SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
                                  .buttonID = 0,
                                  .text     = "OK" },
        SDL_MessageBoxButtonData{ .flags =
                                      SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT,
                                  .buttonID = 1,
                                  .text     = "Exit" },
    };

    const SDL_MessageBoxData box{
        .flags       = SDL_MESSAGEBOX_INFORMATION,
        .window      = nullptr,
        .title       = "Hello World",
        .message     = "SDL3 + C++20 Callbacks",
        .numbuttons  = gsl::narrow_cast<int>(buttons.size()),
        .buttons     = buttons.data(),
        .colorScheme = nullptr,
    };

    int button_id{ -1 };
    if (!SDL_ShowMessageBox(&box, &button_id)) {
        // NOLINTNEXTLINE(cppcoreguidelines-pro-type-vararg) - SDL_Log* is the C varargs SDL logging API
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_ShowMessageBox failed: %s",
                     SDL_GetError());
        return SDL_APP_FAILURE;
    }

    // NOLINTNEXTLINE(cppcoreguidelines-pro-type-vararg) - SDL_Log* is the C varargs SDL logging API
    SDL_Log("button_id == %d", button_id);

    // Signal that we're done after the first iterate.
    state->done_ = true;

    return SDL_APP_CONTINUE;
}

/// Called once per frame by SDL. Return SDL_APP_SUCCESS to exit cleanly.
// NOLINTNEXTLINE(readability-identifier-naming) - SDL_main callback: name fixed by SDL_main.h
SDL_AppResult SDL_AppIterate(void* appstate)
{
    const auto* state = static_cast<const app_state*>(appstate);
    if (state->done_) {
        return SDL_APP_SUCCESS;
    }
    return SDL_APP_CONTINUE;
}

/// Called for every pending event. Handles quit requests.
// NOLINTNEXTLINE(readability-identifier-naming) - SDL_main callback: name fixed by SDL_main.h
SDL_AppResult SDL_AppEvent(void* /*appstate*/, SDL_Event* event)
{
    if (event->type == SDL_EVENT_QUIT) {
        return SDL_APP_SUCCESS;
    }
    return SDL_APP_CONTINUE;
}

/// Called once on shutdown. Frees application state; SDL calls SDL_Quit() for
/// us.
// NOLINTNEXTLINE(readability-identifier-naming) - SDL_main callback: name fixed by SDL_main.h
void SDL_AppQuit(void* appstate, [[maybe_unused]] SDL_AppResult result)
{
    // Ownership arrives as void* from SDL; re-mark it as owner before delete.
    // NOLINTNEXTLINE(readability-redundant-casting) - gsl::owner annotation, not a redundant cast
    auto* state = static_cast<gsl::owner<app_state*>>(appstate);
    delete state;
    // SDL_Quit() is called automatically by SDL after this returns
}
