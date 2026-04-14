//
//  OpenCodePaths.swift
//  ClaudeIsland
//
//  Single source of truth for OpenCode directory paths.
//  OpenCode uses XDG-style layout:
//    Config:  ~/.config/opencode/opencode.json
//    Data:    ~/.local/share/opencode/opencode.db  (SQLite)
//    State:   ~/.local/state/opencode/
//    Install: ~/.opencode/  (bin, node_modules)
//

import Foundation

enum OpenCodePaths {
    private static let home = FileManager.default.homeDirectoryForCurrentUser

    /// ~/.config/opencode/opencode.json
    static let configFile = home
        .appendingPathComponent(".config/opencode/opencode.json")

    /// ~/.local/share/opencode/opencode.db
    static let databaseFile = home
        .appendingPathComponent(".local/share/opencode/opencode.db")

    /// Directory where the Claude Island plugin is installed
    static let pluginDir = home
        .appendingPathComponent(".claude-island/opencode-plugin")

    /// The plugin entry-point file
    static let pluginFile = pluginDir
        .appendingPathComponent("claude-island-opencode-plugin.mjs")

    /// package.json for the plugin directory
    static let pluginPackageJSON = pluginDir
        .appendingPathComponent("package.json")

    /// OpenCode binary (for `opencode plugin` CLI)
    static let opencodeDir = home.appendingPathComponent(".opencode")
}
