#!/usr/bin/env python3
"""House-rules hook: refuse banned CMake/C++ patterns on edit or --staged.

Usage as opencode/Claude edit hook (reads JSON payload from stdin),
or as a pre-commit check: python3 tools/rules/hook.py --staged
Exit 0 = clean, 1/2 = violations.

Pattern from telegramdesktop/tdesktop@dev, tools/rules/hook.py
(https://github.com/telegramdesktop/tdesktop/blob/dev/tools/rules/hook.py):
edit-hook stdin-JSON + --staged dual mode. All checks below are original
to this repo (CMake/C++ bans per AGENTS.md + REVIEW.md); no lines copied.
Same license as this repo (MIT, see license.md).
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CMAKE_BANNED = [
    (r"\binclude_directories\s*\(", "use target_include_directories()"),
    (r"\blink_libraries\s*\(", "use target_link_libraries()"),
    (r"\badd_definitions\s*\(", "use target_compile_definitions()"),
    (r"\bfile\s*\(\s*GLOB\b", "list sources explicitly, no file(GLOB)"),
    (r"CMAKE_CXX_FLAGS(?!_)", "use target_compile_options(), never CMAKE_CXX_FLAGS"),
    (r"CMAKE_BUILD_TYPE", "preset owns CMAKE_BUILD_TYPE, not CMakeLists"),
]

CPP_BANNED = [
    (r"\bnew\s+\w", "RAII only, no new/delete"),
    (r"\bdelete\b", "RAII only, no new/delete"),
    (r"static_cast\s*<\s*void\s*>", "never discard [[nodiscard]] with a cast"),
    (r"\(void\)", "never discard [[nodiscard]] with a cast"),
    (r"using\s+namespace\b", "never add file-scope using namespace"),
]


def check_text(text: str, is_cmake: bool) -> list[str]:
    errors: list[str] = []
    patterns = CMAKE_BANNED if is_cmake else CPP_BANNED
    for pattern, fix in patterns:
        if re.search(pattern, text):
            errors.append(f"banned `{pattern}` -- {fix}")
    return errors


def written(payload: dict) -> str:
    tool = payload.get("tool_input") or {}
    parts = [tool.get("new_string") or "", tool.get("content") or ""]
    parts += [e.get("new_string") or "" for e in tool.get("edits") or []]
    return "\n".join(parts)


def staged() -> int:
    diff = subprocess.run(
        ["git", "diff", "--cached", "-U0", "-M"],
        capture_output=True,
        text=True,
    ).stdout
    path, bad = "", 0
    for line in diff.split("\n"):
        if line.startswith("+++ b/"):
            path = line[6:]
        elif line.startswith("+") and not line.startswith("+++"):
            is_cmake = path.endswith(".cmake") or path.endswith("CMakeLists.txt")
            is_cpp = path.endswith((".cpp", ".h", ".hpp", ".cppm", ".cxx"))
            if is_cmake or is_cpp:
                for err in check_text(line[1:], is_cmake):
                    print(f"{path}: {err}", file=sys.stderr)
                    bad += 1
    return 1 if bad else 0


def main() -> int:
    if "--staged" in sys.argv:
        return staged()
    try:
        payload = json.load(sys.stdin)
    except (ValueError, OSError):
        return 0
    tool = (payload.get("tool_input") or {}).get("file_path", "")
    resp = (payload.get("tool_response") or {}).get("filePath", "")
    path = resp or tool
    is_cmake = path.endswith(".cmake") or path.endswith("CMakeLists.txt")
    is_cpp = path.endswith((".cpp", ".h", ".hpp", ".cppm", ".cxx"))
    if not (is_cmake or is_cpp):
        return 0
    errors = check_text(written(payload), is_cmake)
    for err in errors:
        print(f"{Path(path).name}: {err}", file=sys.stderr)
    if errors:
        print(
            "Rules live in AGENTS.md + REVIEW.md. Fix before anything else.",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
