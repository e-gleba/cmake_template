# --- ct_add_executable ------------------------------------------------------
# The single "executable vs library" platform fork: Android has no
# executables - apps are SHARED libraries loaded through NativeActivity.
# Everywhere else this is plain add_executable().
# Replaces the per-directory
#   if(CMAKE_SYSTEM_NAME STREQUAL "Android") add_library(SHARED) ...
# copies across src/ and tests/.

include_guard(GLOBAL)

function(ct_add_executable name)
    if(CMAKE_SYSTEM_NAME STREQUAL "Android")
        add_library(${name} SHARED)
    else()
        add_executable(${name})
    endif()
endfunction()
