#!/usr/bin/env python3
"""
CLI Island Hook
- Sends OpenCode session state to ClaudeIsland.app via Unix socket
"""
import json
import os
import select
import socket
import sys

SOCKET_PATH = "/tmp/claude-island.sock"
TIMEOUT_SECONDS = 5


def parse_args(argv):
    source = "opencode"
    forced_event = ""
    for i, token in enumerate(argv):
        if token == "--source" and i + 1 < len(argv):
            source = argv[i + 1].strip().lower() or "opencode"
        if token == "--event" and i + 1 < len(argv):
            forced_event = argv[i + 1].strip()
    return source, forced_event


def read_json_stdin_nonblocking():
    try:
        ready, _, _ = select.select([sys.stdin], [], [], 0.05)
        if not ready:
            return {}
        raw = sys.stdin.read()
        if not raw:
            return {}
        return json.loads(raw)
    except Exception:
        return {}


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
    source, forced_event = parse_args(sys.argv[1:])
    data = read_json_stdin_nonblocking()

    payload = data.get("input") if isinstance(data.get("input"), dict) else data
    data_obj = payload.get("data") if isinstance(payload.get("data"), dict) else {}

    session_id = (
        data.get("session_id")
        or payload.get("session_id")
        or data_obj.get("session_id")
        or (data_obj.get("session") or {}).get("id")
        or data.get("sessionId")
        or payload.get("sessionId")
        or data_obj.get("sessionId")
        or data.get("id")
        or payload.get("id")
        or data.get("conversation_id")
        or "unknown"
    )
    event = (
        data.get("hook_event_name")
        or payload.get("hook_event_name")
        or data_obj.get("hook_event_name")
        or data.get("event")
        or payload.get("event")
        or data_obj.get("event")
        or data.get("hook")
        or payload.get("hook")
        or data_obj.get("hook")
        or data.get("hookType")
        or payload.get("hookType")
        or data_obj.get("hookType")
        or ""
    )
    if not event and isinstance(payload.get("type"), str):
        event = {
            "session.start": "SessionStart",
            "session.shutdown": "SessionEnd",
            "session.end": "SessionEnd",
            "user.message": "UserPromptSubmit",
            "tool.execution_start": "PreToolUse",
            "tool.execution_complete": "PostToolUse",
            "tool.execution_error": "PostToolUseFailure",
            "assistant.turn_end": "Stop",
            "assistant.message": "Stop",
        }.get(payload.get("type"), "")
    if not event and forced_event:
        event = forced_event

    context = data_obj.get("context") if isinstance(data_obj.get("context"), dict) else {}
    cwd = (
        data.get("cwd")
        or payload.get("cwd")
        or data_obj.get("cwd")
        or context.get("cwd")
        or (data_obj.get("workspace") or {}).get("cwd")
        or data.get("working_directory")
        or payload.get("working_directory")
        or data_obj.get("working_directory")
        or data.get("workdir")
        or payload.get("workdir")
        or data_obj.get("workdir")
        or os.environ.get("PWD")
        or os.getcwd()
    )

    tool_name = (
        data.get("tool_name")
        or payload.get("tool_name")
        or data_obj.get("tool_name")
        or data.get("toolName")
        or payload.get("toolName")
        or data_obj.get("toolName")
        or data_obj.get("tool")
    )

    tool_input = (
        data.get("tool_input")
        or payload.get("tool_input")
        or data_obj.get("tool_input")
        or data.get("toolArgs")
        or payload.get("toolArgs")
        or data_obj.get("toolArgs")
        or data_obj.get("arguments")
    )

    tool_use_id = (
        data.get("tool_use_id")
        or payload.get("tool_use_id")
        or data_obj.get("tool_use_id")
        or data.get("toolUseId")
        or payload.get("toolUseId")
        or data_obj.get("toolUseId")
        or data_obj.get("toolCallId")
    )

    tool_calls = data.get("toolCalls") or payload.get("toolCalls")
    if isinstance(tool_calls, list) and tool_calls:
        first = tool_calls[0] if isinstance(tool_calls[0], dict) else {}
        tool_name = tool_name or first.get("name")
        tool_use_id = tool_use_id or first.get("id")
        if tool_input is None and isinstance(first.get("args"), str):
            try:
                tool_input = json.loads(first.get("args"))
            except Exception:
                tool_input = {"args": first.get("args")}

    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input)
        except Exception:
            pass

    state = {
        "source": source,
        "session_id": session_id,
        "cwd": cwd,
        "event": event,
        "pid": os.getppid(),
        "tty": get_tty(),
    }

    if event in ("UserPromptSubmit", "userPromptSubmitted"):
        state["status"] = "processing"
    elif event in ("SessionStart", "sessionStart"):
        state["status"] = "waiting_for_input"
    elif event in ("PreToolUse", "preToolUse"):
        state["status"] = "running_tool"
    elif event in ("PostToolUse", "postToolUse", "PostToolUseFailure", "postToolUseFailure"):
        state["status"] = "processing"
    elif event in ("SessionEnd", "sessionEnd"):
        state["status"] = "ended"
    elif event in ("Stop", "agentStop"):
        state["status"] = "waiting_for_input"
    else:
        state["status"] = "idle"

    if tool_name:
        state["tool"] = tool_name
    if isinstance(tool_input, dict):
        state["tool_input"] = tool_input
    if tool_use_id:
        state["tool_use_id"] = tool_use_id

    send_event(state)


if __name__ == "__main__":
    main()
