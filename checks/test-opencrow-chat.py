#!/usr/bin/env python3
"""
Drive a two-turn conversation through opencrow's chat socket and verify
the full noctalia plugin → opencrow (socket) → pi → reply round trip.

Turn 1: greet, expect any non-empty reply.
Turn 2: ask "What color is the sky?", expect a reply containing "blue".

Usage: test-opencrow-chat.py <socket_path>
"""

import json
import socket
import sys
import time

sock_path = sys.argv[1]

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
for _ in range(50):
    try:
        s.connect(sock_path)
        break
    except OSError:
        time.sleep(0.2)
else:
    sys.exit("could not connect to chat socket")

# Drain status/history events with a fresh replay.
s.sendall(json.dumps({"cmd": "replay", "n": 50}).encode() + b"\n")
s.settimeout(120)


def send_and_wait(text, predicate, timeout=120):
    """Send `text`, then wait for the next inbound reply matching `predicate`.

    opencrow batches concurrent messages, so each turn must complete before
    the next is sent.
    """
    s.sendall(json.dumps({"cmd": "send", "text": text}).encode() + b"\n")
    buf = bytearray()
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            chunk = s.recv(4096)
        except socket.timeout:
            break
        if not chunk:
            break
        buf.extend(chunk)
        while b"\n" in buf:
            nl = buf.index(b"\n")
            line = bytes(buf[:nl])
            del buf[: nl + 1]
            ev = json.loads(line)
            print(f"EVENT: {ev}", file=sys.stderr)
            msg = ev.get("msg") or {}
            if ev.get("kind") != "msg" or msg.get("dir") != "in":
                continue
            content = msg.get("content", "")
            print(f"BOT REPLY: {content}", file=sys.stderr)
            if predicate(content):
                return content
            sys.exit(f"reply failed predicate: {content!r}")
    sys.exit(f"timed out waiting for reply to {text!r}")


reply1 = send_and_wait("Hello bot", lambda c: bool(c.strip()))
print(f"TURN 1 OK: {reply1}")

reply2 = send_and_wait(
    "What color is the sky? Answer in one word.",
    lambda c: "blue" in c.lower(),
)
print(f"TURN 2 OK: {reply2}")

s.close()
print("SUCCESS")
