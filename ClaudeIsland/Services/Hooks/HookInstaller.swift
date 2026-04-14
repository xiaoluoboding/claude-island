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
        installCopilotHooks()
        installOpenCodeHooks()
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

    private static func installCopilotHooks() {
        installBundledScript(
            named: "codex-island-state",
            into: CopilotPaths.hooksDir.appendingPathComponent("copilot-island-state.py")
        )
        updateCopilotConfigFile(at: CopilotPaths.configFile)
    }

    private static func installOpenCodeHooks() {
        installOpenCodePlugin()
        registerOpenCodePlugin()
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

    private static func updateCopilotConfigFile(at configURL: URL) {
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }

        let python = detectPython()
        let hookEvents = [
            "sessionStart",
            "sessionEnd",
            "userPromptSubmitted",
            "preToolUse",
            "postToolUse",
            "postToolUseFailure",
            "errorOccurred",
            "agentStop"
        ]

        var hooks = json["hooks"] as? [String: Any] ?? [:]

        for (event, value) in hooks {
            guard var entries = value as? [[String: Any]] else { continue }
            entries.removeAll(where: isCopilotIslandHook)
            if entries.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = entries
            }
        }

        for event in hookEvents {
            let command = "\(python) \(CopilotPaths.hookScriptShellPath) --source copilot --event \(event)"
            let entry: [String: Any] = [
                "type": "command",
                "timeoutSec": 10,
                "bash": command,
                "powershell": command
            ]
            var entries = hooks[event] as? [[String: Any]] ?? []
            entries.append(entry)
            hooks[event] = entries
        }

        json["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: configURL)
        }
    }

    /// Install the OpenCode plugin JS + package.json to ~/.claude-island/opencode-plugin/
    private static func installOpenCodePlugin() {
        let pluginDir = OpenCodePaths.pluginDir

        try? FileManager.default.createDirectory(
            at: pluginDir,
            withIntermediateDirectories: true
        )

        // Copy the bundled plugin .mjs file
        if let bundledURL = Bundle.main.url(
            forResource: "claude-island-opencode-plugin",
            withExtension: "mjs"
        ) {
            let dest = OpenCodePaths.pluginFile
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: bundledURL, to: dest)
        }

        // Write a minimal package.json that makes this directory a valid plugin
        let packageJSON: [String: Any] = [
            "name": "claude-island-opencode-plugin",
            "version": "1.0.0",
            "type": "module",
            "main": "claude-island-opencode-plugin.mjs",
            "exports": ["./server": "./claude-island-opencode-plugin.mjs"]
        ]

        if let data = try? JSONSerialization.data(
            withJSONObject: packageJSON,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: OpenCodePaths.pluginPackageJSON)
        }
    }

    /// Register the plugin in ~/.config/opencode/opencode.json under the "plugin" key
    private static func registerOpenCodePlugin() {
        let configURL = OpenCodePaths.configFile

        // Read existing config (or start with empty)
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        } else {
            // Config file doesn't exist — OpenCode may not be installed
            return
        }

        let pluginPath = OpenCodePaths.pluginDir.path

        // Get existing plugins array
        var plugins: [Any] = json["plugin"] as? [Any] ?? []

        // Check if our plugin is already registered
        let alreadyRegistered = plugins.contains { entry in
            if let str = entry as? String { return str == pluginPath }
            if let arr = entry as? [Any], let str = arr.first as? String { return str == pluginPath }
            return false
        }

        if !alreadyRegistered {
            plugins.append(pluginPath)
            json["plugin"] = plugins
            if let data = try? JSONSerialization.data(
                withJSONObject: json,
                options: [.prettyPrinted, .sortedKeys]
            ) {
                try? data.write(to: configURL)
            }
        }
    }

    /// Check if hooks are currently installed
    static func isInstalled() -> Bool {
        isInstalledInJSON(ClaudePaths.settingsFile, matching: "claude-island-state.py") ||
        isInstalledInJSON(CodexPaths.hooksFile, matching: "codex-island-state.py") ||
        isInstalledInJSON(CopilotPaths.configFile, matching: "copilot-island-state.py") ||
        isOpenCodePluginInstalled()
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
        uninstallFromJSON(
            CopilotPaths.configFile,
            scriptURL: CopilotPaths.hooksDir.appendingPathComponent("copilot-island-state.py"),
            remover: removingCopilotIslandHooks
        )
        uninstallOpenCodePlugin()
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

    nonisolated private static func removingCopilotIslandHooks(from entry: [String: Any]) -> [String: Any]? {
        if var entryHooks = entry["hooks"] as? [[String: Any]] {
            entryHooks.removeAll(where: isCopilotIslandHook)
            guard !entryHooks.isEmpty else { return nil }
            var updatedEntry = entry
            updatedEntry["hooks"] = entryHooks
            return updatedEntry
        }

        if isCopilotIslandHook(entry) {
            return nil
        }
        return entry
    }

    nonisolated private static func isCopilotIslandHook(_ hook: [String: Any]) -> Bool {
        let command = (hook["command"] as? String) ?? (hook["bash"] as? String) ?? ""
        return command.contains("copilot-island-state.py")
    }

    /// Check if the OpenCode plugin is registered in opencode.json
    private static func isOpenCodePluginInstalled() -> Bool {
        guard let data = try? Data(contentsOf: OpenCodePaths.configFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["plugin"] as? [Any] else {
            return false
        }

        let pluginPath = OpenCodePaths.pluginDir.path
        return plugins.contains { entry in
            if let str = entry as? String { return str == pluginPath }
            if let arr = entry as? [Any], let str = arr.first as? String { return str == pluginPath }
            return false
        }
    }

    /// Remove the OpenCode plugin from config and delete plugin files
    private static func uninstallOpenCodePlugin() {
        // Remove from opencode.json config
        let configURL = OpenCodePaths.configFile
        if let data = try? Data(contentsOf: configURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var plugins = json["plugin"] as? [Any] {
            let pluginPath = OpenCodePaths.pluginDir.path
            plugins.removeAll { entry in
                if let str = entry as? String { return str == pluginPath }
                if let arr = entry as? [Any], let str = arr.first as? String { return str == pluginPath }
                return false
            }
            if plugins.isEmpty {
                json.removeValue(forKey: "plugin")
            } else {
                json["plugin"] = plugins
            }
            if let updated = try? JSONSerialization.data(
                withJSONObject: json,
                options: [.prettyPrinted, .sortedKeys]
            ) {
                try? updated.write(to: configURL)
            }
        }

        // Remove plugin files
        try? FileManager.default.removeItem(at: OpenCodePaths.pluginDir)
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
                    if let command = entry["command"] as? String, command.contains(needle) {
                        return true
                    }
                    if let bash = entry["bash"] as? String, bash.contains(needle) {
                        return true
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
