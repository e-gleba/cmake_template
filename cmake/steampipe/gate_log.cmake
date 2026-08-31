# Shared log helpers for the cmake -P gate scripts in this directory.
# message() prefixes every line ("-- ", "CMake Error: ..."), which breaks
# GitHub Actions ::error parsing — print raw through cmake -E echo instead.
#
# gate_echo("<text>")  — one raw stdout line
# gate_error("<text>") — ::error annotation; increments `failures`
#                        (the including script must define it)

macro(gate_echo text)
    execute_process(COMMAND "${CMAKE_COMMAND}" -E echo "${text}")
endmacro()

macro(gate_error text)
    execute_process(COMMAND "${CMAKE_COMMAND}" -E echo "::error ${text}")
    math(EXPR failures "${failures} + 1")
endmacro()
