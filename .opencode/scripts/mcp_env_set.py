#!/usr/bin/env python3
"""Set one env var from hidden console input. No network, no registry.

Usage:
    python3 mcp_env_set.py VAR [--check] [--url URL] [--info TEXT]

--check prints set/missing (exit 0/1). Otherwise opens URL (if given),
prints TEXT as the instruction block, then prompts masked (*** per
keystroke, 5-minute limit) and persists: setx user scope on Windows,
shell-rc append (idempotent) on POSIX. Prints where it saved and what
to do next. Server knowledge arrives via argv, never hardcoded here.
"""

import argparse
import getpass
import os
import re
import subprocess
import sys
import time
import webbrowser
from pathlib import Path

VAR_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
INPUT_TIMEOUT = 300


def hidden_input(prompt, timeout=INPUT_TIMEOUT):
    # One hidden line: '*' per keystroke, backspace works, empty line or
    # timeout aborts. termios/msvcrt imported here so each OS only loads
    # its own backend. Falls back to getpass when stdin is not a TTY.
    deadline = time.time() + timeout
    sys.stdout.write(prompt)
    sys.stdout.flush()
    if os.name == "nt":
        import msvcrt

        def getch():
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
        raw = termios.tcgetattr(fd)
        tty.setraw(fd)

        def getch():
            wait = deadline - time.time()
            if wait <= 0:
                raise TimeoutError
            ready, _, _ = select.select([fd], [], [], min(wait, 0.2))
            if not ready:
                return ""
            return os.read(fd, 1).decode("utf-8", "replace")

    buf = []
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


def set_title(text):
    if os.name == "nt":
        return
    sys.stdout.write("\033]0;%s\007" % text)
    sys.stdout.flush()


def shell_rc():
    shell = os.path.basename(os.environ.get("SHELL", ""))
    if "zsh" in shell:
        name = ".zshrc"
    elif "bash" in shell:
        name = ".bashrc"
    else:
        name = ".profile"
    return Path.home() / name


def persist(var, value):
    if os.name == "nt":
        done = subprocess.run(["setx", var, value], capture_output=True, text=True)
        if done.returncode != 0:
            print("setx failed: %s" % done.stderr.strip())
            return False
        print("Saved via setx (user scope) -- restart opencode to pick it up.")
        return True
    rc = shell_rc()
    created = not rc.exists()
    lines = rc.read_text().splitlines() if not created else []
    prefix = "export %s=" % var
    lines = [line for line in lines if not line.strip().startswith(prefix)]
    lines.append(prefix + value)
    rc.write_text("\n".join(lines) + "\n")
    if created:
        rc.chmod(0o600)
    print("Saved to %s -- then: source %s && restart opencode." % (rc, rc))
    return True


def main(argv):
    ap = argparse.ArgumentParser(
        description="Set one env var from masked console input."
    )
    ap.add_argument("var", help="VAR name ([A-Za-z_][A-Za-z0-9_]*)")
    ap.add_argument("--check", action="store_true", help="print set/missing only")
    ap.add_argument("--url", default="", help="token page to open first")
    ap.add_argument("--info", default="", help="instruction lines, use \\n to separate")
    ns = ap.parse_args(argv[1:])
    if not VAR_RE.match(ns.var):
        ap.error("bad VAR name")
    var = ns.var
    set_title("MCP auth: %s" % var)
    if ns.check:
        missing = not os.environ.get(var, "").strip()
        print("%s: %s" % (var, "missing" if missing else "set"))
        return 1 if missing else 0
    if ns.url:
        print("Opening token page...")
        webbrowser.open(ns.url)
    if ns.info:
        print(ns.info.replace("\\n", "\n"))
    print(
        "Input is hidden (***), %d minutes, then this closes itself."
        % (INPUT_TIMEOUT // 60)
    )
    try:
        try:
            value = hidden_input("%s: " % var).strip()
        except OSError:
            value = getpass.getpass("%s: " % var).strip()
    except TimeoutError:
        print("Timed out after %d minutes, nothing saved." % (INPUT_TIMEOUT // 60))
        return 1
    if not value:
        print("Empty input, nothing saved.")
        return 1
    return 0 if persist(var, value) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
