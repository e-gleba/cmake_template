#include <cstring>

#include <array>
#include <atomic>
#include <cstdlib>
#include <format>
#include <memory>
#include <print>
#include <thread>
#include <vector>

#define SDL_MAIN_USE_CALLBACKS 1
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <gsl/gsl>
#include <tracy/Tracy.hpp>

// ── Tracy-tracked mutex ──────────────────────────────────────────────
// NOLINTBEGIN(cppcoreguidelines-avoid-non-const-global-variables)
TracyLockable(std::mutex, g_data_mutex);
// NOLINTEND(cppcoreguidelines-avoid-non-const-global-variables)

// ── Tracy-tracked allocator ──────────────────────────────────────────
template <typename type_t> struct tracked_allocator
{
    using value_type = type_t;

    tracked_allocator() = default;
    template <typename other_t>
    constexpr tracked_allocator(
        const tracked_allocator<other_t>& /*unused*/) noexcept
    {
    }

    [[nodiscard]] type_t* allocate(std::size_t count)
    {
        const auto bytes = count * sizeof(type_t);
        auto*      ptr   = static_cast<type_t*>(::operator new(bytes));
        TracyAllocN(ptr, bytes, "tracked");
        return ptr;
    }

    void deallocate(type_t* ptr, std::size_t count) noexcept
    {
        TracyFreeN(ptr, "tracked");
        ::operator delete(ptr, count * sizeof(type_t));
    }
};

using tracked_vector = std::vector<std::byte, tracked_allocator<std::byte>>;

// ── Worker: simulates CPU load under a traced zone ───────────────────
static void worker_thread(std::size_t id, std::atomic<bool>& running)
{
    const auto name = std::format("worker_{}", id);
    tracy::SetThreadName(name.c_str());

    while (running.load(std::memory_order_relaxed)) {
        ZoneScopedN("worker_tick");

        {
            ZoneScopedN("alloc_churn");
            tracked_vector buf(1024 * (1 + id));
            std::memset(buf.data(), gsl::narrow_cast<int>(id), buf.size());
        }

        {
            ZoneScopedN("contended_lock");
            std::scoped_lock lock(g_data_mutex);
            volatile int     sink = 0;
            for (int i = 0; i < 10000; ++i) {
                sink += i;
            }
            (void)sink;
        }

        TracyPlot(name.c_str(), static_cast<double>(id * 100));
        std::this_thread::sleep_for(std::chrono::milliseconds(16));
        FrameMarkNamed("worker");
    }
}

// ── App state ────────────────────────────────────────────────────────

struct app_state
{
    SDL_Window*                 window   = nullptr;
    SDL_Renderer*               renderer = nullptr;
    std::atomic<bool>           running{ true };
    std::array<std::jthread, 4> workers;
};

// NOLINTBEGIN(readability-identifier-naming)

SDL_AppResult SDL_AppInit(void**                 appstate,
                          [[maybe_unused]] int   argc,
                          [[maybe_unused]] char* argv[])
{ // NOLINT(cppcoreguidelines-avoid-c-arrays)
    ZoneScopedN("app_init");
    TracySetProgramName("tracy_sandbox");
    TracyMessageL("app_init => start");

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        std::println(stderr, "sdl_init failed: {}", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    auto owner = std::make_unique<app_state>();

    owner->window =
        SDL_CreateWindow("Tracy Sandbox", 1280, 720, SDL_WINDOW_RESIZABLE);
    if (owner->window == nullptr) {
        std::println(stderr, "create_window failed: {}", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    owner->renderer = SDL_CreateRenderer(owner->window, nullptr);
    if (owner->renderer == nullptr) {
        std::println(stderr, "create_renderer failed: {}", SDL_GetError());
        return SDL_APP_FAILURE;
    }

    for (std::size_t i = 0; i < owner->workers.size(); ++i) {
        owner->workers.at(i) = std::jthread(
            [i, &running = owner->running] { worker_thread(i, running); });
    }

    *appstate = owner.release();
    TracyMessageL("app_init => done");
    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppEvent([[maybe_unused]] void* appstate, SDL_Event* event)
{
    ZoneScopedN("app_event");

    if (event->type == SDL_EVENT_QUIT) {
        return SDL_APP_SUCCESS;
    }
    if (event->type == SDL_EVENT_KEY_DOWN && event->key.key == SDLK_ESCAPE) {
        return SDL_APP_SUCCESS;
    }

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppIterate(void* appstate)
{
    ZoneScopedN("app_iterate");
    auto* state = static_cast<app_state*>(appstate);

    {
        ZoneScopedN("main_alloc");
        tracked_vector frame_data(4096);
        std::memset(frame_data.data(), 0xAB, frame_data.size());
    }

    {
        ZoneScopedN("render");
        SDL_SetRenderDrawColor(state->renderer, 30, 30, 46, 255);
        SDL_RenderClear(state->renderer);
        SDL_RenderPresent(state->renderer);
    }

    FrameMark;
    return SDL_APP_CONTINUE;
}

void SDL_AppQuit(void* appstate, [[maybe_unused]] SDL_AppResult result)
{
    ZoneScopedN("app_quit");
    TracyMessageL("app_quit => shutting down");

    auto owner = std::unique_ptr<app_state>(static_cast<app_state*>(appstate));
    owner->running.store(false, std::memory_order_relaxed);

    for (auto& worker : owner->workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }

    if (owner->renderer != nullptr) {
        SDL_DestroyRenderer(owner->renderer);
    }
    if (owner->window != nullptr) {
        SDL_DestroyWindow(owner->window);
    }
    SDL_Quit();
}

// NOLINTEND(readability-identifier-naming)
