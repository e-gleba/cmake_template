/// @file main.cpp
/// Self-contained SDL3 + OpenGL + Dear ImGui demo (target: web_app).
///
/// Cross-compiled to WebAssembly by the emscripten preset: SDL3 creates
/// a WebGL2 / GLES3 context and emcc emits a static site
/// (web_app.{html,js,wasm}). The code stays desktop-portable (OpenGL
/// 3.3 core) so a native target can reuse it unchanged.
///
/// Renders a fullscreen-triangle plasma - about the cheapest animated
/// shader possible: no textures, no buffers, vertex positions derived
/// from gl_VertexID. Shaders are inlined as constexpr string views, so
/// the web build needs zero asset preloading.

#define SDL_MAIN_USE_CALLBACKS 1
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#if defined(__EMSCRIPTEN__)
#include <GLES3/gl3.h>
#else
#include <SDL3/SDL_opengl.h>
#include <SDL3/SDL_opengl_glext.h>
#endif

#include <array>
#include <gsl/gsl>
#include <imgui.h>
#include <imgui_impl_opengl3.h>
#include <imgui_impl_sdl3.h>
#include <new>
#include <string_view>
#include <type_traits>

namespace {

/// GLSL version header per backend: WebGL2 / GLES3 on Emscripten, GL 3.3
/// core on desktop. GLES fragment shaders also need a default precision.
#if defined(__EMSCRIPTEN__)
constexpr std::string_view vertex_header{ "#version 300 es\n" };
constexpr std::string_view fragment_header{ "#version 300 es\n"
                                            "precision mediump float;\n" };
constexpr const char*      imgui_glsl_version{ "#version 300 es" };
#else
constexpr std::string_view vertex_header{ "#version 330 core\n" };
constexpr std::string_view fragment_header{ "#version 330 core\n" };
constexpr const char*      imgui_glsl_version{ "#version 330 core" };
#endif

/// Fullscreen triangle: 3 vertices, zero buffers - positions and UVs are
/// derived from the vertex id, so no VBO/EBO is ever created.
constexpr std::string_view vertex_source{ R"glsl(
out vec2 v_uv;

void main()
{
    vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    v_uv = p;
    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
}
)glsl" };

/// Cheap plasma: one length, one sin, one cosine palette per pixel.
constexpr std::string_view fragment_source{ R"glsl(
in vec2 v_uv;
out vec4 frag_color;

uniform float u_time;
uniform vec2  u_resolution;
uniform float u_speed;

vec3 palette(float t)
{
    return 0.5 + 0.5 * cos(6.2831853 * (t + vec3(0.0, 0.33, 0.67)));
}

void main()
{
    vec2 uv = (v_uv * u_resolution - 0.5 * u_resolution) / u_resolution.y;

    float d = length(uv);
    float t = u_time * u_speed;

    vec3 color = palette(d * 0.6 + t * 0.15);
    color *= 0.35 + 0.65 * (0.5 + 0.5 * sin(d * 12.0 - t * 2.5));

    frag_color = vec4(color, 1.0);
}
)glsl" };

/// Minimal GL entry-point table - exactly what the renderer below uses.
/// Resolved once through SDL_GL_GetProcAddress, which returns core and
/// extension symbols on every SDL3 GL backend (WebGL included), so the
/// demo needs no external GL loader dependency.
struct gl_api final
{
    GLuint (*create_shader)(GLenum stage){};
    void (*shader_source)(GLuint shader, GLsizei count,
                          const GLchar* const* string, const GLint* length){};
    void (*compile_shader)(GLuint shader){};
    void (*get_shader_iv)(GLuint shader, GLenum pname, GLint* params){};
    void (*get_shader_info_log)(GLuint shader, GLsizei buf_size,
                                GLsizei* length, GLchar* info_log){};
    void (*delete_shader)(GLuint shader){};
    GLuint (*create_program)(){};
    void (*attach_shader)(GLuint program, GLuint shader){};
    void (*link_program)(GLuint program){};
    void (*get_program_iv)(GLuint program, GLenum pname, GLint* params){};
    void (*get_program_info_log)(GLuint program, GLsizei buf_size,
                                 GLsizei* length, GLchar* info_log){};
    void (*use_program)(GLuint program){};
    void (*delete_program)(GLuint program){};
    GLint (*get_uniform_location)(GLuint program, const GLchar* name){};
    void (*uniform_1f)(GLint location, GLfloat v0){};
    void (*uniform_2f)(GLint location, GLfloat v0, GLfloat v1){};
    void (*gen_vertex_arrays)(GLsizei n, GLuint* arrays){};
    void (*bind_vertex_array)(GLuint array){};
    void (*delete_vertex_arrays)(GLsizei n, const GLuint* arrays){};
    void (*draw_arrays)(GLenum mode, GLint first, GLsizei count){};
    void (*viewport)(GLint x, GLint y, GLsizei width, GLsizei height){};
    void (*clear_color)(GLfloat red, GLfloat green, GLfloat blue,
                        GLfloat alpha){};
    void (*clear)(GLenum mask){};
};

/// Resolve every entry point. A context missing any of these cannot run
/// the demo at all, so fail fast and log the missing symbol.
[[nodiscard]] bool load_gl_api(gl_api& api) noexcept
{
    bool ok = true;

    const auto bind = [&ok](const char* name, auto& slot) noexcept {
        // Function-pointer to function-pointer cast: ISO C++ legal, so
        // no -Wpedantic diagnostic (unlike routing through void*).
        using proc_t = std::decay_t<decltype(slot)>;
        slot = reinterpret_cast<proc_t>(SDL_GL_GetProcAddress(name));
        if (slot == nullptr) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                         "missing GL entry point: %s",
                         name);
            ok = false;
        }
    };

    bind("glCreateShader", api.create_shader);
    bind("glShaderSource", api.shader_source);
    bind("glCompileShader", api.compile_shader);
    bind("glGetShaderiv", api.get_shader_iv);
    bind("glGetShaderInfoLog", api.get_shader_info_log);
    bind("glDeleteShader", api.delete_shader);
    bind("glCreateProgram", api.create_program);
    bind("glAttachShader", api.attach_shader);
    bind("glLinkProgram", api.link_program);
    bind("glGetProgramiv", api.get_program_iv);
    bind("glGetProgramInfoLog", api.get_program_info_log);
    bind("glUseProgram", api.use_program);
    bind("glDeleteProgram", api.delete_program);
    bind("glGetUniformLocation", api.get_uniform_location);
    bind("glUniform1f", api.uniform_1f);
    bind("glUniform2f", api.uniform_2f);
    bind("glGenVertexArrays", api.gen_vertex_arrays);
    bind("glBindVertexArray", api.bind_vertex_array);
    bind("glDeleteVertexArrays", api.delete_vertex_arrays);
    bind("glDrawArrays", api.draw_arrays);
    bind("glViewport", api.viewport);
    bind("glClearColor", api.clear_color);
    bind("glClear", api.clear);

    return ok;
}

/// Compile one shader stage from version header + body chunks.
/// Returns 0 on failure and logs the compiler output.
[[nodiscard]] GLuint compile_shader(const gl_api&          gl,
                                    const GLenum           stage,
                                    const std::string_view header,
                                    const std::string_view body) noexcept
{
    const GLuint shader = gl.create_shader(stage);

    const std::array chunks{ header.data(), body.data() };
    const std::array lengths{ gsl::narrow_cast<GLint>(header.size()),
                              gsl::narrow_cast<GLint>(body.size()) };
    gl.shader_source(shader,
                     gsl::narrow_cast<GLsizei>(chunks.size()),
                     chunks.data(),
                     lengths.data());
    gl.compile_shader(shader);

    GLint status = GL_FALSE;
    gl.get_shader_iv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_TRUE) {
        return shader;
    }

    std::array<GLchar, 4096> log{};
    gl.get_shader_info_log(shader,
                           gsl::narrow_cast<GLsizei>(log.size()),
                           nullptr,
                           log.data());
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "shader compilation failed:\n%s",
                 log.data());
    gl.delete_shader(shader);
    return 0;
}

/// Link a vertex + fragment shader pair. Returns 0 on failure and logs
/// the linker output.
[[nodiscard]] GLuint link_program(const gl_api& gl,
                                  const GLuint  vertex_shader,
                                  const GLuint  fragment_shader) noexcept
{
    const GLuint program = gl.create_program();
    gl.attach_shader(program, vertex_shader);
    gl.attach_shader(program, fragment_shader);
    gl.link_program(program);

    GLint status = GL_FALSE;
    gl.get_program_iv(program, GL_LINK_STATUS, &status);
    if (status == GL_TRUE) {
        return program;
    }

    std::array<GLchar, 4096> log{};
    gl.get_program_info_log(program,
                            gsl::narrow_cast<GLsizei>(log.size()),
                            nullptr,
                            log.data());
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                 "program link failed:\n%s",
                 log.data());
    gl.delete_program(program);
    return 0;
}

/// Application state carried through the SDL3 callbacks.
/// SDL passes this opaque pointer to every callback after init.
struct app_state final
{
    SDL_Window*   window{};
    SDL_GLContext gl_context{};
    gl_api        gl{};
    GLuint        program{};
    GLuint        vao{};
    GLint         u_time{};
    GLint         u_resolution{};
    GLint         u_speed{};
    Uint64        start_ticks{};
    float         speed{ 1.0F };
    bool          show_demo_window{};
    bool          imgui_ready{};
};

/// Release everything SDL_AppInit may have acquired. Safe on partially
/// initialized state: members are zero-initialized and every resource is
/// checked before destruction.
void destroy_app(app_state* state) noexcept
{
    if (state == nullptr) {
        return;
    }
    if (state->imgui_ready) {
        ImGui_ImplOpenGL3_Shutdown();
        ImGui_ImplSDL3_Shutdown();
        ImGui::DestroyContext();
    }
    if (state->program != 0) {
        state->gl.delete_program(state->program);
    }
    if (state->vao != 0) {
        state->gl.delete_vertex_arrays(1, &state->vao);
    }
    if (state->gl_context != nullptr) {
        SDL_GL_DestroyContext(state->gl_context);
    }
    if (state->window != nullptr) {
        SDL_DestroyWindow(state->window);
    }
    delete state;
}

} // namespace

/// Called once at startup. Creates the window, GL context, shader program
/// and ImGui backends.
/// @param appstate  [out] Pointer to application state; SDL manages lifetime.
/// @param argc      Argument count forwarded from the platform entry point.
/// @param argv      Argument vector forwarded from the platform entry point.
/// @return SDL_APP_CONTINUE on success, SDL_APP_FAILURE on error.
SDL_AppResult SDL_AppInit(void**                 appstate,
                          [[maybe_unused]] int   argc,
                          [[maybe_unused]] char* argv[])
{
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_Init failed: %s",
                     SDL_GetError());
        return SDL_APP_FAILURE;
    }

    // GL attributes must be set before the window is created.
#if defined(__EMSCRIPTEN__)
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,
                        SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
#else
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,
                        SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
#endif
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    constexpr int window_width  = 1280;
    constexpr int window_height = 720;

    SDL_Window* window =
        SDL_CreateWindow("cmake_template | SDL3 + OpenGL + ImGui",
                         window_width,
                         window_height,
                         SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE |
                             SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (window == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_CreateWindow failed: %s",
                     SDL_GetError());
        return SDL_APP_FAILURE;
    }

    SDL_GLContext gl_context = SDL_GL_CreateContext(window);
    if (gl_context == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_GL_CreateContext failed: %s",
                     SDL_GetError());
        SDL_DestroyWindow(window);
        return SDL_APP_FAILURE;
    }
    if (!SDL_GL_MakeCurrent(window, gl_context)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_GL_MakeCurrent failed: %s",
                     SDL_GetError());
        SDL_GL_DestroyContext(gl_context);
        SDL_DestroyWindow(window);
        return SDL_APP_FAILURE;
    }

    // Vsync where the platform allows it; the browser always uses rAF.
    (void)SDL_GL_SetSwapInterval(1);

    auto* state = new (std::nothrow) app_state{};
    if (state == nullptr) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "failed to allocate app_state");
        SDL_GL_DestroyContext(gl_context);
        SDL_DestroyWindow(window);
        return SDL_APP_FAILURE;
    }
    state->window      = window;
    state->gl_context  = gl_context;
    state->start_ticks = SDL_GetTicks();

    if (!load_gl_api(state->gl)) {
        destroy_app(state);
        return SDL_APP_FAILURE;
    }

    const GLuint vertex_shader = compile_shader(
        state->gl, GL_VERTEX_SHADER, vertex_header, vertex_source);
    const GLuint fragment_shader =
        vertex_shader != 0 ? compile_shader(state->gl,
                                            GL_FRAGMENT_SHADER,
                                            fragment_header,
                                            fragment_source)
                           : 0;
    if (vertex_shader != 0 && fragment_shader != 0) {
        state->program =
            link_program(state->gl, vertex_shader, fragment_shader);
    }
    if (vertex_shader != 0) {
        state->gl.delete_shader(vertex_shader);
    }
    if (fragment_shader != 0) {
        state->gl.delete_shader(fragment_shader);
    }
    if (state->program == 0) {
        destroy_app(state);
        return SDL_APP_FAILURE;
    }

    state->u_time = state->gl.get_uniform_location(state->program, "u_time");
    state->u_resolution =
        state->gl.get_uniform_location(state->program, "u_resolution");
    state->u_speed =
        state->gl.get_uniform_location(state->program, "u_speed");

    // A bound VAO is mandatory in a core profile. It stays empty - the
    // triangle is generated from gl_VertexID.
    state->gl.gen_vertex_arrays(1, &state->vao);

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsDark();

    if (!ImGui_ImplSDL3_InitForOpenGL(window, gl_context)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "ImGui SDL3 backend init failed");
        ImGui::DestroyContext();
        destroy_app(state);
        return SDL_APP_FAILURE;
    }
    if (!ImGui_ImplOpenGL3_Init(imgui_glsl_version)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "ImGui OpenGL3 backend init failed");
        ImGui_ImplSDL3_Shutdown();
        ImGui::DestroyContext();
        destroy_app(state);
        return SDL_APP_FAILURE;
    }
    state->imgui_ready = true;

    // Publish only on success: SDL zero-initializes *appstate before
    // this call, and SDL_AppQuit may still run after a failed init -
    // a dangling pointer here would double-free.
    *appstate = state;
    return SDL_APP_CONTINUE;
}

/// Called once per frame by SDL. Renders the plasma and the ImGui overlay.
SDL_AppResult SDL_AppIterate(void* appstate)
{
    auto*       state = static_cast<app_state*>(appstate);
    const auto& gl    = state->gl;

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplSDL3_NewFrame();
    ImGui::NewFrame();

    ImGui::SetNextWindowPos(ImVec2{ 16.0F, 16.0F }, ImGuiCond_FirstUseEver);
    ImGui::Begin("plasma", nullptr, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::Text("%.1f FPS", ImGui::GetIO().Framerate);
    ImGui::SliderFloat("speed", &state->speed, 0.0F, 4.0F);
    ImGui::Checkbox("imgui demo window", &state->show_demo_window);
    ImGui::End();

    if (state->show_demo_window) {
        ImGui::ShowDemoWindow(&state->show_demo_window);
    }

    ImGui::Render();

    int pixel_width  = 0;
    int pixel_height = 0;
    if (!SDL_GetWindowSizeInPixels(state->window,
                                   &pixel_width,
                                   &pixel_height)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_GetWindowSizeInPixels failed: %s",
                     SDL_GetError());
        return SDL_APP_FAILURE;
    }

    gl.viewport(0, 0, pixel_width, pixel_height);
    gl.clear_color(0.02F, 0.03F, 0.05F, 1.0F);
    gl.clear(GL_COLOR_BUFFER_BIT);

    const float seconds =
        gsl::narrow_cast<float>(SDL_GetTicks() - state->start_ticks) /
        1000.0F;

    gl.use_program(state->program);
    gl.uniform_1f(state->u_time, seconds);
    gl.uniform_2f(state->u_resolution,
                  gsl::narrow_cast<GLfloat>(pixel_width),
                  gsl::narrow_cast<GLfloat>(pixel_height));
    gl.uniform_1f(state->u_speed, state->speed);
    gl.bind_vertex_array(state->vao);
    gl.draw_arrays(GL_TRIANGLES, 0, 3);

    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

    if (!SDL_GL_SwapWindow(state->window)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "SDL_GL_SwapWindow failed: %s",
                     SDL_GetError());
        return SDL_APP_FAILURE;
    }
    return SDL_APP_CONTINUE;
}

/// Called for every pending event. Feeds ImGui and handles quit requests.
SDL_AppResult SDL_AppEvent(void* appstate, SDL_Event* event)
{
    auto* state = static_cast<app_state*>(appstate);

    ImGui_ImplSDL3_ProcessEvent(event);

    if (event->type == SDL_EVENT_QUIT) {
        return SDL_APP_SUCCESS;
    }
    if (event->type == SDL_EVENT_WINDOW_CLOSE_REQUESTED &&
        event->window.windowID == SDL_GetWindowID(state->window)) {
        return SDL_APP_SUCCESS;
    }
    return SDL_APP_CONTINUE;
}

/// Called once on shutdown. Frees application state; SDL calls SDL_Quit()
/// for us.
void SDL_AppQuit(void* appstate, [[maybe_unused]] SDL_AppResult result)
{
    destroy_app(static_cast<app_state*>(appstate));
    // SDL_Quit() is called automatically by SDL after this returns
}
