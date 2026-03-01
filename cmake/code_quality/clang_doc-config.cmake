if(NOT CMAKE_EXPORT_COMPILE_COMMANDS)
    message(
        NOTICE
        "clang-doc requires CMAKE_EXPORT_COMPILE_COMMANDS=ON "
        "to produce correct output. Set it in your root "
        "CMakeLists.txt or preset. The clang_doc target will "
        "be created but may produce incomplete documentation.")
    return()
endif()

find_program(
    clang_doc_exe
    NAMES clang-doc
    DOC "clang-doc: generates C/C++ code documentation from source. Install: 'sudo dnf install clang-tools-extra', 'sudo apt install clang-tools-extra', 'brew install llvm', or 'choco install llvm'. Required for 'clang_doc' target."
)

if(NOT clang_doc_exe)
    message(
        NOTICE
        "clang-doc not found — 'clang_doc' target will not be available.\n"
        "Install:\n"
        "  Fedora:  sudo dnf install clang-tools-extra\n"
        "  Ubuntu:  sudo apt install clang-tools-extra\n"
        "  macOS:   brew install llvm\n"
        "  Windows: choco install llvm")
    return()
endif()

set(clang_doc_output_dir "${CMAKE_BINARY_DIR}/clang-doc")

add_custom_target(
    clang_doc
    COMMAND
        "${clang_doc_exe}"
        # Point to compilation database for include paths,
        # defines, and file list.
        -p "${CMAKE_BINARY_DIR}"
        # Output format: html, md, or yaml.
        --format=html
        # Output directory.
        --output="${clang_doc_output_dir}"
        # Generate a main index page.
        --public
        # Process all files in compile_commands.json whose
        # paths contain these source directories. This
        # filters out third-party / dependency sources.
        "${PROJECT_SOURCE_DIR}/src" "${PROJECT_SOURCE_DIR}/include"
    WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
    VERBATIM
    COMMENT "Running clang-doc to generate HTML documentation"
    USES_TERMINAL)
