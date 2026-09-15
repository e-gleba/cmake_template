#define SDL_MAIN_USE_CALLBACKS 1 // NOLINT(cppcoreguidelines-macro-usage)

#include "mcp_server.hpp"

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include <algorithm>
#include <array>
#include <format>
#include <gsl/gsl>
#include <memory>
#include <string>
#include <string_view>

namespace {

[[nodiscard]] std::string json_field(std::string_view json,
                                     std::string_view key)
{
    const std::string needle  = std::format(R"("{}")", key);
    const auto        key_pos = json.find(needle);
    if (key_pos == std::string_view::npos) {
        return {};
    }

    const auto colon = json.find(':', key_pos + needle.size());
    if (colon == std::string_view::npos) {
        return {};
    }

    const auto open = json.find('"', colon + 1);
    if (open == std::string_view::npos) {
        return {};
    }

    const auto close = json.find('"', open + 1);
    if (close == std::string_view::npos) {
        return {};
    }

    return std::string{ json.substr(open + 1, close - open - 1) };
}

constexpr std::array tool_names{
    std::string_view{ "hello" },
    std::string_view{ "sdl_info" },
};

} // namespace

namespace tb::detail {

struct app_state final
{
    piped_mcp::mcp_server mcp_server_;
    bool                  done_{ false };
};

} // namespace tb::detail

SDL_AppResult SDL_AppInit(void**                 appstate,
                          [[maybe_unused]] int   argc,
                          [[maybe_unused]] char* argv[])
{
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        SDL_Log("SDL_Init failed: %s", // NOLINT(cppcoreguidelines-pro-type-vararg)
                SDL_GetError());
        return SDL_APP_FAILURE;
    }

    auto state = std::make_unique<tb::detail::app_state>();

    const tb::piped_mcp::server_config config{
        .name         = "piped_mcp_example",
        .version      = "1.0.0",
        .capabilities = { "stdio", "tools" },
    };

    state->mcp_server_.register_handler(
        "initialize", [](const std::string&) -> std::string {
            return R"json({"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"piped_mcp","version":"0.1.0"}})json";
        });

    state->mcp_server_.register_handler(
        "ping",
        [](const std::string&) -> std::string { return R"json({})json"; });

    state->mcp_server_.register_handler(
        "hello", [](const std::string&) -> std::string {
            return R"json("Hello from C++ MCP Server!")json";
        });

    state->mcp_server_.register_handler(
        "sdl_info", [](const std::string&) -> std::string {
            const int compiled = SDL_VERSION;
            const int linked   = SDL_GetVersion();
            return std::format(
                R"json("SDL compiled {}.{}.{} / linked {}.{}.{}")json",
                SDL_VERSIONNUM_MAJOR(compiled),
                SDL_VERSIONNUM_MINOR(compiled),
                SDL_VERSIONNUM_MICRO(compiled),
                SDL_VERSIONNUM_MAJOR(linked),
                SDL_VERSIONNUM_MINOR(linked),
                SDL_VERSIONNUM_MICRO(linked));
        });

    state->mcp_server_.register_handler(
        "tools/list", [](const std::string&) -> std::string {
            return R"json({"tools":[{"name":"hello","description":"Returns a greeting","inputSchema":{"type":"object","properties":{},"required":[]}},{"name":"sdl_info","description":"SDL3 compiled and linked version","inputSchema":{"type":"object","properties":{},"required":[]}}]})json";
        });

    state->mcp_server_.register_handler(
        "tools/call",
        [&server =
             state->mcp_server_](const std::string& params) -> std::string {
            const std::string name = json_field(params, "name");
            if (name.empty()) {
                return R"json({"content":[{"type":"text","text":"missing tool name"}],"isError":true})json";
            }

            const auto known =
                std::ranges::find(tool_names, std::string_view{ name });
            if (known == tool_names.end()) {
                return R"json({"content":[{"type":"text","text":"unknown tool"}],"isError":true})json";
            }

            const std::string result = server.execute(name, std::string{});
            return std::format(
                R"json({{"content":[{{"type":"text","text":{}}}],"isError":false}})json",
                result);
        });

    if (!state->mcp_server_.start(config)) {
        SDL_Log("Failed to start MCP server"); // NOLINT(cppcoreguidelines-pro-type-vararg)
        return SDL_APP_FAILURE;
    }

    *appstate = state.release();

    constexpr std::array buttons{
        SDL_MessageBoxButtonData{
            .flags    = SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
            .buttonID = 0,
            .text     = "OK",
        },
        SDL_MessageBoxButtonData{
            .flags    = SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT,
            .buttonID = 1,
            .text     = "Exit",
        },
    };

    const SDL_MessageBoxData box{
        .flags       = SDL_MESSAGEBOX_INFORMATION,
        .window      = nullptr,
        .title       = "Piped MCP + SDL3",
        .message     = "MCP Server running on stdio\nSDL3 Callback Example",
        .numbuttons  = gsl::narrow_cast<int>(buttons.size()),
        .buttons     = buttons.data(),
        .colorScheme = nullptr,
    };

    int button_id{ -1 };
    if (!SDL_ShowMessageBox(&box, &button_id)) {
        SDL_Log("SDL_ShowMessageBox failed: %s", // NOLINT(cppcoreguidelines-pro-type-vararg)
                SDL_GetError());
        return SDL_APP_FAILURE;
    }

    if (button_id == 1) {
        static_cast<tb::detail::app_state*>(*appstate)->done_ = true;
    }

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppIterate(void* appstate)
{
    const auto* state = static_cast<const tb::detail::app_state*>(appstate);
    return state->done_ ? SDL_APP_SUCCESS : SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppEvent(void* appstate, SDL_Event* event)
{
    auto* state = static_cast<tb::detail::app_state*>(appstate);

    if (event->type == SDL_EVENT_QUIT) {
        state->done_ = true;
        return SDL_APP_SUCCESS;
    }

    if (event->type == SDL_EVENT_KEY_DOWN && event->key.key == SDLK_SPACE &&
        (event->key.mod & SDL_KMOD_CTRL) != 0) {
        state->mcp_server_.notify("notifications/key_pressed",
                                  R"json({"key":"CTRL+SPACE"})json");
    }

    return SDL_APP_CONTINUE;
}

void SDL_AppQuit(void* appstate, [[maybe_unused]] SDL_AppResult result)
{
    std::unique_ptr<tb::detail::app_state> state{
        static_cast<tb::detail::app_state*>(appstate)
    };
    if (state != nullptr) {
        state->mcp_server_.stop();
    }
}
