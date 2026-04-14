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
    case copilot
    case opencode

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .copilot: return "Copilot"
        case .opencode: return "OpenCode"
        }
    }

    var shortLabel: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .copilot: return "Copilot"
        case .opencode: return "OC"
        }
    }

    var accentColor: Color {
        switch self {
        case .claude:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex:
            return Color(red: 76 / 255, green: 90 / 255, blue: 247 / 255)
        case .copilot:
            return Color(red: 240 / 255, green: 149 / 255, blue: 247 / 255)
        case .opencode:
            return Color(red: 56 / 255, green: 189 / 255, blue: 148 / 255)
        }
    }

    var secondaryAccentColor: Color {
        switch self {
        case .claude:
            return Color(red: 0.62, green: 0.31, blue: 0.22)
        case .codex:
            return Color(red: 99 / 255, green: 102 / 255, blue: 241 / 255)
        case .copilot:
            return Color(red: 170 / 255, green: 86 / 255, blue: 177 / 255)
        case .opencode:
            return Color(red: 34 / 255, green: 150 / 255, blue: 118 / 255)
        }
    }

    var badgeGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor.opacity(0.22), secondaryAccentColor.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var badgeBorderColor: Color {
        accentColor.opacity(0.35)
    }

    var iconAssetName: String? {
        switch self {
        case .claude:
            return "ClaudeSourceIcon"
        case .codex:
            return "CodexSourceIcon"
        case .copilot:
            return nil
        case .opencode:
            return nil
        }
    }

    var symbolName: String? {
        switch self {
        default:
            return nil
        }
    }

    var supportsPermissions: Bool {
        self == .claude
    }

    var supportsDirectMessaging: Bool {
        self == .claude
    }

    var supportsSessionFocus: Bool {
        self != .opencode
    }
}
