//
//  CodexAppLauncher.swift
//  ClaudeIsland
//
//  Activates or launches Codex.app when a Codex session is selected.
//

import AppKit

enum CodexAppLauncher {
    private static let possibleBundleIdentifiers: [String] = [
        "com.openai.codex",
        "com.openai.chatgpt.codex",
        "com.openai.chatgpt"
    ]

    @MainActor
    static func openOrActivate(projectPath: String? = nil) -> Bool {
        let projectURL = validatedProjectURL(from: projectPath)
        guard let appURL = installedCodexAppURL() else { return false }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        if let projectURL {
            NSWorkspace.shared.open(
                [projectURL],
                withApplicationAt: appURL,
                configuration: configuration,
                completionHandler: nil
            )
            return true
        }

        if let running = NSWorkspace.shared.runningApplications.first(where: matchesCodexApp) {
            return running.activate(options: [.activateAllWindows])
        }

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration, completionHandler: nil)
        return true
    }

    @MainActor
    private static func matchesCodexApp(_ app: NSRunningApplication) -> Bool {
        if let bundleIdentifier = app.bundleIdentifier,
           possibleBundleIdentifiers.contains(bundleIdentifier) {
            return true
        }

        return app.localizedName?.caseInsensitiveCompare("Codex") == .orderedSame
    }

    @MainActor
    private static func installedCodexAppURL() -> URL? {
        for bundleIdentifier in possibleBundleIdentifiers {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                return appURL
            }
        }
        return nil
    }

    private static func validatedProjectURL(from path: String?) -> URL? {
        guard let path else { return nil }
        guard !path.isEmpty else { return nil }

        let expanded = NSString(string: path).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }
}
