#!/usr/bin/env python3
"""
Codex Island Hook
- Sends Codex session state to ClaudeIsland.app via Unix socket
"""
import json
import os
import socket
import sys

SOCKET_PATH = "/tmp/claude-island.sock"
TIMEOUT_SECONDS = 5


def get_tty():
    try:
        return os.ttyname(sys.stdin.fileno())
    except Exception:
        pass
    try:
        return os.ttyname(sys.stdout.fileno())
    except Exception:
        pass
    return None


def send_event(state):
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(TIMEOUT_SECONDS)
        sock.connect(SOCKET_PATH)
        sock.sendall(json.dumps(state).encode())
        sock.close()
    except Exception:
        return


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    session_id = (
        data.get("session_id")
        or data.get("sessionId")
        or data.get("id")
        or data.get("conversation_id")
        or "unknown"
    )
    event = data.get("hook_event_name") or data.get("event") or data.get("hook") or ""
    cwd = data.get("cwd") or data.get("working_directory") or data.get("workdir") or os.getcwd()

    state = {
        "source": "codex",
        "session_id": session_id,
        "cwd": cwd,
        "event": event,
        "pid": os.getppid(),
        "tty": get_tty(),
    }

    if event == "UserPromptSubmit":
        state["status"] = "processing"
    elif event == "SessionStart":
        state["status"] = "waiting_for_input"
    elif event == "Stop":
        state["status"] = "waiting_for_input"
    else:
        state["status"] = "idle"

    send_event(state)


if __name__ == "__main__":
    main()
