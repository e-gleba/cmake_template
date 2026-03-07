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

namespace {
// ── Frame image capture for Tracy ────────────────────────────────────
// Tracy expects raw RGBA pixels, width/height divisible by 4.
// We downscale to 320x180 to keep bandwidth reasonable.
void capture_frame_image(SDL_Renderer* renderer)
{
    ZoneScopedN("capture_frame_image");

    constexpr int capture_w = 320;
    constexpr int capture_h = 180;

    // Read pixels from current render target
    SDL_Surface* full = SDL_RenderReadPixels(renderer, nullptr);
    if (full == nullptr) {
        return;
    }
    auto full_guard = gsl::finally([&] { SDL_DestroySurface(full); });

    // Create downscaled RGBA surface (dimensions divisible by 4)
    SDL_Surface* scaled =
        SDL_CreateSurface(capture_w, capture_h, SDL_PIXELFORMAT_RGBA32);
    if (scaled == nullptr) {
        return;
    }
    auto scaled_guard = gsl::finally([&] { SDL_DestroySurface(scaled); });

    // Downscale with bilinear filtering
    if (!SDL_BlitSurfaceScaled(
            full, nullptr, scaled, nullptr, SDL_SCALEMODE_LINEAR)) {
        return;
    }

    // Lock surface to ensure pixel pointer is valid
    if (!SDL_LockSurface(scaled)) {
        return;
    }
    auto lock_guard = gsl::finally([&] { SDL_UnlockSurface(scaled); });

    // offset=0 => current frame, flip=false => top-down scanlines
    FrameImage(scaled->pixels, capture_w, capture_h, 0, false);
}

// ── Worker: simulates CPU load under a traced zone ───────────────────
void worker_thread(std::size_t id, std::atomic<bool>& running)
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
} // namespace

// ── App state ────────────────────────────────────────────────────────

struct app_state final
{
    SDL_Window*                 window   = nullptr;
    SDL_Renderer*               renderer = nullptr;
    std::atomic<bool>           running{ true };
    std::array<std::jthread, 4> workers;
    std::uint64_t               frame_count = 0;
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

    // Render something visible so screenshots aren't just a solid color
    {
        ZoneScopedN("render");

        SDL_SetRenderDrawColor(state->renderer, 30, 30, 46, 255);
        SDL_RenderClear(state->renderer);

        // Animated rectangle — proves frame capture works
        const auto      phase = static_cast<float>(state->frame_count % 240);
        const SDL_FRect rect  = {
             .x = phase * 4.0F,
             .y = 200.0F,
             .w = 120.0F,
             .h = 80.0F,
        };
        SDL_SetRenderDrawColor(state->renderer, 166, 227, 161, 255);
        SDL_RenderFillRect(state->renderer, &rect);

        // Capture every 4th frame — balance between coverage and overhead
        if (state->frame_count % 4 == 0) {
            capture_frame_image(state->renderer);
        }

        SDL_RenderPresent(state->renderer);
    }

    ++state->frame_count;
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
