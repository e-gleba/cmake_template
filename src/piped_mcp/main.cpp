#define SDL_MAIN_USE_CALLBACKS 1

#include "mcp_server.hpp"

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include <array>
#include <cstdio>
#include <gsl/gsl>
#include <new>
#include <string>

namespace tb::detail {

struct app_state {
    piped_mcp::mcp_server* mcp_server{nullptr};
    bool done{false};
};

inline piped_mcp::mcp_server mcp_server;

} // namespace tb::detail

SDL_AppResult SDL_AppInit(
    void** appstate,
    [[maybe_unused]] int argc,
    [[maybe_unused]] char* argv[]
) {
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "SDL_Init failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    auto* state = new (std::nothrow) tb::detail::app_state{};
    if (state == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to allocate app state");
        return SDL_APP_FAILURE;
    }

    tb::piped_mcp::server_config config{
        .name = "piped_mcp_example",
        .version = "1.0.0",
        .capabilities = {"stdio", "tools"},
    };

    tb::detail::mcp_server.register_handler("hello", [](const std::string&) {
        return R"json("Hello from C++ MCP Server!")json";
    });

    tb::detail::mcp_server.register_handler("sdl_info", [](const std::string&) {
        const int compiled_version = SDL_VERSION;
        const int linked_version = SDL_GetVersion();

        std::array<char, 256> buffer{};
        std::snprintf(
            buffer.data(),
            buffer.size(),
            R"json({"compiled":"%d.%d.%d","linked":"%d.%d.%d"})json",
            SDL_VERSIONNUM_MAJOR(compiled_version),
            SDL_VERSIONNUM_MINOR(compiled_version),
            SDL_VERSIONNUM_MICRO(compiled_version),
            SDL_VERSIONNUM_MAJOR(linked_version),
            SDL_VERSIONNUM_MINOR(linked_version),
            SDL_VERSIONNUM_MICRO(linked_version)
        );
        return std::string{buffer.data()};
    });

    if (!tb::detail::mcp_server.start(config)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to start MCP server");
        delete state;
        return SDL_APP_FAILURE;
    }

    state->mcp_server = &tb::detail::mcp_server;
    *appstate = state;

    constexpr std::array buttons{
        SDL_MessageBoxButtonData{
            .flags = SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
            .buttonID = 0,
            .text = "OK",
        },
        SDL_MessageBoxButtonData{
            .flags = SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT,
            .buttonID = 1,
            .text = "Exit",
        },
    };

    const SDL_MessageBoxData box{
        .flags = SDL_MESSAGEBOX_INFORMATION,
        .window = nullptr,
        .title = "Piped MCP + SDL3",
        .message = "MCP Server running on stdio\nSDL3 Callback Example",
        .numbuttons = gsl::narrow_cast<int>(buttons.size()),
        .buttons = buttons.data(),
        .colorScheme = nullptr,
    };

    int button_id{-1};
    if (!SDL_ShowMessageBox(&box, &button_id)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "SDL_ShowMessageBox failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    if (button_id == 1) {
        state->done = true;
    }

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppIterate(void* appstate) {
    const auto* state = static_cast<const tb::detail::app_state*>(appstate);
    return state->done ? SDL_APP_SUCCESS : SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppEvent(void* appstate, SDL_Event* event) {
    auto* state = static_cast<tb::detail::app_state*>(appstate);

    if (event->type == SDL_EVENT_QUIT) {
        state->done = true;
        return SDL_APP_SUCCESS;
    }

    if (
        event->type == SDL_EVENT_KEY_DOWN && event->key.key == SDLK_SPACE
        && (event->key.mod & SDL_KMOD_CTRL) != 0
    ) {
        tb::detail::mcp_server.notify("notifications/key_pressed", R"json({"key":"CTRL+SPACE"})json");
    }

    return SDL_APP_CONTINUE;
}

void SDL_AppQuit(void* appstate, [[maybe_unused]] SDL_AppResult result) {
    auto* state = static_cast<tb::detail::app_state*>(appstate);
    if (state != nullptr && state->mcp_server != nullptr) {
        state->mcp_server->stop();
    }
    delete state;
}
