//
//  OpenCodePaths.swift
//  ClaudeIsland
//
//  Single source of truth for OpenCode config/session paths.
//

import Foundation

enum OpenCodePaths {
    static let opencodeDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".opencode")

    static let hooksDir = opencodeDir.appendingPathComponent("hooks")

    static let hooksFile = opencodeDir.appendingPathComponent("hooks.json")

    static let sessionsDir = opencodeDir.appendingPathComponent("sessions")

    static let hookScriptShellPath = shellQuote(hooksDir.appendingPathComponent("opencode-island-state.py").path)

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
