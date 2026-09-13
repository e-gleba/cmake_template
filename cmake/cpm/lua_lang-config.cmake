cpmaddpackage(
    NAME
    lua
    GIT_REPOSITORY
    https://github.com/lua/lua.git
    VERSION
    5.5.1
    DOWNLOAD_ONLY
    YES)

file(
    GLOB
    lua_sources
    CONFIGURE_DEPENDS
    "${lua_SOURCE_DIR}/*.c")

list(
    REMOVE_ITEM
    lua_sources
    "${lua_SOURCE_DIR}/lua.c" # Interpreter
    "${lua_SOURCE_DIR}/luac.c" # Compiler
    "${lua_SOURCE_DIR}/onelua.c" # Single-file build
)

add_library(lua STATIC ${lua_sources})

set_target_properties(lua PROPERTIES
  C_EXTENSIONS OFF
  POSITION_INDEPENDENT_CODE TRUE
  EXCLUDE_FROM_ALL TRUE
  C_CLANG_TIDY ""
  CXX_CLANG_TIDY ""
  C_CPPCHECK ""
  CXX_CPPCHECK ""
  COMPILE_WARNING_AS_ERROR OFF)

target_include_directories(lua SYSTEM
                           PUBLIC $<BUILD_INTERFACE:${lua_SOURCE_DIR}>)

target_compile_features(lua PUBLIC c_std_23)

target_compile_definitions(
    lua
    PUBLIC LUA_COMPAT_5_3=0
           $<$<CONFIG:Debug>:LUA_USE_APICHECK>
    PRIVATE $<$<C_COMPILER_ID:GNU,Clang,AppleClang>:LUA_USE_JUMPTABLE>
)

target_compile_options(lua PRIVATE
  $<$<C_COMPILER_FRONTEND_VARIANT:MSVC>:/W0>
  $<$<NOT:$<C_COMPILER_FRONTEND_VARIANT:MSVC>>:-w>)

add_library(lua::lua ALIAS lua)
