//
//  Settings.swift
//  ClaudeIsland
//
//  App settings manager using UserDefaults
//

import Foundation

/// Available buddy icons for the notch
enum BuddyIcon: String, CaseIterable {
    case invader = "Invader"
    case ghost = "Ghost"
    case coffee = "Coffee"
    case alien = "Alien"
    case dino = "Dino"
    case gamepad = "Gamepad"
    case skull = "Skull"
    case phoenix = "Phoenix"
    case ufoBeam = "UFO Beam"
    case robot = "Robot"
}

/// Available notification sounds
enum NotificationSound: String, CaseIterable {
    case none = "None"
    case pop = "Pop"
    case ping = "Ping"
    case tink = "Tink"
    case glass = "Glass"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case hero = "Hero"
    case morse = "Morse"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case basso = "Basso"

    /// The system sound name to use with NSSound, or nil for no sound
    var soundName: String? {
        self == .none ? nil : rawValue
    }
}

enum AppSettings {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let notificationSound = "notificationSound"
        static let claudeDirectoryName = "claudeDirectoryName"
        static let buddyIcon = "buddyIcon"
    }

    // MARK: - Notification Sound

    /// The sound to play when Claude finishes and is ready for input
    static var notificationSound: NotificationSound {
        get {
            guard let rawValue = defaults.string(forKey: Keys.notificationSound),
                  let sound = NotificationSound(rawValue: rawValue) else {
                return .pop // Default to Pop
            }
            return sound
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.notificationSound)
        }
    }

    // MARK: - Claude Directory

    /// The name of the Claude config directory under the user's home folder.
    /// Defaults to ".claude" (standard Claude Code installation).
    /// Change to ".claude-internal" (or similar) for enterprise/custom distributions.
    static var claudeDirectoryName: String {
        get {
            let value = defaults.string(forKey: Keys.claudeDirectoryName) ?? ""
            return value.isEmpty ? ".claude" : value
        }
        set {
            defaults.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Keys.claudeDirectoryName)
        }
    }

    // MARK: - Buddy Icon

    /// The pixel-art buddy icon shown in the notch
    static var buddyIcon: BuddyIcon {
        get {
            guard let rawValue = defaults.string(forKey: Keys.buddyIcon),
                  let icon = BuddyIcon(rawValue: rawValue) else {
                return .invader
            }
            return icon
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.buddyIcon)
        }
    }
}
