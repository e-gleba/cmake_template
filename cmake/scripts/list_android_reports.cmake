# Lists Android instrumented-test reports for CI diagnostics. Never fails:
# the upload step behind it stays the strict gate.
#
#   cmake -DAPP_BUILD_DIR=android_project/app/build
#       -P cmake/scripts/list_android_reports.cmake

if(NOT DEFINED APP_BUILD_DIR OR APP_BUILD_DIR STREQUAL "")
    message(FATAL_ERROR "APP_BUILD_DIR is required (e.g. android_project/app/build)")
endif()

foreach(sub IN ITEMS outputs/androidTest-results reports/androidTests)
    if(IS_DIRECTORY "${APP_BUILD_DIR}/${sub}")
        message(STATUS "== ${sub} ==")
        file(
            GLOB_RECURSE
            report_files
            LIST_DIRECTORIES FALSE
            "${APP_BUILD_DIR}/${sub}/*")
        list(SORT report_files)
        foreach(report IN LISTS report_files)
            message(STATUS "${report}")
        endforeach()
    else()
        message(WARNING "${sub} not found under app/build")
    endif()
endforeach()
