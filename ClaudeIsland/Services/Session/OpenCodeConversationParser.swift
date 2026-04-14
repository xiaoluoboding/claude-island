//
//  OpenCodeConversationParser.swift
//  ClaudeIsland
//
//  Parses OpenCode sessions from the SQLite database at
//  ~/.local/share/opencode/opencode.db
//
//  Uses the `sqlite3` CLI (always available on macOS) to avoid linking
//  the SQLite3 C library directly.
//

import Foundation

actor OpenCodeConversationParser {
    static let shared = OpenCodeConversationParser()

    struct IncrementalParseResult {
        let newMessages: [ChatMessage]
        let allMessages: [ChatMessage]
        let completedToolIds: Set<String>
        let toolResults: [String: ConversationParser.ToolResult]
    }

    private struct SessionCache {
        var messages: [ChatMessage] = []
        var seenMessageIds: Set<String> = []
        var lastRowCount: Int = 0
        var completedToolIds: Set<String> = []
        var toolResults: [String: ConversationParser.ToolResult] = [:]
    }

    private var sessionCaches: [String: SessionCache] = [:]

    // MARK: - Public API

    func parse(sessionId: String, cwd: String) -> ConversationInfo {
        let messages = parseFullConversation(sessionId: sessionId, cwd: cwd)
        let meaningfulUserMessages = messages.compactMap { message -> (ChatMessage, String)? in
            guard message.role == .user,
                  let prompt = meaningfulUserPrompt(from: message.textContent) else {
                return nil
            }
            return (message, prompt)
        }

        let firstUser = meaningfulUserMessages.first?.1
        let lastNonEmpty = messages.last(where: { !$0.textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        let lastUser = meaningfulUserMessages.last?.0

        return ConversationInfo(
            summary: truncate(firstUser, maxLength: 50) ?? "OpenCode Session",
            lastMessage: truncate(lastNonEmpty?.textContent, maxLength: 80),
            lastMessageRole: lastNonEmpty?.role.rawValue,
            lastToolName: nil,
            firstUserMessage: truncate(firstUser, maxLength: 50),
            lastUserMessageDate: lastUser?.timestamp
        )
    }

    func parseFullConversation(sessionId: String, cwd: String) -> [ChatMessage] {
        let rows = queryMessagesWithParts(sessionId: sessionId)
        return buildMessages(from: rows)
    }

    func parseIncremental(sessionId: String, cwd: String) -> IncrementalParseResult {
        let rows = queryMessagesWithParts(sessionId: sessionId)
        var cache = sessionCaches[sessionId] ?? SessionCache()

        if rows.count == cache.lastRowCount {
            return IncrementalParseResult(
                newMessages: [],
                allMessages: cache.messages,
                completedToolIds: cache.completedToolIds,
                toolResults: cache.toolResults
            )
        }

        let allParsed = buildMessages(from: rows)
        var newMessages: [ChatMessage] = []

        for msg in allParsed {
            if cache.seenMessageIds.insert(msg.id).inserted {
                newMessages.append(msg)
                cache.messages.append(msg)
            }
        }

        // Extract tool results from part data
        for row in rows {
            guard let partDataStr = row["part_data"] as? String,
                  let partBytes = partDataStr.data(using: .utf8),
                  let partData = try? JSONSerialization.jsonObject(with: partBytes) as? [String: Any] else {
                continue
            }
            if let toolId = extractToolResult(from: partData, cache: &cache) {
                cache.completedToolIds.insert(toolId)
            }
        }

        cache.lastRowCount = rows.count
        sessionCaches[sessionId] = cache

        return IncrementalParseResult(
            newMessages: newMessages,
            allMessages: cache.messages,
            completedToolIds: cache.completedToolIds,
            toolResults: cache.toolResults
        )
    }

    func completedToolIds(for sessionId: String) -> Set<String> {
        sessionCaches[sessionId]?.completedToolIds ?? []
    }

    func toolResults(for sessionId: String) -> [String: ConversationParser.ToolResult] {
        sessionCaches[sessionId]?.toolResults ?? [:]
    }

    func resetState(for sessionId: String) {
        sessionCaches.removeValue(forKey: sessionId)
    }

    // MARK: - SQLite Queries

    /// Query messages joined with their text parts from the SQLite DB.
    /// Returns rows with msg_id, msg_data (JSON), part_data (JSON).
    private func queryMessagesWithParts(sessionId: String) -> [[String: Any]] {
        let dbPath = OpenCodePaths.databaseFile.path
        guard FileManager.default.fileExists(atPath: dbPath) else { return [] }

        let safeId = sessionId.replacingOccurrences(of: "'", with: "''")
        // Join message + part tables to get role from message and text from parts
        let query = """
        SELECT m.id as msg_id, m.data as msg_data, p.id as part_id, p.data as part_data
        FROM part p
        JOIN message m ON p.message_id = m.id
        WHERE p.session_id = '\(safeId)'
        ORDER BY m.time_created, p.time_created;
        """

        return runSQLiteQuery(dbPath: dbPath, query: query)
    }

    /// Run a sqlite3 query and return parsed JSON rows.
    /// Uses `-json` output mode for reliable parsing.
    private func runSQLiteQuery(dbPath: String, query: String) -> [[String: Any]] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-json", "-readonly", dbPath, query]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else { return [] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return rows
    }

    // MARK: - Parsing

    /// Build ChatMessage array from joined message+part rows.
    /// Groups parts by message_id, extracts role from msg_data, text from part_data.
    private func buildMessages(from rows: [[String: Any]]) -> [ChatMessage] {
        // Group parts by message ID, preserving order
        var messageOrder: [String] = []
        var messageData: [String: [String: Any]] = [:]
        var messageParts: [String: [[String: Any]]] = [:]

        for row in rows {
            guard let msgId = row["msg_id"] as? String else { continue }

            if messageData[msgId] == nil {
                messageOrder.append(msgId)
                // Parse msg_data JSON
                if let msgDataStr = row["msg_data"] as? String,
                   let bytes = msgDataStr.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
                    messageData[msgId] = parsed
                }
            }

            // Parse part_data JSON
            if let partDataStr = row["part_data"] as? String,
               let bytes = partDataStr.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] {
                messageParts[msgId, default: []].append(parsed)
            }
        }

        var messages: [ChatMessage] = []

        for msgId in messageOrder {
            guard let msgData = messageData[msgId] else { continue }
            guard let roleStr = msgData["role"] as? String else { continue }

            let role: ChatRole
            switch roleStr {
            case "user": role = .user
            case "assistant": role = .assistant
            default: continue
            }

            // Timestamp from msg_data.time.created (milliseconds since epoch)
            var timestamp = Date()
            if let timeObj = msgData["time"] as? [String: Any],
               let created = timeObj["created"] as? Double {
                timestamp = Date(timeIntervalSince1970: created / 1000.0)
            }

            // Collect text blocks from parts
            var blocks: [MessageBlock] = []
            let parts = messageParts[msgId] ?? []

            for part in parts {
                guard let partType = part["type"] as? String else { continue }

                switch partType {
                case "text":
                    if let text = part["text"] as? String {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            blocks.append(.text(trimmed))
                        }
                    }

                case "tool-invocation":
                    let toolName = (part["toolName"] as? String) ?? (part["name"] as? String) ?? "unknown"
                    let callId = (part["toolCallId"] as? String) ?? (part["id"] as? String) ?? UUID().uuidString
                    var input: [String: String] = [:]
                    if let args = part["args"] as? [String: Any] {
                        for (k, v) in args {
                            input[k] = "\(v)"
                        }
                    }
                    blocks.append(.toolUse(ToolUseBlock(id: callId, name: toolName, input: input)))

                default:
                    break
                }
            }

            guard !blocks.isEmpty else { continue }

            let chatId = "opencode-\(roleStr)-\(msgId)"
            messages.append(ChatMessage(
                id: chatId,
                role: role,
                timestamp: timestamp,
                content: blocks
            ))
        }

        return messages
    }

    /// Extract tool result from a part data dictionary.
    private func extractToolResult(from partData: [String: Any], cache: inout SessionCache) -> String? {
        let partType = partData["type"] as? String

        if partType == "tool-invocation" {
            let state = partData["state"] as? String
            if state == "result" || state == "completed" {
                let toolCallId = (partData["toolCallId"] as? String) ?? (partData["id"] as? String) ?? ""
                guard !toolCallId.isEmpty else { return nil }

                let resultText: String?
                if let result = partData["result"] as? [[String: Any]] {
                    resultText = result.compactMap { $0["text"] as? String }.joined(separator: "\n")
                } else {
                    resultText = partData["output"] as? String
                }

                let isError = partData["isError"] as? Bool ?? false
                cache.toolResults[toolCallId] = ConversationParser.ToolResult(
                    content: resultText,
                    stdout: nil,
                    stderr: nil,
                    isError: isError
                )
                return toolCallId
            }
        }

        return nil
    }

    // MARK: - Helpers

    private func truncate(_ message: String?, maxLength: Int) -> String? {
        guard let message else { return nil }
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength - 3)) + "..."
        }
        return cleaned
    }

    private func meaningfulUserPrompt(from rawText: String) -> String? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let generatedPrefixes = [
            "<environment_context>",
            "<app-context>",
            "<collaboration_mode>",
            "<permissions instructions>",
            "<current_datetime>",
            "<reminder>",
        ]

        if generatedPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            return nil
        }

        return trimmed
    }
}
