//
//  BuddySelector.swift
//  ClaudeIsland
//
//  Manages buddy icon selection state for the settings menu
//

import Combine
import Foundation

@MainActor
class BuddySelector: ObservableObject {
    static let shared = BuddySelector()

    // MARK: - Published State

    @Published var isPickerExpanded: Bool = false
    @Published var selectedBuddy: BuddyIcon = AppSettings.buddyIcon

    private init() {}

    // MARK: - Public API

    /// Extra height needed when picker is expanded
    var expandedPickerHeight: CGFloat {
        guard isPickerExpanded else { return 0 }
        let totalOptions = BuddyIcon.allCases.count
        return CGFloat(totalOptions) * 40 + 8
    }

    func select(_ buddy: BuddyIcon) {
        selectedBuddy = buddy
        AppSettings.buddyIcon = buddy
    }
}
