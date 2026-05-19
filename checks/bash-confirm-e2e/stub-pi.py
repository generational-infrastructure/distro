#!/usr/bin/env python3
"""Minimal stand-in for the `pi` binary, just enough to drive opencrow's
confirm round-trip end-to-end.

Speaks the JSON-NDJSON RPC protocol that opencrow's `worker.go` expects:
  - reads JSON commands from stdin (`prompt`, `extension_ui_response`, ...)
  - emits JSON events on stdout (`agent_start`, `extension_ui_request`,
    `agent_end`, ...)

Stub behavior:
  - Ignores all CLI args (real pi has --mode rpc --session-dir ... etc.)
  - On each `prompt` command:
      1. Emit agent_start.
      2. Emit extension_ui_request{method=confirm, id=<unique>, title=..., message=<prompt text>}.
      3. Wait for the matching extension_ui_response on stdin.
      4. Append the response to ``OPENCROW_STUB_LOG`` (one JSON object
         per line) so the harness can assert against it.
      5. Emit agent_end with a short assistant message describing the
         outcome.

The harness sets ``OPENCROW_STUB_LOG`` to a file path it can read after
the round-trip completes.
"""

import json
import os
import sys
import time

LOG_PATH = os.environ.get("OPENCROW_STUB_LOG", "/tmp/stub-pi.log")


def emit(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def log(obj):
    with open(LOG_PATH, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(obj) + "\n")


def read_command():
    line = sys.stdin.readline()
    if not line:
        return None
    line = line.strip()
    if not line:
        return read_command()
    return json.loads(line)


def handle_prompt(message, counter):
    req_id = f"e2e-{counter}"
    emit({"type": "agent_start"})
    emit(
        {
            "type": "extension_ui_request",
            "id": req_id,
            "method": "confirm",
            "title": "Run shell command?",
            "message": message,
        }
    )

    # Drain stdin until the matching response arrives. Any other command
    # (e.g. abort) is logged and ignored.
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        cmd = read_command()
        if cmd is None:
            log({"event": "stdin_closed_before_response", "id": req_id})
            return
        if cmd.get("type") == "extension_ui_response" and cmd.get("id") == req_id:
            log({"event": "ui_response", "id": req_id, "cmd": cmd, "prompt": message})
            break
        log({"event": "unexpected_command_before_response", "cmd": cmd})
    else:
        log({"event": "timeout_waiting_for_response", "id": req_id})
        return

    emit(
        {
            "type": "agent_end",
            "success": True,
            "messages": [
                {
                    "role": "assistant",
                    "content": [
                        {"type": "text", "text": f"handled {req_id}"},
                    ],
                    "stopReason": "endTurn",
                }
            ],
        }
    )


def main():
    counter = 0
    while True:
        cmd = read_command()
        if cmd is None:
            return
        ctype = cmd.get("type")
        if ctype == "prompt":
            counter += 1
            handle_prompt(cmd.get("message", ""), counter)
        elif ctype == "abort":
            log({"event": "abort_received"})
        elif ctype == "get_available_models":
            emit(
                {
                    "type": "response",
                    "command": "get_available_models",
                    "data": {"models": []},
                }
            )
        elif ctype == "get_state":
            emit({"type": "response", "command": "get_state", "data": {"model": None}})
        elif ctype == "set_model":
            emit(
                {
                    "type": "response",
                    "command": "set_model",
                    "data": {
                        "provider": cmd.get("provider", ""),
                        "id": cmd.get("modelId", ""),
                    },
                }
            )
        else:
            log({"event": "ignored_command", "cmd": cmd})


if __name__ == "__main__":
    main()
