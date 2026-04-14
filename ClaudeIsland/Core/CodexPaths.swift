//
//  CodexPaths.swift
//  ClaudeIsland
//
//  Single source of truth for Codex config/session paths.
//

import Foundation

enum CodexPaths {
    static let codexDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")

    static let hooksDir = codexDir.appendingPathComponent("hooks")

    static let hooksFile = codexDir.appendingPathComponent("hooks.json")

    static let sessionsDir = codexDir.appendingPathComponent("sessions")

    static let archivedSessionsDir = codexDir.appendingPathComponent("archived_sessions")

    static let sessionIndexFile = codexDir.appendingPathComponent("session_index.jsonl")

    static let hookScriptShellPath = shellQuote(hooksDir.appendingPathComponent("codex-island-state.py").path)

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
