// Piped MCP stdio example with SDL3 callbacks
// Demonstrates MCP protocol over stdio with SDL3 event loop

#include "mcp_server.hpp"

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include <array>
#include <cstdlib>
#include <gsl/gsl>
#include <iostream>
#include <string>

namespace {

// Application state carried through SDL3 callbacks
struct AppState {
    piped_mcp::McpServer* mcp_server{nullptr};
    bool done{false};
};

// MCP server instance
piped_mcp::McpServer g_mcp_server;

} // namespace

/// Called once at startup. Initializes SDL video and MCP server.
SDL_AppResult SDL_AppInit(
    void** appstate,
    [[maybe_unused]] int argc,
    [[maybe_unused]] char* argv[]
) {
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "SDL_Init failed: %s", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    // Create application state
    auto* state = gsl::owner<AppState*>{new (std::nothrow) AppState{});
    if (state == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to allocate app state");
        return SDL_APP_FAILURE;
    }

    // Initialize MCP server
    piped_mcp::ServerConfig config{
        .name = "piped_mcp_example",
        .version = "1.0.0",
        .capabilities = {"stdio", "tools"}
    };

    if (!g_mcp_server.start(config)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Failed to start MCP server");
        delete state;
        return SDL_APP_FAILURE;
    }

    // Register custom command handler
    g_mcp_server.register_handler("hello", [](const std::string&) {
        return "{\"result\":\"Hello from C++ MCP Server!\"}";
    });

    // Register SDL info command
    g_mcp_server.register_handler("sdl_info", [](const std::string&) {
        SDL_version compiled;
        SDL_version linked;
        SDL_GetVersion(&compiled);
        SDL_GetVersion(&linked);
        
        char buffer[256];
        std::snprintf(
            buffer, sizeof(buffer),
            "{\"compiled\":\"%d.%d.%d\",\"linked\":\"%d.%d.%d\"}",
            compiled.major, compiled.minor, compiled.patch,
            linked.major, linked.minor, linked.patch
        );
        return buffer;
    });

    state->mcp_server = &g_mcp_server;
    *appstate = state;

    // Show welcome message box
    constexpr std::array buttons{
        SDL_MessageBoxButtonData{
            .flags = SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT,
            .buttonID = 0,
            .text = "OK"
        },
        SDL_MessageBoxButtonData{
            .flags = SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT,
            .buttonID = 1,
            .text = "Exit"
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

/// Called once per frame by SDL
SDL_AppResult SDL_AppIterate(void* appstate) {
    const auto* state = static_cast<const AppState*>(appstate);
    if (state->done) {
        return SDL_APP_SUCCESS;
    }
    return SDL_APP_CONTINUE;
}

/// Called for every pending event
SDL_AppResult SDL_AppEvent(void* appstate, SDL_Event* event) {
    auto* state = static_cast<AppState*>(appstate);
    
    if (event->type == SDL_EVENT_QUIT) {
        state->done = true;
        return SDL_APP_SUCCESS;
    }
    
    // Handle key events for MCP notifications
    if (event->type == SDL_EVENT_KEY_DOWN) {
        if (event->key.key == SDLK_SPACE && (event->key.mod & SDL_KMOD_CTRL)) {
            g_mcp_server.notify("key_pressed", "{\"key\":\"CTRL+SPACE\"}");
        }
    }
    
    return SDL_APP_CONTINUE;
}

/// Called once on shutdown
void SDL_AppQuit(void* appstate, [[maybe_unused]] SDL_AppResult result) {
    auto* state = static_cast<gsl::owner<AppState*>>(appstate);
    
    // Stop MCP server
    if (state->mcp_server != nullptr) {
        state->mcp_server->stop();
    }
    
    delete state;
}
