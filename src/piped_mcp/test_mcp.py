#!/usr/bin/env python3

import json
import queue
import subprocess
import sys
import threading
from pathlib import Path


def find_mcp_server_path():
    for build_dir in (
        Path("build"),
        Path("build/bin"),
        Path("build/Release"),
        Path("build/Debug"),
        Path("out/build"),
        Path("out/build/bin"),
    ):
        for extension in ("", ".exe"):
            executable = build_dir / f"piped_mcp{extension}"
            if executable.exists():
                return executable.resolve()
    return None


def read_line(stream, timeout=5):
    lines = queue.Queue(maxsize=1)

    def read():
        lines.put(stream.readline())

    threading.Thread(target=read, daemon=True).start()
    try:
        line = lines.get(timeout=timeout)
    except queue.Empty as error:
        raise TimeoutError("MCP response timed out") from error
    if not line:
        raise EOFError("MCP server closed stdout")
    return line


def send_request(process, method, request_id):
    request = {"jsonrpc": "2.0", "method": method, "params": {}, "id": request_id}
    process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
    process.stdin.flush()
    return json.loads(read_line(process.stdout))


def test_mcp_server():
    executable = find_mcp_server_path()
    if executable is None:
        print("Error: could not find piped_mcp executable", file=sys.stderr)
        return False

    process = subprocess.Popen(
        [str(executable)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )

    try:
        hello = send_request(process, "hello", 1)
        hello_ok = (
            hello.get("jsonrpc") == "2.0"
            and hello.get("id") == 1
            and "Hello from C++" in hello.get("result", "")
        )

        sdl_info = send_request(process, "sdl_info", 2)
        sdl_result = sdl_info.get("result", {})
        sdl_ok = (
            sdl_info.get("jsonrpc") == "2.0"
            and sdl_info.get("id") == 2
            and "compiled" in sdl_result
            and "linked" in sdl_result
        )

        if not hello_ok:
            print(f"hello validation failed: {hello}", file=sys.stderr)
        if not sdl_ok:
            print(f"sdl_info validation failed: {sdl_info}", file=sys.stderr)
        return hello_ok and sdl_ok
    except (EOFError, TimeoutError, json.JSONDecodeError, BrokenPipeError) as error:
        print(f"MCP test failed: {error}", file=sys.stderr)
        return False
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


if __name__ == "__main__":
    sys.exit(0 if test_mcp_server() else 1)
