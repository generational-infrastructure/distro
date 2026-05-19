#!/usr/bin/env python3
"""Drives an out-of-process opencrow + stub-pi pair via the socket
backend and asserts the confirm round-trip behaves as expected.

Two scenarios in one VM-free harness:
  1. user allows  → stub logs ``confirmed: true``
  2. user denies  → stub logs ``confirmed: false``

The third interesting case (context cancelled / no response) is already
covered by Go-side unit tests in ../../socket/confirm_test.go.

Invoked by ``default.nix`` with three positional args:
  argv[1]: path to the opencrow binary
  argv[2]: path to the stub pi binary (script)
  argv[3]: scratch dir (writable, must exist)
"""

import json
import os
import socket
import subprocess
import sys
import time


def fail(msg):
    sys.stderr.write(f"FAIL: {msg}\n")
    sys.exit(1)


def wait_for_socket(path, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if os.path.exists(path):
            return
        time.sleep(0.1)
    fail(f"socket {path} did not appear within {timeout}s")


def read_event(sock_file, want_kind, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        line = sock_file.readline()
        if not line:
            fail(f"chat socket closed while waiting for {want_kind}")
        ev = json.loads(line)
        if ev.get("kind") == want_kind:
            return ev
    fail(f"timed out waiting for {want_kind}")


def send(sock, obj):
    sock.sendall((json.dumps(obj) + "\n").encode())


def run_scenario(sock, sock_file, prompt, confirmed):
    send(sock, {"cmd": "send", "text": prompt})
    ev = read_event(sock_file, "confirm")
    assert ev.get("confirmBody") == prompt, ev
    assert ev.get("confirmTitle") == "Run shell command?", ev
    assert ev.get("confirmId"), ev
    send(
        sock,
        {"cmd": "confirm-response", "id": ev["confirmId"], "confirmed": confirmed},
    )
    # Wait for the agent's "handled" reply so we know pi has emitted
    # agent_end (the stub log is flushed before that).
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        line = sock_file.readline()
        if not line:
            fail("socket closed before agent reply")
        ev2 = json.loads(line)
        if ev2.get("kind") == "msg" and ev2.get("msg", {}).get("dir") == "in":
            text = ev2["msg"].get("content", "")
            if text.startswith("handled "):
                return
    fail("did not receive agent reply")


def assert_log(log_path, expected_results):
    with open(log_path, "r", encoding="utf-8") as fh:
        entries = [json.loads(line) for line in fh if line.strip()]
    responses = [e for e in entries if e.get("event") == "ui_response"]
    if len(responses) != len(expected_results):
        fail(
            f"expected {len(expected_results)} ui_response entries, got {len(responses)}: {entries}"
        )
    for i, (entry, want) in enumerate(zip(responses, expected_results)):
        got = entry["cmd"].get("confirmed", None)
        if got is not want:
            fail(f"scenario {i}: confirmed={got!r}, want {want!r} (entry: {entry})")


def main():
    opencrow_bin, pi_bin, scratch = sys.argv[1:4]
    sock_path = os.path.join(scratch, "chat.sock")
    session_dir = os.path.join(scratch, "sessions")
    log_path = os.path.join(scratch, "stub-pi.log")
    os.makedirs(session_dir, exist_ok=True)
    # Truncate any prior log so assertions count only this run.
    open(log_path, "w").close()

    env = dict(os.environ)
    env.update(
        {
            "OPENCROW_BACKEND": "socket",
            "OPENCROW_SOCKET_PATH": sock_path,
            "OPENCROW_SOCKET_NAME": "TestBot",
            "OPENCROW_PI_BINARY": pi_bin,
            "OPENCROW_PI_SESSION_DIR": session_dir,
            "OPENCROW_PI_WORKING_DIR": scratch,
            "OPENCROW_PI_PROVIDER": "anthropic",
            "OPENCROW_PI_MODEL": "stub-model",
            "OPENCROW_PI_IDLE_TIMEOUT": "10m",
            "OPENCROW_STUB_LOG": log_path,
            "HOME": scratch,
        },
    )

    proc = subprocess.Popen(
        [opencrow_bin],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        cwd=scratch,
    )
    try:
        wait_for_socket(sock_path)
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(sock_path)
        sock_file = sock.makefile("r", buffering=1, encoding="utf-8")
        # Use a single long timeout for all reads; readline() picks it
        # up via the underlying socket. Toggling settimeout back to None
        # after a timeout can wedge the file object in a "timed out"
        # state on some Python versions, so we pick one and stick with it.
        sock.settimeout(30)
        send(sock, {"cmd": "replay", "n": 10})
        # Wait for replay response so the connection is registered in
        # opencrow's conns set before we trigger any broadcasts.
        first = sock_file.readline()
        if not first:
            fail("chat socket closed during initial replay")
        run_scenario(sock, sock_file, "echo allow-me", confirmed=True)
        run_scenario(sock, sock_file, "echo deny-me", confirmed=False)

        assert_log(log_path, [True, False])
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        if proc.stdout:
            sys.stderr.write("--- opencrow output ---\n")
            sys.stderr.write(proc.stdout.read().decode("utf-8", errors="replace"))
            sys.stderr.write("--- end opencrow output ---\n")

    print("OK")


if __name__ == "__main__":
    main()
