/// @file main.cpp
/// @brief Emscripten/WebAssembly demo - SDL3 callbacks + OpenGL + Dear ImGui.
///
/// Renders an animated plasma shader on a buffer-less fullscreen triangle
/// (vertices are derived from `gl_VertexID`, so no VBO/VAO state exists) with
/// a Dear ImGui control overlay. Targets WebGL2 (GLSL ES 3.00) under
/// Emscripten and desktop OpenGL 3.3 Core elsewhere; every GL entry point is
/// resolved through `SDL_GL_GetProcAddress`, so no loader library (glad/glew)
/// is linked.
///
/// The app follows the SDL3 callback model: the browser drives
/// `SDL_AppIterate` from `requestAnimationFrame` and maps the tab close
/// button to `SDL_EVENT_QUIT`. All mutable state lives in one `app_state`
/// whose ownership is handed to SDL through `void** appstate`.

// Must be defined before <SDL3/SDL_main.h> so SDL routes `main` through the
// SDL_App* callbacks at the bottom of this file. Required on Emscripten,
// where the browser event loop must stay in control of the thread.
#define SDL_MAIN_USE_CALLBACKS

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <SDL3/SDL_opengl.h>

#include <imgui.h>
#include <imgui_impl_opengl3.h>
#include <imgui_impl_sdl3.h>

#include <gsl/narrow>
#include <gsl/util>

#include <array>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string_view>
#include <type_traits>
#include <utility>

namespace {

// ---------------------------------------------------------------------------
// configuration
// ---------------------------------------------------------------------------

namespace config {

inline constexpr std::string_view app_name = "cmake_template - web_app";
inline constexpr std::string_view app_version = "1.0.0";
inline constexpr std::string_view app_id = "com.e-gleba.cmake_template.web_app";

inline constexpr int window_width = 1280;
inline constexpr int window_height = 720;

inline constexpr float speed_default = 1.0F;
inline constexpr float speed_min = 0.0F;
inline constexpr float speed_max = 4.0F;

} // namespace config

// ---------------------------------------------------------------------------
// shaders - inlined, so the web bundle ships zero asset files
// ---------------------------------------------------------------------------

namespace shaders {

// GLSL ES 3.00 allows `layout(location=)` only on vertex inputs and fragment
// outputs - never on varyings between stages - so `uv` is matched by name.
#if defined(__EMSCRIPTEN__)
inline constexpr std::string_view vertex_header = "#version 300 es\n";
inline constexpr std::string_view fragment_header =
    "#version 300 es\n"
    "precision highp float;\n";
#else
inline constexpr std::string_view vertex_header = "#version 330 core\n";
inline constexpr std::string_view fragment_header = "#version 330 core\n";
#endif

/// Fullscreen triangle generated analytically from `gl_VertexID` - three
/// vertices, no buffers, covering the whole viewport.
inline constexpr std::string_view vertex_body = R"glsl(
out vec2 uv;

void main()
{
    const vec2 position =
        vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2)) * 2.0 - 1.0;
    uv = position * 0.5 + 0.5;
    gl_Position = vec4(position, 0.0, 1.0);
}
)glsl";

/// Animated plasma: sine octaves through a cosine palette (Inigo Quilez's
/// cheap procedural coloring) with a soft vignette. Uniform-driven so the UI
/// steers it live.
inline constexpr std::string_view fragment_body = R"glsl(
in vec2 uv;

layout(location = 0) out vec4 frag_color;

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_speed;

vec3 palette(float t)
{
    const vec3 a = vec3(0.5);
    const vec3 b = vec3(0.5);
    const vec3 c = vec3(1.0);
    const vec3 d = vec3(0.263, 0.416, 0.557);
    return a + b * cos(6.2831853 * (c * t + d));
}

void main()
{
    const vec2 p =
        (uv * 2.0 - 1.0) * vec2(u_resolution.x / u_resolution.y, 1.0);
    const float t = u_time * u_speed;

    float v = sin(p.x * 3.0 + t) + sin((p.y + t) * 0.5)
            + sin((p.x + p.y + t) * 0.5);
    const vec2 q = p + 0.5 * vec2(cos(t * 0.7), sin(t * 0.9));
    v = v * 0.25 + 0.25 * sin(length(q) * 4.0 - t);

    const vec3 color = palette(v + t * 0.1) * (1.0 - 0.125 * dot(p, p));
    frag_color = vec4(color, 1.0);
}
)glsl";

/// GLSL handed to the driver as a (header, body) string pair - the canonical
/// `glShaderSource` way to inject the platform `#version` without any string
/// concatenation.
struct source {
    std::string_view header;
    std::string_view body;
};

inline constexpr source vertex{vertex_header, vertex_body};
inline constexpr source fragment{fragment_header, fragment_body};

} // namespace shaders

// ---------------------------------------------------------------------------
// GL entry points
// ---------------------------------------------------------------------------

/// The exact GL subset this renderer needs, resolved once at startup through
/// `SDL_GL_GetProcAddress` - valid for desktop GL, WebGL2 and WGL alike.
/// Namespace scope mirrors how loader libraries (glad/glew) expose GL, so
/// `shader_program` can release its handle without the table being threaded
/// through every call site.
struct gl_api {
    PFNGLGETSTRINGPROC GetString = nullptr;
    PFNGLVIEWPORTPROC Viewport = nullptr;
    PFNGLCLEARCOLORPROC ClearColor = nullptr;
    PFNGLCLEARPROC Clear = nullptr;
    PFNGLDRAWARRAYSPROC DrawArrays = nullptr;
    PFNGLCREATESHADERPROC CreateShader = nullptr;
    PFNGLSHADERSOURCEPROC ShaderSource = nullptr;
    PFNGLCOMPILESHADERPROC CompileShader = nullptr;
    PFNGLGETSHADERIVPROC GetShaderiv = nullptr;
    PFNGLGETSHADERINFOLOGPROC GetShaderInfoLog = nullptr;
    PFNGLDELETESHADERPROC DeleteShader = nullptr;
    PFNGLCREATEPROGRAMPROC CreateProgram = nullptr;
    PFNGLATTACHSHADERPROC AttachShader = nullptr;
    PFNGLLINKPROGRAMPROC LinkProgram = nullptr;
    PFNGLGETPROGRAMIVPROC GetProgramiv = nullptr;
    PFNGLGETPROGRAMINFOLOGPROC GetProgramInfoLog = nullptr;
    PFNGLDELETEPROGRAMPROC DeleteProgram = nullptr;
    PFNGLUSEPROGRAMPROC UseProgram = nullptr;
    PFNGLGETUNIFORMLOCATIONPROC GetUniformLocation = nullptr;
    PFNGLUNIFORM1FPROC Uniform1f = nullptr;
    PFNGLUNIFORM2FPROC Uniform2f = nullptr;
};

gl_api gl{};

[[nodiscard]] bool resolve_gl_entry_points() noexcept
{
    bool resolved = true;
    const auto bind = [&resolved](const char* name, auto& entry) noexcept {
        // Function-pointer to function-pointer cast: ISO C++ legal, unlike
        // routing through `void*` (which -Wpedantic diagnoses).
        entry = reinterpret_cast<std::decay_t<decltype(entry)>>(
            SDL_GL_GetProcAddress(name));
        if (entry == nullptr) {
            SDL_LogError(SDL_LOG_CATEGORY_VIDEO, "GL entry point missing: %s",
                         name);
            resolved = false;
        }
    };

    bind("glGetString", gl.GetString);
    bind("glViewport", gl.Viewport);
    bind("glClearColor", gl.ClearColor);
    bind("glClear", gl.Clear);
    bind("glDrawArrays", gl.DrawArrays);
    bind("glCreateShader", gl.CreateShader);
    bind("glShaderSource", gl.ShaderSource);
    bind("glCompileShader", gl.CompileShader);
    bind("glGetShaderiv", gl.GetShaderiv);
    bind("glGetShaderInfoLog", gl.GetShaderInfoLog);
    bind("glDeleteShader", gl.DeleteShader);
    bind("glCreateProgram", gl.CreateProgram);
    bind("glAttachShader", gl.AttachShader);
    bind("glLinkProgram", gl.LinkProgram);
    bind("glGetProgramiv", gl.GetProgramiv);
    bind("glGetProgramInfoLog", gl.GetProgramInfoLog);
    bind("glDeleteProgram", gl.DeleteProgram);
    bind("glUseProgram", gl.UseProgram);
    bind("glGetUniformLocation", gl.GetUniformLocation);
    bind("glUniform1f", gl.Uniform1f);
    bind("glUniform2f", gl.Uniform2f);
    return resolved;
}

// ---------------------------------------------------------------------------
// renderer
// ---------------------------------------------------------------------------

/// Owning RAII wrapper for a compiled and linked GL program. Move-only;
/// releases its handle on destruction while a GL context is current.
class shader_program {
public:
    shader_program() noexcept = default;
    ~shader_program() { destroy(); }

    shader_program(const shader_program&) = delete;
    shader_program& operator=(const shader_program&) = delete;

    shader_program(shader_program&& other) noexcept
        : id_(std::exchange(other.id_, 0u)) {}

    shader_program& operator=(shader_program&& other) noexcept
    {
        if (this != &other) {
            destroy();
            id_ = std::exchange(other.id_, 0u);
        }
        return *this;
    }

    /// Compiles both stages and links. On any failure: logs the driver info
    /// log, releases every intermediate object, leaves `*this` empty.
    [[nodiscard]] bool build(const shaders::source& vertex,
                             const shaders::source& fragment) noexcept
    {
        destroy();

        const GLuint vertex_shader = compile(GL_VERTEX_SHADER, vertex);
        if (vertex_shader == 0u) {
            return false;
        }
        const auto vertex_guard = gsl::finally(
            [&] { gl.DeleteShader(vertex_shader); });

        const GLuint fragment_shader = compile(GL_FRAGMENT_SHADER, fragment);
        if (fragment_shader == 0u) {
            return false;
        }
        const auto fragment_guard = gsl::finally(
            [&] { gl.DeleteShader(fragment_shader); });

        id_ = gl.CreateProgram();
        gl.AttachShader(id_, vertex_shader);
        gl.AttachShader(id_, fragment_shader);
        gl.LinkProgram(id_);

        GLint linked = GL_FALSE;
        gl.GetProgramiv(id_, GL_LINK_STATUS, &linked);
        if (linked != GL_TRUE) {
            std::array<GLchar, info_log_size> log{};
            gl.GetProgramInfoLog(id_, gsl::narrow_cast<GLsizei>(log.size()),
                                 nullptr, log.data());
            SDL_LogError(SDL_LOG_CATEGORY_RENDER, "program link failed: %s",
                         log.data());
            destroy();
            return false;
        }
        return true;
    }

    void destroy() noexcept
    {
        if (id_ != 0u) {
            gl.DeleteProgram(id_);
            id_ = 0u;
        }
    }

    void bind() const noexcept { gl.UseProgram(id_); }

    /// Returns -1 for unknown or optimized-out uniforms; GL silently ignores
    /// uploads to location -1, so call sites need no checks.
    [[nodiscard]] GLint uniform_location(const char* name) const noexcept
    {
        return gl.GetUniformLocation(id_, name);
    }

private:
    [[nodiscard]] static GLuint compile(GLenum stage,
                                        const shaders::source& source) noexcept
    {
        const GLuint shader = gl.CreateShader(stage);

        const std::array<const GLchar*, 2> parts{source.header.data(),
                                                 source.body.data()};
        const std::array<GLint, 2> lengths{
            gsl::narrow_cast<GLint>(source.header.size()),
            gsl::narrow_cast<GLint>(source.body.size())};
        gl.ShaderSource(shader, gsl::narrow_cast<GLsizei>(parts.size()),
                        parts.data(), lengths.data());
        gl.CompileShader(shader);

        GLint compiled = GL_FALSE;
        gl.GetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
        if (compiled != GL_TRUE) {
            std::array<GLchar, info_log_size> log{};
            gl.GetShaderInfoLog(shader, gsl::narrow_cast<GLsizei>(log.size()),
                                nullptr, log.data());
            SDL_LogError(SDL_LOG_CATEGORY_RENDER,
                         "%s shader compile failed: %s",
                         stage == GL_VERTEX_SHADER ? "vertex" : "fragment",
                         log.data());
            gl.DeleteShader(shader);
            return 0u;
        }
        return shader;
    }

    static constexpr std::size_t info_log_size = 1024;

    GLuint id_ = 0u;
};

// ---------------------------------------------------------------------------
// application state
// ---------------------------------------------------------------------------

/// Everything the demo owns. SDL holds the instance between callbacks;
/// `shutdown` releases it in reverse order of initialization.
struct app_state {
    SDL_Window* window = nullptr;
    SDL_GLContext gl_context = nullptr;
    bool imgui_initialized = false;
    shader_program program;

    GLint uniform_resolution = -1;
    GLint uniform_time = -1;
    GLint uniform_speed = -1;

    std::uint64_t start_ticks_ns = 0;
    std::uint64_t frame_count = 0;
    float speed = config::speed_default;
    bool show_demo_window = false;
};

[[nodiscard]] bool create_window_and_context(app_state& app) noexcept
{
#if defined(__EMSCRIPTEN__)
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
#else
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,
                        SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS,
                        SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG); // macOS
#endif
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 0); // fullscreen triangle: no depth
    SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 0);

    app.window = SDL_CreateWindow(config::app_name.data(), config::window_width,
                                  config::window_height,
                                  SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE
                                      | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (app.window == nullptr) {
        SDL_LogCritical(SDL_LOG_CATEGORY_VIDEO, "SDL_CreateWindow failed: %s",
                        SDL_GetError());
        return false;
    }

    app.gl_context = SDL_GL_CreateContext(app.window);
    if (app.gl_context == nullptr) {
        SDL_LogCritical(SDL_LOG_CATEGORY_VIDEO,
                        "SDL_GL_CreateContext failed: %s", SDL_GetError());
        return false;
    }

    if (!SDL_GL_MakeCurrent(app.window, app.gl_context)) {
        SDL_LogCritical(SDL_LOG_CATEGORY_VIDEO, "SDL_GL_MakeCurrent failed: %s",
                        SDL_GetError());
        return false;
    }

    // Vsync where possible; the browser always vsyncs via rAF anyway.
    if (!SDL_GL_SetSwapInterval(1)) {
        SDL_LogWarn(SDL_LOG_CATEGORY_VIDEO, "vsync unavailable: %s",
                    SDL_GetError());
    }
    return true;
}

[[nodiscard]] bool init_imgui(app_state& app) noexcept
{
    IMGUI_CHECKVERSION();
    if (ImGui::CreateContext() == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_RENDER, "ImGui::CreateContext failed");
        return false;
    }
    ImGui::StyleColorsDark();

    if (!ImGui_ImplSDL3_InitForOpenGL(app.window, app.gl_context)) {
        SDL_LogError(SDL_LOG_CATEGORY_RENDER,
                     "ImGui_ImplSDL3_InitForOpenGL failed");
        return false;
    }
    if (!ImGui_ImplOpenGL3_Init(shaders::vertex_header.data())) {
        SDL_LogError(SDL_LOG_CATEGORY_RENDER, "ImGui_ImplOpenGL3_Init failed");
        return false;
    }
    app.imgui_initialized = true;
    return true;
}

/// Idempotent teardown, valid for partially-initialized states (init failure
/// path) and the normal `SDL_AppQuit` path alike. GL objects are released
/// while the context is still current.
void shutdown(app_state& app) noexcept
{
    if (app.imgui_initialized) {
        ImGui_ImplOpenGL3_Shutdown();
        ImGui_ImplSDL3_Shutdown();
        ImGui::DestroyContext();
        app.imgui_initialized = false;
    }
    app.program.destroy();
    if (app.gl_context != nullptr) {
        SDL_GL_DestroyContext(app.gl_context);
        app.gl_context = nullptr;
    }
    if (app.window != nullptr) {
        SDL_DestroyWindow(app.window);
        app.window = nullptr;
    }
    SDL_Quit();
}

void render_scene(app_state& app) noexcept
{
    int width = 0;
    int height = 0;
    SDL_GetWindowSizeInPixels(app.window, &width, &height); // high-DPI aware
    if (width <= 0 || height <= 0) {
        return; // minimized or zero-size framebuffer: nothing to draw
    }

    gl.Viewport(0, 0, width, height);
    gl.ClearColor(0.02F, 0.02F, 0.03F, 1.0F);
    gl.Clear(GL_COLOR_BUFFER_BIT);

    const auto elapsed_ns = SDL_GetTicksNS() - app.start_ticks_ns;
    const float time_seconds = gsl::narrow_cast<float>(elapsed_ns) * 1.0e-9F;

    app.program.bind();
    gl.Uniform2f(app.uniform_resolution, gsl::narrow_cast<float>(width),
                 gsl::narrow_cast<float>(height));
    gl.Uniform1f(app.uniform_time, time_seconds);
    gl.Uniform1f(app.uniform_speed, app.speed);
    gl.DrawArrays(GL_TRIANGLES, 0, 3);
}

void render_ui(app_state& app) noexcept
{
    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplSDL3_NewFrame();
    ImGui::NewFrame();

    ImGui::SetNextWindowPos(ImVec2(16.0F, 16.0F), ImGuiCond_FirstUseEver);
    if (ImGui::Begin("web_app", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
        ImGui::TextUnformatted("SDL3 + OpenGL + Dear ImGui on WebAssembly");
        ImGui::Separator();
        ImGui::SliderFloat("speed", &app.speed, config::speed_min,
                           config::speed_max, "%.2fx");
        ImGui::Checkbox("Dear ImGui demo window", &app.show_demo_window);
        ImGui::Separator();
        ImGui::TextDisabled("%.1f fps | frame %llu", ImGui::GetIO().Framerate,
                            static_cast<unsigned long long>(app.frame_count));
    }
    ImGui::End();

    if (app.show_demo_window) {
        ImGui::ShowDemoWindow(&app.show_demo_window);
    }

    ImGui::Render();
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
}

} // namespace

// ---------------------------------------------------------------------------
// SDL3 application callbacks (entry points, browser-driven)
// ---------------------------------------------------------------------------

/// One-time init: SDL, window + GL context, GL entry points, shader program,
/// Dear ImGui. The state is published to SDL only after full success - SDL
/// zero-initializes `*appstate` and may still call `SDL_AppQuit` after a
/// failed init, so partial ownership must never escape.
SDL_AppResult SDL_AppInit(void** appstate, int /*argc*/, char** /*argv*/)
{
    SDL_SetAppMetadata(config::app_name.data(), config::app_version.data(),
                       config::app_id.data());

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        SDL_LogCritical(SDL_LOG_CATEGORY_APPLICATION, "SDL_Init failed: %s",
                        SDL_GetError());
        return SDL_APP_FAILURE;
    }

    auto app = std::make_unique<app_state>();

    // Order matters: context before GL resolution, program before ImGui.
    if (!create_window_and_context(*app) || !resolve_gl_entry_points()
        || !app->program.build(shaders::vertex, shaders::fragment)
        || !init_imgui(*app)) {
        shutdown(*app);
        return SDL_APP_FAILURE;
    }

    app->uniform_resolution = app->program.uniform_location("u_resolution");
    app->uniform_time = app->program.uniform_location("u_time");
    app->uniform_speed = app->program.uniform_location("u_speed");
    app->start_ticks_ns = SDL_GetTicksNS();

    const auto* renderer =
        reinterpret_cast<const char*>(gl.GetString(GL_RENDERER));
    const auto* version =
        reinterpret_cast<const char*>(gl.GetString(GL_VERSION));
    SDL_Log("web_app ready - renderer: %s | %s",
            renderer != nullptr ? renderer : "unknown",
            version != nullptr ? version : "unknown");

    *appstate = app.release();
    return SDL_APP_CONTINUE;
}

/// One frame: scene, UI, swap. Under Emscripten SDL calls this from
/// `requestAnimationFrame`, so it is implicitly vsynced and paused in
/// background tabs.
SDL_AppResult SDL_AppIterate(void* appstate)
{
    auto& app = *static_cast<app_state*>(appstate);

    render_scene(app);
    render_ui(app);
    SDL_GL_SwapWindow(app.window);

    ++app.frame_count;
    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppEvent(void* /*appstate*/, SDL_Event* event)
{
    ImGui_ImplSDL3_ProcessEvent(event);

    if (event->type == SDL_EVENT_QUIT) {
        return SDL_APP_SUCCESS; // browser tab closed / window close button
    }
    return SDL_APP_CONTINUE;
}

/// Final callback - also invoked after a failed `SDL_AppInit` (with nullptr
/// state in that case, since ownership was never handed over).
void SDL_AppQuit(void* appstate, SDL_AppResult /*result*/)
{
    if (appstate == nullptr) {
        return;
    }
    const std::unique_ptr<app_state> app(static_cast<app_state*>(appstate));
    shutdown(*app);
}
