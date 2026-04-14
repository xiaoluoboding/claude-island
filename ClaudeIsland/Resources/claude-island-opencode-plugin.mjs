/**
 * Claude Island Bridge Plugin for OpenCode
 *
 * Forwards OpenCode session events to Claude Island's Unix domain socket
 * so the macOS menu bar app can show Dynamic Island-style notifications.
 *
 * Event mapping:
 *   session.status (busy)     → SessionStart / processing
 *   session.status (idle)     → Stop / waiting_for_input
 *   session.idle              → Stop / waiting_for_input
 *   session.created           → SessionStart / waiting_for_input
 *   message.updated           → UserPromptSubmit / processing
 *   message.part.updated      → PreToolUse / running_tool (for tool parts)
 *   permission.updated        → PermissionRequest / waiting_for_approval
 *   permission.ask            → PermissionRequest (bi-directional: can approve/deny from menu bar)
 *   session.error             → Stop / waiting_for_input
 *
 * @see https://github.com/sst/opencode
 */

import { createConnection } from "net";

const SOCKET_PATH = "/tmp/claude-island.sock";
const PERMISSION_TIMEOUT_MS = 300_000; // 5 minutes

function sendToSocket(data) {
  return new Promise((resolve) => {
    try {
      const client = createConnection(SOCKET_PATH, () => {
        client.write(JSON.stringify(data));
        client.end();
        resolve(null);
      });
      client.on("error", () => resolve(null));
      client.setTimeout(5000, () => {
        client.destroy();
        resolve(null);
      });
    } catch {
      resolve(null);
    }
  });
}

function sendAndWaitForResponse(data) {
  return new Promise((resolve) => {
    try {
      const client = createConnection(SOCKET_PATH, () => {
        client.write(JSON.stringify(data));
      });

      const chunks = [];
      client.on("data", (chunk) => chunks.push(chunk));
      client.on("end", () => {
        try {
          const text = Buffer.concat(chunks).toString();
          resolve(JSON.parse(text));
        } catch {
          resolve(null);
        }
      });
      client.on("error", () => resolve(null));
      client.setTimeout(PERMISSION_TIMEOUT_MS, () => {
        client.destroy();
        resolve(null);
      });
    } catch {
      resolve(null);
    }
  });
}

// Singleton guard
const GUARD_KEY = "__claudeIslandOpenCodePlugin__";

// Child session cache to filter out subagent events
const childSessionCache = new Map();

async function isChildSession(sessionID, client) {
  if (!sessionID || !client?.session?.list) return true;
  if (childSessionCache.has(sessionID)) return childSessionCache.get(sessionID);

  try {
    const sessions = await client.session.list();
    const session = sessions.data?.find((s) => s.id === sessionID);
    const isChild = !!session?.parentID;
    childSessionCache.set(sessionID, isChild);
    return isChild;
  } catch {
    return true; // Safe default: assume child to avoid false positives
  }
}

export const server = async ({ client, project, directory }) => {
  // If already loaded in this process, return no-op hooks
  if (globalThis[GUARD_KEY]) return {};
  globalThis[GUARD_KEY] = true;
  return {
    event: async ({ event }) => {
      const sessionID = event.properties?.sessionID;

      // Skip child/subagent sessions
      if (sessionID && (await isChildSession(sessionID, client))) return;

      let hookEvent = null;

      switch (event.type) {
        case "session.status": {
          const status = event.properties?.status;
          if (status?.type === "busy") {
            hookEvent = {
              source: "opencode",
              session_id: sessionID,
              cwd: directory,
              event: "SessionStart",
              status: "processing",
              pid: process.pid,
            };
          } else if (status?.type === "idle") {
            hookEvent = {
              source: "opencode",
              session_id: sessionID,
              cwd: directory,
              event: "Stop",
              status: "waiting_for_input",
              pid: process.pid,
            };
          }
          break;
        }

        case "session.idle":
          hookEvent = {
            source: "opencode",
            session_id: sessionID,
            cwd: directory,
            event: "Stop",
            status: "waiting_for_input",
            pid: process.pid,
          };
          break;

        case "session.created": {
          const info = event.properties?.info;
          hookEvent = {
            source: "opencode",
            session_id: info?.id || sessionID,
            cwd: info?.directory || directory,
            event: "SessionStart",
            status: "waiting_for_input",
            pid: process.pid,
          };
          // New session — clear child cache entry
          if (info?.id) childSessionCache.delete(info.id);
          break;
        }

        case "session.error":
          hookEvent = {
            source: "opencode",
            session_id: sessionID,
            cwd: directory,
            event: "Stop",
            status: "waiting_for_input",
            pid: process.pid,
          };
          break;

        case "message.updated": {
          const msg = event.properties?.info;
          if (msg?.role === "user") {
            hookEvent = {
              source: "opencode",
              session_id: msg?.sessionID || sessionID,
              cwd: directory,
              event: "UserPromptSubmit",
              status: "processing",
              pid: process.pid,
            };
          }
          break;
        }

        case "message.part.updated": {
          const part = event.properties?.info;
          const partData = part?.data;
          if (partData?.type === "tool-invocation" || partData?.type === "tool") {
            hookEvent = {
              source: "opencode",
              session_id: sessionID,
              cwd: directory,
              event: "PreToolUse",
              status: "running_tool",
              tool: partData.toolName || partData.name || partData.tool,
              pid: process.pid,
            };
          }
          break;
        }

        case "permission.updated": {
          const perm = event.properties;
          hookEvent = {
            source: "opencode",
            session_id: perm?.sessionID,
            cwd: directory,
            event: "PermissionRequest",
            status: "waiting_for_approval",
            tool: perm?.title || perm?.type,
            tool_use_id: perm?.id,
            pid: process.pid,
          };
          break;
        }

        case "session.deleted":
        case "session.compacted":
          // Session ended or compacted — send ended status
          if (sessionID) {
            hookEvent = {
              source: "opencode",
              session_id: sessionID,
              cwd: directory,
              event: "SessionEnd",
              status: "ended",
              pid: process.pid,
            };
          }
          break;
      }

      if (hookEvent) {
        await sendToSocket(hookEvent);
      }
    },

    "permission.ask": async (permission, output) => {
      if (output.status !== "ask") return;

      // Send permission request to Claude Island and wait for user decision
      const response = await sendAndWaitForResponse({
        source: "opencode",
        session_id: permission.sessionID,
        cwd: directory,
        event: "PermissionRequest",
        status: "waiting_for_approval",
        tool: permission.title || permission.type,
        tool_use_id: permission.id,
        pid: process.pid,
      });

      if (response?.decision === "allow") {
        output.status = "allow";
      } else if (response?.decision === "deny") {
        output.status = "deny";
      }
      // If no response or "ask", leave output.status as "ask" (user sees TUI prompt)
    },
  };
};
