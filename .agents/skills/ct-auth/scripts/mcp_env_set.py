#!/usr/bin/env python3
"""Store one secret VAR in ct_project.env via hidden console input.

Single source of truth: ~/.config/opencode/ct_project.env
(override with CT_PROJECT_ENV_PATH).

Usage:
    python3 mcp_env_set.py VAR [--check] [--launch] [--url URL] [--instructions TEXT]

The masked prompt has a hard 5-minute deadline (INPUT_TIMEOUT); the user
is told so before typing. --url auto-opens the token page; --instructions
carries the AI-written steps (what to create + the URL as plain text, for
windows where auto-open fails) and is required for every prompt run.

Exit codes: 0 saved (or set, with --check); 1 missing, aborted, timed out,
or failed; 2 rerun in a terminal (manual command printed, nothing opened).
"""

from __future__ import annotations

import argparse
import getpass
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import webbrowser
from pathlib import Path

VAR_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_PLAIN_RE = re.compile(r"[A-Za-z0-9_@%+/:.,-]+")
LINE_RE = re.compile(
    r"^[^\S\n]*(?:export[^\S\n]+)?([A-Za-z_][A-Za-z0-9_]*)[^\S\n]*=[^\S\n]*(.*?)[^\S\n]*$",
    re.MULTILINE,
)
INPUT_TIMEOUT = 300


def env_file() -> Path:
    override = os.environ.get("CT_PROJECT_ENV_PATH", "").strip()
    if override:
        return Path(override).expanduser()
    base = os.environ.get("XDG_CONFIG_HOME", "").strip()
    root = Path(base).expanduser() if base else Path.home() / ".config"
    return root / "opencode" / "ct_project.env"


def _unescape_doublequoted(inner: str) -> str:
    """Undo format_value escaping: `\"` -> `"`, `\\` -> `\\`."""
    out: list[str] = []
    i = 0
    while i < len(inner):
        ch = inner[i]
        if ch == "\\" and i + 1 < len(inner) and inner[i + 1] in ('"', "\\"):
            out.append(inner[i + 1])
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def parse(text: str) -> dict[str, str]:
    text = text.removeprefix("\ufeff")
    out: dict[str, str] = {}
    for match in LINE_RE.finditer(text):
        key, raw = match.group(1), match.group(2)
        if len(raw) > 1 and raw[0] == '"' and raw[-1] == '"':
            raw = _unescape_doublequoted(raw[1:-1])
        elif len(raw) > 1 and raw[0] == "'" and raw[-1] == "'":
            raw = raw[1:-1]
        out[key] = raw
    return out


def format_value(value: str) -> str:
    """Quote for ct_project.env so parse() round-trips."""
    if "\n" in value or "\r" in value:
        raise ValueError("value must be a single line")
    if _PLAIN_RE.fullmatch(value) is not None:
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def save(var: str, value: str) -> Path:
    target = env_file()
    line = var + "=" + format_value(value)
    text = target.read_text(encoding="utf-8") if target.exists() else ""
    lines = text.splitlines()
    for i, existing in enumerate(lines):
        match = LINE_RE.match(existing)
        if match and match.group(1) == var:
            lines[i] = line
            break
    else:
        lines.append(line)
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_name(target.name + ".tmp")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if os.name != "nt":
        os.chmod(tmp, 0o600)
    os.replace(tmp, target)
    return target


def is_set(var: str) -> bool:
    if os.environ.get(var, "").strip():
        return True
    try:
        text = env_file().read_text(encoding="utf-8")
    except OSError:
        return False
    return bool(parse(text).get(var, "").strip())


def set_title(text: str) -> None:
    if os.name != "nt" and sys.stdout.isatty():
        sys.stdout.write(f"\033]0;{text}\007")
        sys.stdout.flush()


def read_masked(prompt_text: str, timeout: int = INPUT_TIMEOUT) -> str:
    """One hidden line with `*` feedback and a hard deadline.

    Raises OSError when stdin has no TTY, TimeoutError on expiry.
    getpass cannot do deadlines portably, hence the ~40 lines.
    """
    if not sys.stdin.isatty():
        raise OSError("stdin has no TTY (not a terminal)")
    deadline = time.time() + timeout
    sys.stdout.write(prompt_text)
    sys.stdout.flush()
    restore = None
    fd = -1
    termios_mod = None
    if os.name == "nt":
        import msvcrt

        def getch() -> str:
            while not msvcrt.kbhit():
                if time.time() > deadline:
                    raise TimeoutError
                time.sleep(0.05)
            return msvcrt.getwch()

    else:
        import select
        import termios
        import tty

        termios_mod = termios
        fd = sys.stdin.fileno()
        try:
            restore = termios.tcgetattr(fd)
        except (OSError, termios.error) as exc:
            raise OSError(f"stdin has no TTY ({exc})") from exc
        tty.setraw(fd)

        def getch() -> str:
            wait = deadline - time.time()
            if wait <= 0:
                raise TimeoutError
            ready, _, _ = select.select([fd], [], [], min(wait, 0.2))
            if not ready:
                return ""
            return os.read(fd, 1).decode("utf-8", "replace")

    buf: list[str] = []
    try:
        while True:
            ch = getch()
            if not ch:
                continue
            if ch in ("\r", "\n"):
                sys.stdout.write("\n")
                return "".join(buf)
            if ch == "\x03":
                raise KeyboardInterrupt
            if ch in ("\x08", "\x7f"):
                if buf:
                    buf.pop()
                    sys.stdout.write("\b \b")
                    sys.stdout.flush()
                continue
            buf.append(ch)
            sys.stdout.write("*")
            sys.stdout.flush()
    finally:
        if restore is not None and termios_mod is not None:
            termios_mod.tcsetattr(fd, termios_mod.TCSADRAIN, restore)


def prompt(var: str, url: str, instructions: str) -> int:
    set_title(f"MCP auth: {var}")
    if url:
        print("Opening token page...")
        try:
            opened = webbrowser.open(url)
        except (OSError, webbrowser.Error) as exc:
            print(
                f"Could not open browser ({exc}); open {url} manually.", file=sys.stderr
            )
        else:
            if not opened:
                print(f"Open {url} manually.", file=sys.stderr)
    if instructions:
        print(instructions.replace("\\n", "\n"))
    print(
        f"Input is hidden (***). You have {INPUT_TIMEOUT // 60} minutes, "
        "then this closes itself."
    )
    while True:
        try:
            try:
                value = read_masked(f"{var}: ").strip()
            except OSError:
                value = getpass.getpass(f"{var}: ").strip()
        except TimeoutError:
            print(f"Timed out after {INPUT_TIMEOUT // 60} minutes, nothing saved.")
            return 1
        except (KeyboardInterrupt, EOFError):
            print("Aborted, nothing saved.")
            return 1
        if not value:
            print("Empty input, please try again (Ctrl-C to abort).")
            continue
        break
    try:
        where = save(var, value)
    except (OSError, ValueError) as exc:
        print(f"Save failed: {exc}", file=sys.stderr)
        return 1
    print(f"{var}: saved to {where}")
    return 0


def manual(var: str, url: str, instructions: str, reason: str) -> int:
    parts = ["python3 .agents/skills/ct-auth/scripts/mcp_env_set.py", var]
    if url:
        parts.append(f"--url {shlex.quote(url)}")
    if instructions:
        parts.append(f"--instructions {shlex.quote(instructions)}")
    print(f"{reason} run this in a terminal (opens nothing here):", file=sys.stderr)
    print(f"  {' '.join(parts)}", file=sys.stderr)
    return 2


def run_windowed(child: list[str], var: str) -> int | None:
    if os.name == "nt":
        argv = ["cmd", "/c", "start", f'"MCP auth: {var}"', "/wait", *child]
    elif sys.platform == "darwin":
        return run_macos(child)
    else:
        if not (
            os.environ.get("DISPLAY", "").strip()
            or os.environ.get("WAYLAND_DISPLAY", "").strip()
        ):
            return None
        term = next(
            (t for t in ("konsole", "gnome-terminal", "xterm") if shutil.which(t)), None
        )
        if term is None:
            return None
        if term == "konsole":
            argv = [term, "--separate", "--nofork", "-e", *child]
        elif term == "gnome-terminal":
            argv = [term, "--wait", "--", *child]
        else:
            argv = [term, "-e", *child]
    try:
        done = subprocess.run(argv, check=False, timeout=INPUT_TIMEOUT)
    except (FileNotFoundError, OSError) as exc:
        print(f"Window launch failed: {exc}", file=sys.stderr)
        return 1
    except subprocess.TimeoutExpired:
        print(f"Timed out after {INPUT_TIMEOUT // 60} minutes, nothing saved.")
        return 1
    return done.returncode


def run_macos(child: list[str]) -> int | None:
    try:
        fd, sentinel = tempfile.mkstemp(prefix="mcp_env_")
    except OSError as exc:
        print(f"Sentinel file failed: {exc}", file=sys.stderr)
        return None
    os.close(fd)
    cmd = " ".join(shlex.quote(a) for a in child)
    cmd += f"; code=$?; echo $code > {shlex.quote(sentinel)}"
    osa = cmd.replace("\\", "\\\\").replace('"', '\\"')
    try:
        done = subprocess.run(
            ["osascript", "-e", f'tell application "Terminal" to do script "{osa}"'],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (FileNotFoundError, OSError) as exc:
        print(f"Terminal launch failed: {exc}", file=sys.stderr)
        Path(sentinel).unlink(missing_ok=True)
        return None
    except subprocess.TimeoutExpired:
        print("Terminal launch timed out.", file=sys.stderr)
        Path(sentinel).unlink(missing_ok=True)
        return None
    if done.returncode != 0:
        print(f"Terminal launch refused: {done.stderr.strip()}", file=sys.stderr)
        Path(sentinel).unlink(missing_ok=True)
        return None
    deadline = time.time() + INPUT_TIMEOUT
    while time.time() < deadline:
        try:
            code = Path(sentinel).read_text(encoding="utf-8").strip()
        except OSError:
            code = ""
        if code:
            Path(sentinel).unlink(missing_ok=True)
            try:
                return int(code)
            except ValueError:
                return 1
        time.sleep(0.5)
    print(f"Timed out after {INPUT_TIMEOUT // 60} minutes, nothing saved.")
    Path(sentinel).unlink(missing_ok=True)
    return 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Store one secret VAR in ct_project.env."
    )
    parser.add_argument("var", help="VAR name ([A-Za-z_][A-Za-z0-9_]*)")
    parser.add_argument(
        "--check", action="store_true", help="print set/missing, never prompts"
    )
    parser.add_argument(
        "--launch", action="store_true", help="no TTY: open one prompt window and wait"
    )
    parser.add_argument("--url", default="", help="token page to open first")
    parser.add_argument(
        "--instructions",
        default="",
        help="steps shown to the user (use \\n for new lines); "
        "the AI always passes what to create and where",
    )
    args = parser.parse_args(argv[1:])
    if VAR_RE.fullmatch(args.var) is None:
        parser.error("bad VAR name")
    if args.check:
        ok = is_set(args.var)
        print(f"{args.var}: {'set' if ok else 'missing'}")
        return 0 if ok else 1
    if sys.stdin.isatty():
        return prompt(args.var, args.url, args.instructions)
    if not args.launch:
        return manual(args.var, args.url, args.instructions, "stdin has no TTY;")
    script = str(Path(__file__).resolve())
    child = [sys.executable, script, args.var]
    if args.url:
        child += ["--url", args.url]
    if args.instructions:
        child += ["--instructions", args.instructions]
    print(f"Opening one prompt window for {args.var}; waiting...")
    code = run_windowed(child, args.var)
    if code is None:
        return manual(
            args.var, args.url, args.instructions, "No window available here;"
        )
    if code == 0:
        print(f"{args.var}: saved.")
        return 0
    print(
        f"{args.var}: prompt failed or aborted (exit {code}); rerun to retry.",
        file=sys.stderr,
    )
    return code


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except KeyboardInterrupt:
        print("Aborted, nothing saved.", file=sys.stderr)
        sys.exit(1)
    except BrokenPipeError:
        sys.exit(1)
    except Exception as exc:  # noqa: BLE001
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
