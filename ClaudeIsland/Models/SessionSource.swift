//
//  SessionSource.swift
//  ClaudeIsland
//
//  Identifies which CLI produced a session.
//

import SwiftUI

enum SessionSource: String, Codable, Equatable, Sendable, CaseIterable {
    case claude
    case codex

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    var shortLabel: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    var accentColor: Color {
        switch self {
        case .claude:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex:
            return Color(red: 76 / 255, green: 90 / 255, blue: 247 / 255)
        }
    }

    var iconAssetName: String? {
        switch self {
        case .claude:
            return nil
        case .codex:
            return "CodexSourceIcon"
        }
    }

    var supportsPermissions: Bool {
        self == .claude
    }

    var supportsDirectMessaging: Bool {
        self == .claude
    }
}
