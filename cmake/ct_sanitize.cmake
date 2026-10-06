# --- sanitize -----------------------------------------------------------------
# Sanitizer flags as per-sanitizer INTERFACE targets under one umbrella:
# ct_address_sanitizer / ct_undefined_behavior_sanitizer / ct_thread_sanitizer
# carry their own flags, and ct_sanitize links whichever the CT_*_SANITIZER
# options enable (set by the sanitize_* preset fragments; sanitize_asan_ubsan
# composes the asan+ubsan fragments via inherits).
# Link the umbrella PRIVATE into every first-party target - never PUBLIC:
# consumers of an installed package must not inherit our instrumentation.
#
# All options off (default) keeps zero-cost builds: the targets exist but
# carry no flags, so non-sanitizer presets are unaffected.

include_guard(GLOBAL)

option(CT_ADDRESS_SANITIZER "Build first-party targets with AddressSanitizer"
       OFF)
option(
    CT_UNDEFINED_BEHAVIOR_SANITIZER
    "Build first-party targets with UndefinedBehaviorSanitizer (aborts on first error)"
    OFF)
option(
    CT_THREAD_SANITIZER
    "Build first-party targets with ThreadSanitizer (cannot combine with AddressSanitizer)"
    OFF)

add_library(ct_address_sanitizer INTERFACE)
add_library(ct_undefined_behavior_sanitizer INTERFACE)
add_library(ct_thread_sanitizer INTERFACE)
add_library(ct_sanitize INTERFACE)
add_library(CT::sanitize ALIAS ct_sanitize)

if(CT_THREAD_SANITIZER AND CT_ADDRESS_SANITIZER)
    message(
        FATAL_ERROR
            [[CT_THREAD_SANITIZER and CT_ADDRESS_SANITIZER cannot be combined (TSan is incompatible with ASan)]]
    )
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" AND (CT_UNDEFINED_BEHAVIOR_SANITIZER
                                              OR CT_THREAD_SANITIZER))
    message(
        FATAL_ERROR
            [[MSVC sanitizers: only CT_ADDRESS_SANITIZER (/fsanitize=address) is supported]]
    )
endif()

# -g keeps reports symbolized outside Debug; -fno-omit-frame-pointer
# sharpens ASan/TSan stacks; -fno-sanitize-recover=all makes UBSan
# abort on first error (required for CI signal).
if(CT_ADDRESS_SANITIZER)
    target_compile_options(
        ct_address_sanitizer
        INTERFACE
            "$<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang,AppleClang>:-fsanitize=address;-fno-omit-frame-pointer;-g>"
            "$<$<COMPILE_LANG_AND_ID:C,GNU,Clang,AppleClang>:-fsanitize=address;-fno-omit-frame-pointer;-g>"
            "$<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/fsanitize=address>"
            "$<$<COMPILE_LANG_AND_ID:C,MSVC>:/fsanitize=address>")
    target_link_options(
        ct_address_sanitizer
        INTERFACE
        "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=address>"
        "$<$<CXX_COMPILER_ID:MSVC>:/fsanitize=address>")
    target_link_libraries(ct_sanitize INTERFACE ct_address_sanitizer)
endif()

if(CT_UNDEFINED_BEHAVIOR_SANITIZER)
    target_compile_options(
        ct_undefined_behavior_sanitizer
        INTERFACE
            "$<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang,AppleClang>:-fsanitize=undefined;-fno-sanitize-recover=all;-g>"
            "$<$<COMPILE_LANG_AND_ID:C,GNU,Clang,AppleClang>:-fsanitize=undefined;-fno-sanitize-recover=all;-g>"
    )
    target_link_options(
        ct_undefined_behavior_sanitizer
        INTERFACE
        "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=undefined;-fno-sanitize-recover=all>"
    )
    target_link_libraries(ct_sanitize INTERFACE ct_undefined_behavior_sanitizer)
endif()

if(CT_THREAD_SANITIZER)
    target_compile_options(
        ct_thread_sanitizer
        INTERFACE
            "$<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang,AppleClang>:-fsanitize=thread;-fno-omit-frame-pointer;-g>"
            "$<$<COMPILE_LANG_AND_ID:C,GNU,Clang,AppleClang>:-fsanitize=thread;-fno-omit-frame-pointer;-g>"
    )
    target_link_options(
        ct_thread_sanitizer INTERFACE
        "$<$<CXX_COMPILER_ID:GNU,Clang,AppleClang>:-fsanitize=thread>")
    target_link_libraries(ct_sanitize INTERFACE ct_thread_sanitizer)
endif()
