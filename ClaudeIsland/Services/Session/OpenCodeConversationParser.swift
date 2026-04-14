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
        let rows = queryMessages(sessionId: sessionId)
        return parseRows(rows)
    }

    func parseIncremental(sessionId: String, cwd: String) -> IncrementalParseResult {
        let rows = queryMessages(sessionId: sessionId)
        var cache = sessionCaches[sessionId] ?? SessionCache()

        if rows.count == cache.lastRowCount {
            return IncrementalParseResult(
                newMessages: [],
                allMessages: cache.messages,
                completedToolIds: cache.completedToolIds,
                toolResults: cache.toolResults
            )
        }

        // Parse all rows (SQLite doesn't support offset-based incremental easily
        // with our JSON blob format, so we re-parse but deduplicate via seenIds)
        var newMessages: [ChatMessage] = []
        let allParsed = parseRows(rows)

        for msg in allParsed {
            if cache.seenMessageIds.insert(msg.id).inserted {
                newMessages.append(msg)
                cache.messages.append(msg)
            }
        }

        // Parse tool results from parts
        let parts = queryParts(sessionId: sessionId)
        for part in parts {
            if let toolId = parseToolResult(from: part, cache: &cache) {
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

    /// Query messages from the SQLite DB using the sqlite3 CLI.
    /// Returns an array of JSON-decoded dictionaries.
    private func queryMessages(sessionId: String) -> [[String: Any]] {
        let dbPath = OpenCodePaths.databaseFile.path
        guard FileManager.default.fileExists(atPath: dbPath) else { return [] }

        let safeId = sessionId.replacingOccurrences(of: "'", with: "''")
        let query = """
        SELECT m.id, m.session_id, m.data
        FROM message m
        WHERE m.session_id = '\(safeId)'
        ORDER BY m.rowid;
        """

        return runSQLiteQuery(dbPath: dbPath, query: query)
    }

    /// Query parts from the SQLite DB.
    private func queryParts(sessionId: String) -> [[String: Any]] {
        let dbPath = OpenCodePaths.databaseFile.path
        guard FileManager.default.fileExists(atPath: dbPath) else { return [] }

        let safeId = sessionId.replacingOccurrences(of: "'", with: "''")
        let query = """
        SELECT p.id, p.message_id, p.session_id, p.data
        FROM part p
        WHERE p.session_id = '\(safeId)'
        ORDER BY p.rowid;
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

    private func parseRows(_ rows: [[String: Any]]) -> [ChatMessage] {
        var messages: [ChatMessage] = []
        var seenIds: Set<String> = []

        for row in rows {
            guard let id = row["id"] as? String,
                  seenIds.insert(id).inserted else { continue }

            // The `data` column is a JSON string
            guard let dataStr = row["data"] as? String,
                  let dataBytes = dataStr.data(using: .utf8),
                  let data = try? JSONSerialization.jsonObject(with: dataBytes) as? [String: Any] else {
                continue
            }

            guard let roleStr = data["role"] as? String else { continue }
            let role: ChatRole
            switch roleStr {
            case "user": role = .user
            case "assistant": role = .assistant
            default: continue
            }

            // Parse timestamp from data.time.created (Unix epoch seconds)
            var timestamp = Date()
            if let timeObj = data["time"] as? [String: Any],
               let created = timeObj["created"] as? Double {
                timestamp = Date(timeIntervalSince1970: created)
            }

            let msgId = "opencode-\(roleStr)-\(id)"

            // For user messages, there's no inline text — content comes from parts
            // For assistant messages, same — text is in parts
            // But we'll include a placeholder text from data if available
            var blocks: [MessageBlock] = []

            // Some message formats include summary.title
            if let summary = data["summary"] as? [String: Any],
               let title = summary["title"] as? String, !title.isEmpty {
                blocks.append(.text(title))
            }

            // We'll also attach parts inline if this is a small session
            // (large sessions use incremental parsing)
            if blocks.isEmpty {
                blocks.append(.text(""))
            }

            messages.append(ChatMessage(
                id: msgId,
                role: role,
                timestamp: timestamp,
                content: blocks
            ))
        }

        return messages
    }

    /// Attach part content to existing messages or create tool-use blocks.
    private func parseToolResult(from partRow: [String: Any], cache: inout SessionCache) -> String? {
        guard let dataStr = partRow["data"] as? String,
              let dataBytes = dataStr.data(using: .utf8),
              let data = try? JSONSerialization.jsonObject(with: dataBytes) as? [String: Any] else {
            return nil
        }

        let partType = data["type"] as? String

        // Tool invocation result
        if partType == "tool-result" || partType == "tool-invocation" {
            let toolCallId = data["toolCallId"] as? String ?? data["id"] as? String ?? ""
            guard !toolCallId.isEmpty else { return nil }

            if partType == "tool-result" {
                let resultText = data["result"] as? String
                    ?? (data["output"] as? String)
                let isError = data["isError"] as? Bool ?? false
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
