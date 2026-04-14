//
//  OpenCodeConversationParser.swift
//  ClaudeIsland
//
//  Parses OpenCode session JSONL files into the app's shared chat/session model.
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

    private struct IncrementalParseState {
        var lastFileOffset: UInt64 = 0
        var messages: [ChatMessage] = []
        var seenMessageIds: Set<String> = []
        var seenToolIds: Set<String> = []
        var completedToolIds: Set<String> = []
        var toolResults: [String: ConversationParser.ToolResult] = [:]
    }

    private var incrementalState: [String: IncrementalParseState] = [:]

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
        guard let filePath = sessionFilePath(sessionId: sessionId),
              let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }
        return parseContent(content)
    }

    func parseIncremental(sessionId: String, cwd: String) -> IncrementalParseResult {
        guard let filePath = sessionFilePath(sessionId: sessionId),
              let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            return IncrementalParseResult(
                newMessages: [],
                allMessages: [],
                completedToolIds: [],
                toolResults: [:]
            )
        }
        defer { try? fileHandle.close() }

        var state = incrementalState[sessionId] ?? IncrementalParseState()

        let fileSize: UInt64
        do {
            fileSize = try fileHandle.seekToEnd()
        } catch {
            return IncrementalParseResult(
                newMessages: [],
                allMessages: state.messages,
                completedToolIds: state.completedToolIds,
                toolResults: state.toolResults
            )
        }

        if fileSize < state.lastFileOffset {
            state = IncrementalParseState()
        }

        if fileSize == state.lastFileOffset {
            incrementalState[sessionId] = state
            return IncrementalParseResult(
                newMessages: [],
                allMessages: state.messages,
                completedToolIds: state.completedToolIds,
                toolResults: state.toolResults
            )
        }

        do {
            try fileHandle.seek(toOffset: state.lastFileOffset)
        } catch {
            incrementalState[sessionId] = state
            return IncrementalParseResult(
                newMessages: [],
                allMessages: state.messages,
                completedToolIds: state.completedToolIds,
                toolResults: state.toolResults
            )
        }

        guard let newData = try? fileHandle.readToEnd(),
              let newContent = String(data: newData, encoding: .utf8) else {
            incrementalState[sessionId] = state
            return IncrementalParseResult(
                newMessages: [],
                allMessages: state.messages,
                completedToolIds: state.completedToolIds,
                toolResults: state.toolResults
            )
        }

        var newMessages: [ChatMessage] = []
        for line in newContent.components(separatedBy: "\n") where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            if let toolId = parseToolOutput(json, state: &state) {
                state.completedToolIds.insert(toolId)
                continue
            }

            if let message = parseMessageLine(json, state: &state) {
                newMessages.append(message)
                state.messages.append(message)
            }
        }

        state.lastFileOffset = fileSize
        incrementalState[sessionId] = state

        return IncrementalParseResult(
            newMessages: newMessages,
            allMessages: state.messages,
            completedToolIds: state.completedToolIds,
            toolResults: state.toolResults
        )
    }

    func completedToolIds(for sessionId: String) -> Set<String> {
        incrementalState[sessionId]?.completedToolIds ?? []
    }

    func toolResults(for sessionId: String) -> [String: ConversationParser.ToolResult] {
        incrementalState[sessionId]?.toolResults ?? [:]
    }

    func resetState(for sessionId: String) {
        incrementalState.removeValue(forKey: sessionId)
    }

    // MARK: - Private

    private func parseContent(_ content: String) -> [ChatMessage] {
        var state = IncrementalParseState()
        var messages: [ChatMessage] = []

        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            _ = parseToolOutput(json, state: &state)
            if let message = parseMessageLine(json, state: &state) {
                messages.append(message)
            }
        }

        return messages
    }

    /// Parse a single JSONL line into a ChatMessage.
    ///
    /// OpenCode session events follow a flexible schema. We handle multiple
    /// common patterns so the parser works even as the upstream format evolves:
    ///
    /// Pattern 1 — Copilot/Codex-style `type` + `data`:
    ///   {"type": "user.message", "data": {"content": "..."}, "timestamp": "..."}
    ///
    /// Pattern 2 — OpenAI response_item style:
    ///   {"type": "response_item", "payload": {"type": "message", "role": "user", "content": [...]}}
    ///
    /// Pattern 3 — Simple role-based:
    ///   {"role": "user", "content": "...", "timestamp": "..."}
    private func parseMessageLine(_ json: [String: Any], state: inout IncrementalParseState) -> ChatMessage? {
        guard let type = json["type"] as? String else {
            return parseSimpleMessage(json, state: &state)
        }

        let timestamp = parseTimestamp(json["timestamp"] as? String) ?? Date()

        switch type {
        // Pattern 1: event-style messages (user.message / assistant.message)
        case "user.message":
            guard let data = json["data"] as? [String: Any],
                  let text = data["content"] as? String else { return nil }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let id = "opencode-user-\(StableHash.hash("\(timestamp.timeIntervalSince1970)-\(trimmed)".prefix(200)))"
            guard state.seenMessageIds.insert(id).inserted else { return nil }

            return ChatMessage(
                id: id,
                role: .user,
                timestamp: timestamp,
                content: [.text(trimmed)]
            )

        case "assistant.message":
            guard let data = json["data"] as? [String: Any] else { return nil }

            var blocks: [MessageBlock] = []

            if let text = data["content"] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    blocks.append(.text(trimmed))
                }
            }

            if let toolRequests = data["toolRequests"] as? [[String: Any]] {
                for request in toolRequests {
                    guard let callId = request["toolCallId"] as? String,
                          let name = request["name"] as? String else { continue }
                    let input = parseToolArguments(request["arguments"])
                    if state.seenToolIds.insert(callId).inserted {
                        blocks.append(.toolUse(ToolUseBlock(id: callId, name: name, input: input)))
                    }
                }
            }

            guard !blocks.isEmpty else { return nil }

            let rawId = (data["messageId"] as? String) ?? "\(timestamp.timeIntervalSince1970)"
            let id = "opencode-assistant-\(StableHash.hash(rawId.prefix(200)))"
            guard state.seenMessageIds.insert(id).inserted else { return nil }

            return ChatMessage(
                id: id,
                role: .assistant,
                timestamp: timestamp,
                content: blocks
            )

        // Pattern 2: OpenAI response_item style
        case "response_item":
            return parseResponseItem(json, timestamp: timestamp, state: &state)

        default:
            return nil
        }
    }

    private func parseResponseItem(_ json: [String: Any], timestamp: Date, state: inout IncrementalParseState) -> ChatMessage? {
        guard let payload = json["payload"] as? [String: Any],
              let payloadType = payload["type"] as? String else {
            return nil
        }

        switch payloadType {
        case "message":
            guard let roleRaw = payload["role"] as? String,
                  let role = ChatRole(rawValue: roleRaw),
                  role == .user || role == .assistant,
                  let content = payload["content"] as? [[String: Any]] else {
                return nil
            }

            let text = content.compactMap { block -> String? in
                guard let type = block["type"] as? String else { return nil }
                switch type {
                case "input_text", "output_text":
                    return block["text"] as? String
                default:
                    return nil
                }
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { return nil }

            let id = "opencode-msg-\(StableHash.hash("\(timestamp.timeIntervalSince1970)-\(roleRaw)-\(text)".prefix(200)))"
            guard state.seenMessageIds.insert(id).inserted else { return nil }

            return ChatMessage(
                id: id,
                role: role,
                timestamp: timestamp,
                content: [.text(text)]
            )

        case "function_call":
            guard let callId = payload["call_id"] as? String,
                  let name = payload["name"] as? String else {
                return nil
            }

            let input = parseToolArguments(payload["arguments"])
            let id = "opencode-tool-\(callId)"
            guard state.seenMessageIds.insert(id).inserted else { return nil }
            state.seenToolIds.insert(callId)

            return ChatMessage(
                id: id,
                role: .assistant,
                timestamp: timestamp,
                content: [.toolUse(ToolUseBlock(id: callId, name: name, input: input))]
            )

        default:
            return nil
        }
    }

    /// Fallback parser for simple role-based JSON lines:
    ///   {"role": "user", "content": "...", "timestamp": "..."}
    private func parseSimpleMessage(_ json: [String: Any], state: inout IncrementalParseState) -> ChatMessage? {
        guard let roleRaw = json["role"] as? String,
              let role = ChatRole(rawValue: roleRaw),
              role == .user || role == .assistant else {
            return nil
        }

        let timestamp = parseTimestamp(json["timestamp"] as? String) ?? Date()

        var blocks: [MessageBlock] = []

        if let text = json["content"] as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                blocks.append(.text(trimmed))
            }
        } else if let parts = json["parts"] as? [[String: Any]] {
            for part in parts {
                if let text = part["text"] as? String {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        blocks.append(.text(trimmed))
                    }
                }
            }
        }

        guard !blocks.isEmpty else { return nil }

        let id = "opencode-\(roleRaw)-\(StableHash.hash("\(timestamp.timeIntervalSince1970)-\(blocks.first!)".prefix(200)))"
        guard state.seenMessageIds.insert(id).inserted else { return nil }

        return ChatMessage(
            id: id,
            role: role,
            timestamp: timestamp,
            content: blocks
        )
    }

    private func parseToolOutput(_ json: [String: Any], state: inout IncrementalParseState) -> String? {
        // Pattern 1: Copilot-style tool completion
        if let type = json["type"] as? String, type == "tool.execution_complete",
           let data = json["data"] as? [String: Any],
           let callId = data["toolCallId"] as? String {
            let success = data["success"] as? Bool ?? true
            let resultData = data["result"] as? [String: Any]
            let content = (resultData?["content"] as? String) ?? (resultData?["detailedContent"] as? String)

            state.toolResults[callId] = ConversationParser.ToolResult(
                content: content,
                stdout: nil,
                stderr: nil,
                isError: !success
            )
            return callId
        }

        // Pattern 2: Codex-style custom_tool_call_output
        if let type = json["type"] as? String, type == "response_item",
           let payload = json["payload"] as? [String: Any],
           payload["type"] as? String == "custom_tool_call_output",
           let callId = payload["call_id"] as? String {
            let outputText = extractToolOutputText(payload["output"])
            state.toolResults[callId] = ConversationParser.ToolResult(
                content: outputText,
                stdout: nil,
                stderr: nil,
                isError: false
            )
            return callId
        }

        return nil
    }

    private func extractToolOutputText(_ value: Any?) -> String? {
        if let string = value as? String {
            if let data = string.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let output = json["output"] as? String {
                    return output
                }
                if let nested = json["metadata"] as? [String: Any],
                   let output = nested["output"] as? String {
                    return output
                }
            }
            return string
        }

        if let dict = value as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }

        return nil
    }

    private func parseToolArguments(_ value: Any?) -> [String: String] {
        guard let value else { return [:] }

        if let string = value as? String {
            if let data = string.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return flatten(json)
            }
            return ["arguments": string]
        }

        if let dict = value as? [String: Any] {
            return flatten(dict)
        }

        return [:]
    }

    private func flatten(_ dict: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in dict {
            switch value {
            case let string as String:
                result[key] = string
            case let int as Int:
                result[key] = String(int)
            case let bool as Bool:
                result[key] = bool ? "true" : "false"
            default:
                if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                   let string = String(data: data, encoding: .utf8) {
                    result[key] = string
                }
            }
        }
        return result
    }

    private func parseTimestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private func truncate(_ message: String?, maxLength: Int) -> String? {
        guard let message else { return nil }
        let cleaned = message.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
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
            "<reminder>"
        ]

        if generatedPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            return nil
        }

        return trimmed
    }

    private func sessionFilePath(sessionId: String) -> String? {
        // Try direct path first: ~/.opencode/sessions/{sessionId}/events.jsonl
        let directPath = OpenCodePaths.sessionsDir
            .appendingPathComponent(sessionId)
            .appendingPathComponent("events.jsonl")
            .path
        if FileManager.default.fileExists(atPath: directPath) {
            return directPath
        }

        // Search sessions directory for a matching file
        let sessionsDir = OpenCodePaths.sessionsDir
        guard let enumerator = FileManager.default.enumerator(at: sessionsDir, includingPropertiesForKeys: nil) else {
            return nil
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            if url.lastPathComponent.contains(sessionId) || url.deletingLastPathComponent().lastPathComponent == sessionId {
                return url.path
            }
        }

        return nil
    }
}
