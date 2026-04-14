//
//  HookInstaller.swift
//  ClaudeIsland
//
//  Auto-installs Claude Code hooks on app launch
//

import Foundation

struct HookInstaller {

    /// Install hook script and update settings.json on app launch
    static func installIfNeeded() {
        installClaudeHooks()
        installCodexHooks()
    }

    private static func installClaudeHooks() {
        installBundledScript(
            named: "claude-island-state",
            into: ClaudePaths.hooksDir.appendingPathComponent("claude-island-state.py")
        )
        updateClaudeSettings(at: ClaudePaths.settingsFile)
    }

    private static func installCodexHooks() {
        installBundledScript(
            named: "codex-island-state",
            into: CodexPaths.hooksDir.appendingPathComponent("codex-island-state.py")
        )
        updateCodexHooksFile(at: CodexPaths.hooksFile)
    }

    private static func installBundledScript(named resource: String, into destination: URL) {
        try? FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let bundled = Bundle.main.url(forResource: resource, withExtension: "py") {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: bundled, to: destination)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destination.path
            )
        }
    }

    private static func updateClaudeSettings(at settingsURL: URL) {
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        let python = detectPython()
        let command = "\(python) \(ClaudePaths.hookScriptShellPath)"
        let hookEntry: [[String: Any]] = [["type": "command", "command": command]]
        let hookEntryWithTimeout: [[String: Any]] = [["type": "command", "command": command, "timeout": 86400]]
        let withMatcher: [[String: Any]] = [["matcher": "*", "hooks": hookEntry]]
        let withMatcherAndTimeout: [[String: Any]] = [["matcher": "*", "hooks": hookEntryWithTimeout]]
        let withoutMatcher: [[String: Any]] = [["hooks": hookEntry]]
        let preCompactConfig: [[String: Any]] = [
            ["matcher": "auto", "hooks": hookEntry],
            ["matcher": "manual", "hooks": hookEntry]
        ]

        var hooks = json["hooks"] as? [String: Any] ?? [:]

        let hookEvents: [(String, [[String: Any]])] = [
            ("UserPromptSubmit", withoutMatcher),
            ("PreToolUse", withMatcher),
            ("PostToolUse", withMatcher),
            // PostToolUseFailure fires when a tool errored or was interrupted — we
            // currently miss these signals entirely (v2.0.x+)
            ("PostToolUseFailure", withMatcher),
            ("PermissionRequest", withMatcherAndTimeout),
            // PermissionDenied surfaces auto-mode classifier denials (v2.1.88+)
            ("PermissionDenied", withMatcher),
            ("Notification", withMatcher),
            ("Stop", withoutMatcher),
            // StopFailure fires on API errors (rate limit, auth, billing) — lets
            // us show the failure in the notch instead of appearing stuck (v2.1.78+)
            ("StopFailure", withoutMatcher),
            // SubagentStart pairs with existing SubagentStop (v2.0.43+)
            ("SubagentStart", withoutMatcher),
            ("SubagentStop", withoutMatcher),
            ("SessionStart", withoutMatcher),
            ("SessionEnd", withoutMatcher),
            ("PreCompact", preCompactConfig),
            // PostCompact pairs with PreCompact so the UI can exit the
            // .compacting phase cleanly (v2.1.76+)
            ("PostCompact", preCompactConfig),
        ]

        for (event, config) in hookEvents {
            let existingEvent = hooks[event] as? [[String: Any]] ?? []
            let cleanedEvent = existingEvent.compactMap { removingClaudeIslandHooks(from: $0) }
            hooks[event] = cleanedEvent + config
        }

        json["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: settingsURL)
        }
    }

    private static func updateCodexHooksFile(at hooksURL: URL) {
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: hooksURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        let python = detectPython()
        let command = "\(python) \(CodexPaths.hookScriptShellPath)"
        let hookEntry: [[String: Any]] = [["type": "command", "command": command, "timeout": 5]]
        let entry: [[String: Any]] = [["hooks": hookEntry]]
        let events = ["UserPromptSubmit", "Stop"]

        var hooks = json["hooks"] as? [String: Any] ?? [:]

        // First remove all existing codex-island hooks from every event.
        // This lets us clean up stale SessionStart hooks from older versions.
        for (event, value) in hooks {
            guard let existingEvent = value as? [[String: Any]] else { continue }
            let cleanedEvent = existingEvent.compactMap { removingCodexIslandHooks(from: $0) }
            if cleanedEvent.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = cleanedEvent
            }
        }

        for event in events {
            let existingEvent = hooks[event] as? [[String: Any]] ?? []
            hooks[event] = existingEvent + entry
        }

        json["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: hooksURL)
        }
    }

    /// Check if hooks are currently installed
    static func isInstalled() -> Bool {
        isInstalledInJSON(ClaudePaths.settingsFile, matching: "claude-island-state.py") ||
        isInstalledInJSON(CodexPaths.hooksFile, matching: "codex-island-state.py")
    }

    /// Uninstall hooks from settings.json and remove script
    static func uninstall() {
        uninstallFromJSON(
            ClaudePaths.settingsFile,
            scriptURL: ClaudePaths.hooksDir.appendingPathComponent("claude-island-state.py"),
            remover: removingClaudeIslandHooks
        )
        uninstallFromJSON(
            CodexPaths.hooksFile,
            scriptURL: CodexPaths.hooksDir.appendingPathComponent("codex-island-state.py"),
            remover: removingCodexIslandHooks
        )
    }

    private static func detectPython() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return "python3"
            }
        } catch {}

        return "python"
    }

    nonisolated private static func removingClaudeIslandHooks(from entry: [String: Any]) -> [String: Any]? {
        guard var entryHooks = entry["hooks"] as? [[String: Any]] else {
            return entry
        }

        entryHooks.removeAll(where: isClaudeIslandHook)
        guard !entryHooks.isEmpty else { return nil }

        var updatedEntry = entry
        updatedEntry["hooks"] = entryHooks
        return updatedEntry
    }

    nonisolated private static func isClaudeIslandHook(_ hook: [String: Any]) -> Bool {
        let cmd = hook["command"] as? String ?? ""
        return cmd.contains("claude-island-state.py")
    }

    nonisolated private static func removingCodexIslandHooks(from entry: [String: Any]) -> [String: Any]? {
        guard var entryHooks = entry["hooks"] as? [[String: Any]] else {
            return entry
        }

        entryHooks.removeAll(where: isCodexIslandHook)
        guard !entryHooks.isEmpty else { return nil }

        var updatedEntry = entry
        updatedEntry["hooks"] = entryHooks
        return updatedEntry
    }

    nonisolated private static func isCodexIslandHook(_ hook: [String: Any]) -> Bool {
        let cmd = hook["command"] as? String ?? ""
        return cmd.contains("codex-island-state.py")
    }

    private static func isInstalledInJSON(_ url: URL, matching needle: String) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        for (_, value) in hooks {
            if let entries = value as? [[String: Any]] {
                for entry in entries {
                    if let entryHooks = entry["hooks"] as? [[String: Any]] {
                        for hook in entryHooks {
                            if let cmd = hook["command"] as? String, cmd.contains(needle) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    private static func uninstallFromJSON(
        _ url: URL,
        scriptURL: URL,
        remover: ([String: Any]) -> [String: Any]?
    ) {
        try? FileManager.default.removeItem(at: scriptURL)

        guard let data = try? Data(contentsOf: url),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = json["hooks"] as? [String: Any] else {
            return
        }

        for (event, value) in hooks {
            if var entries = value as? [[String: Any]] {
                entries = entries.compactMap(remover)
                if entries.isEmpty {
                    hooks.removeValue(forKey: event)
                } else {
                    hooks[event] = entries
                }
            }
        }

        if hooks.isEmpty {
            json.removeValue(forKey: "hooks")
        } else {
            json["hooks"] = hooks
        }

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: url)
        }
    }
}
