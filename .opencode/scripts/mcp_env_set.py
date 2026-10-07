#!/usr/bin/env python3
"""Set one env var from hidden console input. No network, no registry.

Usage:
    python3 mcp_env_set.py VAR [--check] [--launch] [--url URL] [--info TEXT]

--check prints set/missing (exit 0/1) and never opens a window.
Without --check, prompts masked (*** per keystroke, 5-minute limit) and
persists to user scope: setx on Windows, shell-rc append (idempotent)
on POSIX. Prints where it saved and what to do next. Server knowledge
arrives via argv, never hardcoded here.

Windowing (exactly one, never probes):
- stdin is a TTY -> prompt inline, zero windows (--launch is a no-op).
- stdin has no TTY + --launch + display + terminal -> re-exec this
  script (without --launch) inside exactly one blocking terminal and
  wait. The child sets the window title and prompts. The parent prints
  one opening line, then one result line.
- stdin has no TTY without --launch, or no display / no terminal ->
  print the exact manual command and open nothing (exit 2).
TTY/display checks are env + PATH only and never pop UI.

Exit codes (judge by these + the result line, never by grepping
env/rc files): 0 saved (or set, with --check); 1 missing (--check),
prompt failed/aborted, or terminal launch failed; 2 this environment
needs a manual run (bad VAR, no TTY without --launch, no display or
no terminal with --launch: manual command printed, nothing opened).
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
import time
import webbrowser
from pathlib import Path

VAR_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
INPUT_TIMEOUT = 300


def hidden_input(prompt: str, timeout: int = INPUT_TIMEOUT) -> str:
    # One hidden line: '*' per keystroke, backspace works, empty line or
    # timeout aborts. termios/msvcrt imported here so each OS only loads
    # its own backend. Raises OSError with a clean message when stdin has
    # no TTY instead of a termios traceback; caller decides (no window).
    if not sys.stdin.isatty():
        raise OSError("stdin has no TTY (not a terminal)")
    deadline = time.time() + timeout
    sys.stdout.write(prompt)
    sys.stdout.flush()
    if os.name == "nt":
        import msvcrt

        def getch() -> str:
            while not msvcrt.kbhit():
                if time.time() > deadline:
                    raise TimeoutError
                time.sleep(0.05)
            return msvcrt.getwch()

        raw = None
    else:
        import select
        import termios
        import tty

        fd = sys.stdin.fileno()
        try:
            raw = termios.tcgetattr(fd)
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
        if raw is not None:
            import termios

            termios.tcsetattr(fd, termios.TCSADRAIN, raw)


def set_title(text: str) -> None:
    # Title escape only on a real terminal; never pollute piped logs.
    if os.name == "nt" or not sys.stdout.isatty():
        return
    sys.stdout.write(f"\033]0;{text}\007")
    sys.stdout.flush()


def shell_rc() -> Path:
    shell = os.path.basename(os.environ.get("SHELL", ""))
    if "zsh" in shell:
        name = ".zshrc"
    elif "bash" in shell:
        name = ".bashrc"
    else:
        name = ".profile"
    return Path.home() / name


def persist(var: str, value: str) -> bool:
    if os.name == "nt":
        done = subprocess.run(
            ["setx", var, value], capture_output=True, text=True, check=False
        )
        if done.returncode != 0:
            print(f"setx failed: {done.stderr.strip()}", file=sys.stderr)
            return False
        print("Saved via setx (user scope) -- restart opencode to pick it up.")
        return True
    rc = shell_rc()
    created = not rc.exists()
    lines = rc.read_text().splitlines() if not created else []
    prefix = f"export {var}="
    lines = [line for line in lines if not line.strip().startswith(prefix)]
    lines.append(prefix + shlex.quote(value))
    rc.write_text("\n".join(lines) + "\n")
    if created:
        rc.chmod(0o600)
    print(f"Saved to {rc} -- then: source {rc} && restart opencode.")
    return True


def has_display() -> bool:
    # Env-only check, never pops UI.
    if os.name == "nt":
        return True
    return bool(
        os.environ.get("DISPLAY", "").strip()
        or os.environ.get("WAYLAND_DISPLAY", "").strip()
    )


def find_terminal() -> str | None:
    # PATH-only check, never launches anything (no probe windows).
    for name in ("konsole", "gnome-terminal", "xterm"):
        if shutil.which(name):
            return name
    return None


def manual_command(var: str, url: str, info: str) -> str:
    parts = ["python3 .opencode/scripts/mcp_env_set.py", var]
    if url:
        parts.append(f"--url {shlex.quote(url)}")
    if info:
        parts.append(f"--info {shlex.quote(info)}")
    return " ".join(parts)


def launch_in_terminal(child_argv: list[str], title: str, term: str) -> int:
    # Open exactly one blocking terminal running child_argv. Returns the
    # child exit code. Spawn failures report cleanly and open nothing.
    if term == "konsole":
        term_argv = ["konsole", "--separate", "--nofork", "-e", *child_argv]
    elif term == "gnome-terminal":
        term_argv = ["gnome-terminal", "--wait", "--", *child_argv]
    else:
        term_argv = ["xterm", "-T", title, "-e", *child_argv]
    try:
        done = subprocess.run(term_argv, check=False)
    except (FileNotFoundError, OSError) as exc:
        print(f"Terminal launch failed ({term}): {exc}", file=sys.stderr)
        return 1
    return done.returncode


def report_launch_result(var: str, code: int) -> int:
    # Parent-side verdict for a --launch run. The token itself never
    # appears here, only the outcome. Returns code unchanged: judge by
    # exit code + this line, never by grepping env/rc files.
    if code == 0:
        print(f"{var}: saved.")
    else:
        print(
            f"{var}: prompt failed or aborted (exit {code}); rerun to retry.",
            file=sys.stderr,
        )
    return code


def prompt_inline(var: str, url: str, info: str) -> int:
    set_title(f"MCP auth: {var}")
    if url:
        print("Opening token page...")
        try:
            opened = webbrowser.open(url)
        except (
            OSError,
            webbrowser.Error,
        ) as exc:  # browser missing/broken: warn, still prompt
            print(
                f"Could not open browser ({exc}); open {url} manually.", file=sys.stderr
            )
        else:
            if not opened:
                print(f"Open {url} manually.", file=sys.stderr)
    if info:
        print(info.replace("\\n", "\n"))
    print(
        f"Input is hidden (***), {INPUT_TIMEOUT // 60} minutes, then this closes itself."
    )
    try:
        try:
            value = hidden_input(f"{var}: ").strip()
        except OSError:
            value = getpass.getpass(f"{var}: ").strip()
    except TimeoutError:
        print(f"Timed out after {INPUT_TIMEOUT // 60} minutes, nothing saved.")
        return 1
    except (KeyboardInterrupt, EOFError):
        print("Aborted, nothing saved.")
        return 1
    if not value:
        print("Empty input, nothing saved.")
        return 1
    return 0 if persist(var, value) else 1


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Set one env var from masked console input."
    )
    ap.add_argument("var", help="VAR name ([A-Za-z_][A-Za-z0-9_]*)")
    ap.add_argument(
        "--check",
        action="store_true",
        help="print set/missing only, never opens a window",
    )
    ap.add_argument(
        "--launch",
        action="store_true",
        help="no TTY + display: open exactly one terminal and wait; else print the manual command",
    )
    ap.add_argument("--url", default="", help="token page to open first")
    ap.add_argument("--info", default="", help="instruction lines, use \\n to separate")
    ns = ap.parse_args(argv[1:])
    if not VAR_RE.match(ns.var):
        ap.error("bad VAR name")
    var: str = ns.var
    if ns.check:
        # --check never launches; --launch is ignored with it.
        missing = not os.environ.get(var, "").strip()
        print(f"{var}: {'missing' if missing else 'set'}")
        return 1 if missing else 0
    if sys.stdin.isatty():
        return prompt_inline(var, ns.url, ns.info)
    if not ns.launch:
        print(
            "stdin has no TTY; run in a terminal (opens nothing here):", file=sys.stderr
        )
        print(f"  {manual_command(var, ns.url, ns.info)}", file=sys.stderr)
        print(
            "Or rerun with --launch to open exactly one prompt window.", file=sys.stderr
        )
        return 2
    term = find_terminal()
    if not has_display():
        print(
            "No display here (neither $DISPLAY nor $WAYLAND_DISPLAY); "
            "run this in a terminal (opens nothing here):",
            file=sys.stderr,
        )
        print(f"  {manual_command(var, ns.url, ns.info)}", file=sys.stderr)
        return 2
    if term is None:
        print(
            "No terminal found (konsole, gnome-terminal, xterm); "
            "run this in a terminal (opens nothing here):",
            file=sys.stderr,
        )
        print(f"  {manual_command(var, ns.url, ns.info)}", file=sys.stderr)
        return 2
    print(f"Opening one prompt window for {var} ({term}); waiting...")
    script = str(Path(__file__).resolve())
    child = [sys.executable, script, var]
    if ns.url:
        child += ["--url", ns.url]
    if ns.info:
        child += ["--info", ns.info]
    return report_launch_result(
        var, launch_in_terminal(child, f"MCP auth: {var}", term)
    )


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except KeyboardInterrupt:
        print("Aborted, nothing saved.", file=sys.stderr)
        sys.exit(1)
    except BrokenPipeError:
        sys.exit(1)
    # Last-resort crash guard: clean `error: …` + exit 1, no traceback.
    except Exception as exc:  # noqa: BLE001
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
