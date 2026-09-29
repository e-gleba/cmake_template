cpmaddpackage(
    NAME
    flecs
    GITHUB_REPOSITORY
    SanderMertens/flecs
    GIT_TAG
    v4.1.5
    GIT_SHALLOW
    ON
    EXCLUDE_FROM_ALL
    ON
    SYSTEM
    ON
    OPTIONS
    "FLECS_STATIC ON"
    "FLECS_SHARED OFF"
    "FLECS_TESTS OFF")
