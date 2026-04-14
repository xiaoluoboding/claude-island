//
//  BuddyPickerRow.swift
//  ClaudeIsland
//
//  Buddy icon selection picker for settings menu
//

import SwiftUI

struct BuddyPickerRow: View {
    @ObservedObject var buddySelector: BuddySelector
    @State private var isHovered = false

    private var isExpanded: Bool {
        buddySelector.isPickerExpanded
    }

    private func setExpanded(_ value: Bool) {
        buddySelector.isPickerExpanded = value
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row - shows current selection
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    setExpanded(!isExpanded)
                }
            } label: {
                HStack(spacing: 10) {
                    MultiCliPixelIcon(size: 14, buddy: buddySelector.selectedBuddy)
                        .frame(width: 16)

                    Text("Buddy")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textColor)

                    Spacer()

                    Text(buddySelector.selectedBuddy.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }

            // Expanded buddy list
            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(BuddyIcon.allCases, id: \.self) { buddy in
                        BuddyOptionRow(
                            buddy: buddy,
                            isSelected: buddySelector.selectedBuddy == buddy
                        ) {
                            buddySelector.select(buddy)
                        }
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 4)
            }
        }
    }

    private var textColor: Color {
        .white.opacity(isHovered ? 1.0 : 0.7)
    }
}

// MARK: - Buddy Option Row

private struct BuddyOptionRow: View {
    let buddy: BuddyIcon
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                MultiCliPixelIcon(size: 18, animate: isHovered, buddy: buddy)
                    .frame(width: 20)

                Text(buddy.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(isHovered ? 1.0 : 0.7))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(TerminalColors.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
