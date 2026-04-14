//
//  CodexConversationParser.swift
//  ClaudeIsland
//
//  Parses Codex session JSONL files into the app's shared chat/session model.
//

import Foundation

actor CodexConversationParser {
    static let shared = CodexConversationParser()

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
    private var sessionPathCache: [String: String] = [:]
    private var sessionTitleCache: [String: String] = [:]
    private var titleCacheLoaded = false

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
        let preferredSummary = truncate(firstUser, maxLength: 50) ?? sessionTitle(for: sessionId)

        return ConversationInfo(
            summary: preferredSummary,
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

    private func parseMessageLine(_ json: [String: Any], state: inout IncrementalParseState) -> ChatMessage? {
        guard json["type"] as? String == "response_item",
              let payload = json["payload"] as? [String: Any],
              let payloadType = payload["type"] as? String else {
            return nil
        }

        let timestamp = parseTimestamp(json["timestamp"] as? String) ?? Date()

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

            let id = "codex-msg-\(StableHash.hash("\(timestamp.timeIntervalSince1970)-\(roleRaw)-\(text)".prefix(200)))"
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
            let id = "codex-tool-\(callId)"
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

    private func parseToolOutput(_ json: [String: Any], state: inout IncrementalParseState) -> String? {
        guard json["type"] as? String == "response_item",
              let payload = json["payload"] as? [String: Any],
              payload["type"] as? String == "custom_tool_call_output",
              let callId = payload["call_id"] as? String else {
            return nil
        }

        let outputText = extractToolOutputText(payload["output"])
        state.toolResults[callId] = ConversationParser.ToolResult(
            content: outputText,
            stdout: nil,
            stderr: nil,
            isError: false
        )
        return callId
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
            "# AGENTS.md instructions for "
        ]

        if generatedPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            return nil
        }

        return trimmed
    }

    private func sessionTitle(for sessionId: String) -> String? {
        if !titleCacheLoaded {
            loadSessionTitles()
        }
        return sessionTitleCache[sessionId]
    }

    private func loadSessionTitles() {
        titleCacheLoaded = true
        guard let content = try? String(contentsOf: codexSessionIndexFile(), encoding: .utf8) else {
            return
        }

        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? String else {
                continue
            }
            if let title = json["thread_name"] as? String, !title.isEmpty {
                sessionTitleCache[id] = title
            }
        }
    }

    private func sessionFilePath(sessionId: String) -> String? {
        if let cached = sessionPathCache[sessionId], FileManager.default.fileExists(atPath: cached) {
            return cached
        }

        let locations = codexSessionRoots()
        for root in locations {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension == "jsonl" else { continue }
                if url.lastPathComponent.contains(sessionId) {
                    sessionPathCache[sessionId] = url.path
                    return url.path
                }
            }
        }

        return nil
    }

    private func codexSessionIndexFile() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/session_index.jsonl")
    }

    private func codexSessionRoots() -> [URL] {
        let codexDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        return [
            codexDir.appendingPathComponent("sessions"),
            codexDir.appendingPathComponent("archived_sessions")
        ]
    }
}

actor CopilotConversationParser {
    static let shared = CopilotConversationParser()

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
            summary: truncate(firstUser, maxLength: 50) ?? "Copilot Session",
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

    private func parseMessageLine(_ json: [String: Any], state: inout IncrementalParseState) -> ChatMessage? {
        guard let type = json["type"] as? String else { return nil }
        let timestamp = parseTimestamp(json["timestamp"] as? String) ?? Date()

        switch type {
        case "user.message":
            guard let data = json["data"] as? [String: Any],
                  let text = data["content"] as? String else { return nil }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let id = "copilot-user-\(StableHash.hash("\(timestamp.timeIntervalSince1970)-\(trimmed)".prefix(200)))"
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
            let id = "copilot-assistant-\(StableHash.hash(rawId.prefix(200)))"
            guard state.seenMessageIds.insert(id).inserted else { return nil }

            return ChatMessage(
                id: id,
                role: .assistant,
                timestamp: timestamp,
                content: blocks
            )

        default:
            return nil
        }
    }

    private func parseToolOutput(_ json: [String: Any], state: inout IncrementalParseState) -> String? {
        guard json["type"] as? String == "tool.execution_complete",
              let data = json["data"] as? [String: Any],
              let callId = data["toolCallId"] as? String else {
            return nil
        }

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

    private func parseToolArguments(_ value: Any?) -> [String: String] {
        guard let dict = value as? [String: Any] else { return [:] }
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

        if trimmed.hasPrefix("<current_datetime>") || trimmed.hasPrefix("<reminder>") {
            return nil
        }

        return trimmed
    }

    private func sessionFilePath(sessionId: String) -> String? {
        let path = CopilotPaths.sessionStateDir
            .appendingPathComponent(sessionId)
            .appendingPathComponent("events.jsonl")
            .path
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }
}
