#!/usr/bin/env python3
"""
Test script for Piped MCP C++ implementation
Uses the mcp Python library to communicate with the C++ MCP server over stdio
"""

import subprocess
import sys
import time
import json
from pathlib import Path


def find_mcp_server_path():
    """Find the piped_mcp executable in the build directory."""
    # Try common build directories
    build_dirs = [
        Path("build"),
        Path("build/bin"),
        Path("build/Release"),
        Path("build/Debug"),
        Path("out/build"),
        Path("out/build/bin"),
    ]
    
    for build_dir in build_dirs:
        if build_dir.exists():
            # Check for executable
            for ext in ["", ".exe"]:
                exe_path = build_dir / f"piped_mcp{ext}"
                if exe_path.exists():
                    return str(exe_path.resolve())
    
    # Try system path
    for ext in ["", ".exe"]:
        exe_path = Path(f"piped_mcp{ext}")
        if exe_path.exists():
            return str(exe_path.resolve())
    
    return None


def test_mcp_server():
    """Test the MCP server by running it and sending commands."""
    exe_path = find_mcp_server_path()
    
    if not exe_path:
        print("Error: Could not find piped_mcp executable")
        print("Please build the project first:")
        print("  cmake -B build -DCMAKE_BUILD_TYPE=Release")
        print("  cmake --build build")
        return False
    
    print(f"Found executable: {exe_path}")
    
    # Start the MCP server process
    print("Starting MCP server...")
    proc = subprocess.Popen(
        [exe_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        universal_newlines=True
    )
    
    try:
        # Give it a moment to start
        time.sleep(1)
        
        # Test 1: Send hello command
        print("\nTest 1: Sending 'hello' command...")
        request = json.dumps({
            "method": "hello",
            "params": {},
            "id": 1
        })
        
        # Send Content-Length header
        content_length = len(request)
        proc.stdin.write(f"Content-Length: {content_length}\r\n")
        proc.stdin.write("Content-Type: application/json\r\n")
        proc.stdin.write("\r\n")
        proc.stdin.write(request)
        proc.stdin.flush()
        
        # Read response
        response = proc.stdout.readline()
        if "Content-Length:" in response:
            content_length = int(response.split(":")[1].strip())
            # Read headers
            while True:
                line = proc.stdout.readline()
                if line.strip() == "":
                    break
            # Read content
            content = proc.stdout.read(content_length)
            print(f"Response: {content}")
            
            # Parse and verify
            try:
                result = json.loads(content)
                if "result" in result and "Hello from C++" in result["result"]:
                    print("✓ Test 1 passed!")
                else:
                    print("✗ Test 1 failed: Unexpected response")
            except json.JSONDecodeError:
                print("✗ Test 1 failed: Invalid JSON response")
        else:
            print(f"✗ Test 1 failed: No response (got: {response})")
        
        # Test 2: Send sdl_info command
        print("\nTest 2: Sending 'sdl_info' command...")
        request = json.dumps({
            "method": "sdl_info",
            "params": {},
            "id": 2
        })
        
        content_length = len(request)
        proc.stdin.write(f"Content-Length: {content_length}\r\n")
        proc.stdin.write("Content-Type: application/json\r\n")
        proc.stdin.write("\r\n")
        proc.stdin.write(request)
        proc.stdin.flush()
        
        # Read response
        response = proc.stdout.readline()
        if "Content-Length:" in response:
            content_length = int(response.split(":")[1].strip())
            # Read headers
            while True:
                line = proc.stdout.readline()
                if line.strip() == "":
                    break
            # Read content
            content = proc.stdout.read(content_length)
            print(f"Response: {content}")
            
            # Parse and verify
            try:
                result = json.loads(content)
                if "compiled" in result and "linked" in result:
                    print("✓ Test 2 passed!")
                else:
                    print("✗ Test 2 failed: Unexpected response")
            except json.JSONDecodeError:
                print("✗ Test 2 failed: Invalid JSON response")
        else:
            print(f"✗ Test 2 failed: No response (got: {response})")
        
        print("\nAll tests completed!")
        return True
        
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        return False
    finally:
        # Clean up
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


if __name__ == "__main__":
    success = test_mcp_server()
    sys.exit(0 if success else 1)
