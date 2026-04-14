//
//  NotchHeaderView.swift
//  ClaudeIsland
//
//  Header bar for the dynamic island
//

import Combine
import SwiftUI

struct SessionSourceBrandIcon: View {
    let source: SessionSource
    let size: CGFloat
    var animate: Bool = false
    var prefersClaudeTheme: Bool = false
    var buddy: BuddyIcon = AppSettings.buddyIcon

    var body: some View {
        Group {
            if prefersClaudeTheme || source == .claude {
                ClaudeCrabIcon(size: size, color: SessionSource.claude.accentColor, animateLegs: animate)
            } else if source == .copilot {
                CopilotPixelFaceIcon(size: size, animate: true)
            } else {
                MultiCliPixelIcon(size: size, animate: animate, buddy: buddy)
            }
        }
    }
}

struct CopilotPixelFaceIcon: View {
    let size: CGFloat
    var animate: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 3.0)
            let isBlinking = animate && phase < 0.22

            Canvas { context, canvasSize in
                let grid: CGFloat = 16
                let step = min(canvasSize.width, canvasSize.height) / grid
                let pixelSize = step * 0.94
                let xOffset = (canvasSize.width - grid * step) / 2
                let yOffset = (canvasSize.height - grid * step) / 2

                func draw(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 1, _ h: CGFloat = 1, _ color: Color) {
                    let rect = CGRect(
                        x: xOffset + x * step + (step - pixelSize) / 2,
                        y: yOffset + y * step + (step - pixelSize) / 2,
                        width: pixelSize * w,
                        height: pixelSize * h
                    )
                    context.fill(Path(rect), with: .color(color))
                }

                let outline = Color(red: 0.75, green: 0.84, blue: 0.98)
                let mouth = SessionSource.copilot.accentColor
                let teeth = Color(red: 0.67, green: 0.95, blue: 0.45)

                // Eye outlines (left + right)
                if isBlinking {
                    draw(3, 4, 3, 1, outline)
                    draw(10, 4, 3, 1, outline)
                } else {
                    draw(3, 2, 3, 1, outline)
                    draw(3, 5, 3, 1, outline)
                    draw(3, 2, 1, 4, outline)
                    draw(5, 2, 1, 4, outline)

                    draw(10, 2, 3, 1, outline)
                    draw(10, 5, 3, 1, outline)
                    draw(10, 2, 1, 4, outline)
                    draw(12, 2, 1, 4, outline)
                }

                // Mouth + cheeks
                draw(2, 8, 1, 4, mouth)
                draw(13, 8, 1, 4, mouth)
                draw(4, 11, 9, 1, mouth)

                // Teeth
                draw(6, 8, 1, 2, teeth)
                draw(9, 8, 1, 2, teeth)
            }
            .frame(width: size, height: size)
        }
    }
}

struct CopilotPixelBadgeIcon: View {
    let size: CGFloat

    var body: some View {
        CopilotPixelFaceIcon(size: size, animate: true)
    }
}

struct MultiCliPixelIcon: View {
    let size: CGFloat
    var animate: Bool = false
    var buddy: BuddyIcon = AppSettings.buddyIcon

    private var pixels: [(x: CGFloat, y: CGFloat, color: Color)] {
        switch buddy {
        case .invader:
            return Self.invaderPixels
        case .ghost:
            return Self.ghostPixels
        case .coffee:
            return Self.coffeePixels
        case .alien:
            return Self.alienPixels
        case .dino:
            return Self.dinoPixels
        case .gamepad:
            return Self.gamepadPixels
        case .skull:
            return Self.skullPixels
        case .phoenix:
            return Self.phoenixPixels
        case .ufoBeam:
            return Self.ufoBeamPixels
        case .robot:
            return Self.robotPixels
        }
    }

    // MARK: - Pixel Data

    private static let invaderPixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (2, 0, Color(red: 247 / 255, green: 37 / 255, blue: 133 / 255)),
        (5, 0, Color(red: 247 / 255, green: 37 / 255, blue: 133 / 255)),
        (3, 1, Color(red: 171 / 255, green: 21 / 255, blue: 162 / 255)),
        (4, 1, Color(red: 171 / 255, green: 21 / 255, blue: 162 / 255)),
        (2, 2, Color(red: 106 / 255, green: 9 / 255, blue: 180 / 255)),
        (3, 2, Color(red: 106 / 255, green: 9 / 255, blue: 180 / 255)),
        (4, 2, Color(red: 106 / 255, green: 9 / 255, blue: 180 / 255)),
        (5, 2, Color(red: 106 / 255, green: 9 / 255, blue: 180 / 255)),
        (1, 3, Color(red: 74 / 255, green: 11 / 255, blue: 169 / 255)),
        (2, 3, Color(red: 74 / 255, green: 11 / 255, blue: 169 / 255)),
        (5, 3, Color(red: 74 / 255, green: 11 / 255, blue: 169 / 255)),
        (6, 3, Color(red: 74 / 255, green: 11 / 255, blue: 169 / 255)),
        (0, 4, Color(red: 61 / 255, green: 36 / 255, blue: 184 / 255)),
        (1, 4, Color(red: 61 / 255, green: 36 / 255, blue: 184 / 255)),
        (2, 4, Color(red: 61 / 255, green: 36 / 255, blue: 184 / 255)),
        (3, 4, Color(red: 61 / 255, green: 36 / 255, blue: 184 / 255)),
        (4, 4, Color(red: 61 / 255, green: 36 / 255, blue: 184 / 255)),
        (5, 4, Color(red: 61 / 255, green: 36 / 255, blue: 184 / 255)),
        (6, 4, Color(red: 61 / 255, green: 36 / 255, blue: 184 / 255)),
        (7, 4, Color(red: 61 / 255, green: 36 / 255, blue: 184 / 255)),
        (0, 5, Color(red: 66 / 255, green: 85 / 255, blue: 227 / 255)),
        (2, 5, Color(red: 66 / 255, green: 85 / 255, blue: 227 / 255)),
        (3, 5, Color(red: 66 / 255, green: 85 / 255, blue: 227 / 255)),
        (4, 5, Color(red: 66 / 255, green: 85 / 255, blue: 227 / 255)),
        (5, 5, Color(red: 66 / 255, green: 85 / 255, blue: 227 / 255)),
        (7, 5, Color(red: 66 / 255, green: 85 / 255, blue: 227 / 255)),
        (0, 6, Color(red: 71 / 255, green: 142 / 255, blue: 239 / 255)),
        (2, 6, Color(red: 71 / 255, green: 142 / 255, blue: 239 / 255)),
        (5, 6, Color(red: 71 / 255, green: 142 / 255, blue: 239 / 255)),
        (7, 6, Color(red: 71 / 255, green: 142 / 255, blue: 239 / 255)),
        (3, 7, Color(red: 76 / 255, green: 201 / 255, blue: 240 / 255)),
        (4, 7, Color(red: 76 / 255, green: 201 / 255, blue: 240 / 255))
    ]

    private static let ghostPixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (2, 0, Color(red: 1, green: 0, blue: 1)),
        (3, 0, Color(red: 1, green: 0, blue: 1)),
        (4, 0, Color(red: 1, green: 0, blue: 1)),
        (5, 0, Color(red: 1, green: 0, blue: 1)),
        (1, 1, Color(red: 219 / 255, green: 0, blue: 1)),
        (2, 1, Color(red: 219 / 255, green: 0, blue: 1)),
        (3, 1, Color(red: 219 / 255, green: 0, blue: 1)),
        (4, 1, Color(red: 219 / 255, green: 0, blue: 1)),
        (5, 1, Color(red: 219 / 255, green: 0, blue: 1)),
        (6, 1, Color(red: 219 / 255, green: 0, blue: 1)),
        (0, 2, Color(red: 182 / 255, green: 0, blue: 1)),
        (1, 2, Color(red: 182 / 255, green: 0, blue: 1)),
        (3, 2, Color(red: 182 / 255, green: 0, blue: 1)),
        (4, 2, Color(red: 182 / 255, green: 0, blue: 1)),
        (6, 2, Color(red: 182 / 255, green: 0, blue: 1)),
        (7, 2, Color(red: 182 / 255, green: 0, blue: 1)),
        (0, 3, Color(red: 146 / 255, green: 0, blue: 1)),
        (1, 3, Color(red: 146 / 255, green: 0, blue: 1)),
        (2, 3, Color(red: 146 / 255, green: 0, blue: 1)),
        (3, 3, Color(red: 146 / 255, green: 0, blue: 1)),
        (4, 3, Color(red: 146 / 255, green: 0, blue: 1)),
        (5, 3, Color(red: 146 / 255, green: 0, blue: 1)),
        (6, 3, Color(red: 146 / 255, green: 0, blue: 1)),
        (7, 3, Color(red: 146 / 255, green: 0, blue: 1)),
        (0, 4, Color(red: 110 / 255, green: 36 / 255, blue: 1)),
        (1, 4, Color(red: 110 / 255, green: 36 / 255, blue: 1)),
        (2, 4, Color(red: 110 / 255, green: 36 / 255, blue: 1)),
        (3, 4, Color(red: 110 / 255, green: 36 / 255, blue: 1)),
        (4, 4, Color(red: 110 / 255, green: 36 / 255, blue: 1)),
        (5, 4, Color(red: 110 / 255, green: 36 / 255, blue: 1)),
        (6, 4, Color(red: 110 / 255, green: 36 / 255, blue: 1)),
        (7, 4, Color(red: 110 / 255, green: 36 / 255, blue: 1)),
        (0, 5, Color(red: 73 / 255, green: 109 / 255, blue: 1)),
        (1, 5, Color(red: 73 / 255, green: 109 / 255, blue: 1)),
        (2, 5, Color(red: 73 / 255, green: 109 / 255, blue: 1)),
        (3, 5, Color(red: 73 / 255, green: 109 / 255, blue: 1)),
        (4, 5, Color(red: 73 / 255, green: 109 / 255, blue: 1)),
        (5, 5, Color(red: 73 / 255, green: 109 / 255, blue: 1)),
        (6, 5, Color(red: 73 / 255, green: 109 / 255, blue: 1)),
        (7, 5, Color(red: 73 / 255, green: 109 / 255, blue: 1)),
        (0, 6, Color(red: 37 / 255, green: 182 / 255, blue: 1)),
        (1, 6, Color(red: 37 / 255, green: 182 / 255, blue: 1)),
        (2, 6, Color(red: 37 / 255, green: 182 / 255, blue: 1)),
        (3, 6, Color(red: 37 / 255, green: 182 / 255, blue: 1)),
        (4, 6, Color(red: 37 / 255, green: 182 / 255, blue: 1)),
        (5, 6, Color(red: 37 / 255, green: 182 / 255, blue: 1)),
        (6, 6, Color(red: 37 / 255, green: 182 / 255, blue: 1)),
        (7, 6, Color(red: 37 / 255, green: 182 / 255, blue: 1)),
        (0, 7, Color(red: 0, green: 1, blue: 1)),
        (2, 7, Color(red: 0, green: 1, blue: 1)),
        (5, 7, Color(red: 0, green: 1, blue: 1)),
        (7, 7, Color(red: 0, green: 1, blue: 1)),
    ]

    private static let coffeePixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (3, 0, Color(red: 1, green: 0, blue: 0)),
        (2, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (3, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (0, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (1, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (2, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (3, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (4, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (5, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (0, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (1, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (2, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (3, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (4, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (5, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (6, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (0, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (1, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (2, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (3, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (4, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (5, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (6, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (1, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (2, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (3, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (4, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (5, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (2, 7, Color(red: 1, green: 1, blue: 0)),
        (3, 7, Color(red: 1, green: 1, blue: 0)),
        (4, 7, Color(red: 1, green: 1, blue: 0)),
    ]

    private static let alienPixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (2, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (3, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (4, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (5, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (1, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (2, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (3, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (4, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (5, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (6, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (0, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (1, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (3, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (4, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (6, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (7, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (0, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (1, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (2, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (3, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (4, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (5, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (6, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (7, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (1, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (2, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (3, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (4, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (5, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (6, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (2, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (5, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (1, 6, Color(red: 182 / 255, green: 39 / 255, blue: 1)),
        (6, 6, Color(red: 182 / 255, green: 39 / 255, blue: 1)),
        (0, 7, Color(red: 1, green: 0, blue: 1)),
        (7, 7, Color(red: 1, green: 0, blue: 1)),
    ]

    private static let dinoPixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (4, 0, Color(red: 0, green: 1, blue: 136 / 255)),
        (5, 0, Color(red: 0, green: 1, blue: 136 / 255)),
        (6, 0, Color(red: 0, green: 1, blue: 136 / 255)),
        (7, 0, Color(red: 0, green: 1, blue: 136 / 255)),
        (4, 1, Color(red: 0, green: 231 / 255, blue: 97 / 255)),
        (6, 1, Color(red: 0, green: 231 / 255, blue: 97 / 255)),
        (7, 1, Color(red: 0, green: 231 / 255, blue: 97 / 255)),
        (4, 2, Color(red: 0, green: 206 / 255, blue: 58 / 255)),
        (5, 2, Color(red: 0, green: 206 / 255, blue: 58 / 255)),
        (6, 2, Color(red: 0, green: 206 / 255, blue: 58 / 255)),
        (7, 2, Color(red: 0, green: 206 / 255, blue: 58 / 255)),
        (4, 3, Color(red: 0, green: 182 / 255, blue: 19 / 255)),
        (5, 3, Color(red: 0, green: 182 / 255, blue: 19 / 255)),
        (0, 4, Color(red: 0, green: 158 / 255, blue: 0)),
        (3, 4, Color(red: 0, green: 158 / 255, blue: 0)),
        (4, 4, Color(red: 0, green: 158 / 255, blue: 0)),
        (5, 4, Color(red: 0, green: 158 / 255, blue: 0)),
        (0, 5, Color(red: 0, green: 134 / 255, blue: 0)),
        (1, 5, Color(red: 0, green: 134 / 255, blue: 0)),
        (2, 5, Color(red: 0, green: 134 / 255, blue: 0)),
        (3, 5, Color(red: 0, green: 134 / 255, blue: 0)),
        (4, 5, Color(red: 0, green: 134 / 255, blue: 0)),
        (5, 5, Color(red: 0, green: 134 / 255, blue: 0)),
        (1, 6, Color(red: 0, green: 109 / 255, blue: 0)),
        (2, 6, Color(red: 0, green: 109 / 255, blue: 0)),
        (3, 6, Color(red: 0, green: 109 / 255, blue: 0)),
        (4, 6, Color(red: 0, green: 109 / 255, blue: 0)),
        (5, 6, Color(red: 0, green: 109 / 255, blue: 0)),
        (2, 7, Color(red: 0, green: 85 / 255, blue: 0)),
        (5, 7, Color(red: 0, green: 85 / 255, blue: 0)),
    ]

    private static let gamepadPixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (1, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (2, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (3, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (4, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (5, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (6, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (0, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (1, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (2, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (3, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (4, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (5, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (6, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (7, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (0, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (1, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (3, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (4, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (6, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (7, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (0, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (1, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (2, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (3, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (4, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (5, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (6, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (7, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (0, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (1, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (2, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (3, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (4, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (5, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (6, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (7, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (1, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (2, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (5, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (6, 6, Color(red: 1, green: 221 / 255, blue: 0)),
    ]

    private static let skullPixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (2, 0, Color(red: 1, green: 1, blue: 1)),
        (3, 0, Color(red: 1, green: 1, blue: 1)),
        (4, 0, Color(red: 1, green: 1, blue: 1)),
        (5, 0, Color(red: 1, green: 1, blue: 1)),
        (1, 1, Color(red: 231 / 255, green: 231 / 255, blue: 231 / 255)),
        (2, 1, Color(red: 231 / 255, green: 231 / 255, blue: 231 / 255)),
        (3, 1, Color(red: 231 / 255, green: 231 / 255, blue: 231 / 255)),
        (4, 1, Color(red: 231 / 255, green: 231 / 255, blue: 231 / 255)),
        (5, 1, Color(red: 231 / 255, green: 231 / 255, blue: 231 / 255)),
        (6, 1, Color(red: 231 / 255, green: 231 / 255, blue: 231 / 255)),
        (0, 2, Color(red: 206 / 255, green: 206 / 255, blue: 206 / 255)),
        (1, 2, Color(red: 206 / 255, green: 206 / 255, blue: 206 / 255)),
        (3, 2, Color(red: 206 / 255, green: 206 / 255, blue: 206 / 255)),
        (4, 2, Color(red: 206 / 255, green: 206 / 255, blue: 206 / 255)),
        (6, 2, Color(red: 206 / 255, green: 206 / 255, blue: 206 / 255)),
        (7, 2, Color(red: 206 / 255, green: 206 / 255, blue: 206 / 255)),
        (0, 3, Color(red: 182 / 255, green: 182 / 255, blue: 182 / 255)),
        (1, 3, Color(red: 182 / 255, green: 182 / 255, blue: 182 / 255)),
        (2, 3, Color(red: 182 / 255, green: 182 / 255, blue: 182 / 255)),
        (3, 3, Color(red: 182 / 255, green: 182 / 255, blue: 182 / 255)),
        (4, 3, Color(red: 182 / 255, green: 182 / 255, blue: 182 / 255)),
        (5, 3, Color(red: 182 / 255, green: 182 / 255, blue: 182 / 255)),
        (6, 3, Color(red: 182 / 255, green: 182 / 255, blue: 182 / 255)),
        (7, 3, Color(red: 182 / 255, green: 182 / 255, blue: 182 / 255)),
        (0, 4, Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)),
        (1, 4, Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)),
        (2, 4, Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)),
        (3, 4, Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)),
        (4, 4, Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)),
        (5, 4, Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)),
        (6, 4, Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)),
        (7, 4, Color(red: 158 / 255, green: 158 / 255, blue: 158 / 255)),
        (1, 5, Color(red: 134 / 255, green: 134 / 255, blue: 134 / 255)),
        (2, 5, Color(red: 134 / 255, green: 134 / 255, blue: 134 / 255)),
        (3, 5, Color(red: 134 / 255, green: 134 / 255, blue: 134 / 255)),
        (4, 5, Color(red: 134 / 255, green: 134 / 255, blue: 134 / 255)),
        (5, 5, Color(red: 134 / 255, green: 134 / 255, blue: 134 / 255)),
        (6, 5, Color(red: 134 / 255, green: 134 / 255, blue: 134 / 255)),
        (2, 6, Color(red: 109 / 255, green: 109 / 255, blue: 109 / 255)),
        (5, 6, Color(red: 109 / 255, green: 109 / 255, blue: 109 / 255)),
        (2, 7, Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255)),
        (3, 7, Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255)),
        (4, 7, Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255)),
        (5, 7, Color(red: 85 / 255, green: 85 / 255, blue: 85 / 255)),
    ]

    private static let phoenixPixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (0, 0, Color(red: 1, green: 0, blue: 0)),
        (3, 0, Color(red: 1, green: 0, blue: 0)),
        (4, 0, Color(red: 1, green: 0, blue: 0)),
        (7, 0, Color(red: 1, green: 0, blue: 0)),
        (0, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (1, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (3, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (4, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (6, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (7, 1, Color(red: 1, green: 39 / 255, blue: 0)),
        (1, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (2, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (3, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (4, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (5, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (6, 2, Color(red: 1, green: 78 / 255, blue: 0)),
        (2, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (3, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (4, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (5, 3, Color(red: 1, green: 117 / 255, blue: 0)),
        (1, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (2, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (3, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (4, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (5, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (6, 4, Color(red: 1, green: 153 / 255, blue: 0)),
        (0, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (1, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (3, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (4, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (6, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (7, 5, Color(red: 1, green: 187 / 255, blue: 0)),
        (0, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (3, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (4, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (7, 6, Color(red: 1, green: 221 / 255, blue: 0)),
        (2, 7, Color(red: 1, green: 1, blue: 0)),
        (5, 7, Color(red: 1, green: 1, blue: 0)),
    ]

    private static let ufoBeamPixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (3, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (4, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (2, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (3, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (4, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (5, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (1, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (2, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (3, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (4, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (5, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (6, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (0, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (1, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (2, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (3, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (4, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (5, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (6, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (7, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (1, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (3, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (4, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (6, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (2, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (5, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (1, 6, Color(red: 182 / 255, green: 39 / 255, blue: 1)),
        (6, 6, Color(red: 182 / 255, green: 39 / 255, blue: 1)),
        (0, 7, Color(red: 1, green: 0, blue: 1)),
        (7, 7, Color(red: 1, green: 0, blue: 1)),
    ]

    private static let robotPixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (2, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (3, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (4, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (5, 0, Color(red: 0, green: 1, blue: 204 / 255)),
        (1, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (2, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (3, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (4, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (5, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (6, 1, Color(red: 0, green: 221 / 255, blue: 219 / 255)),
        (1, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (3, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (4, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (6, 2, Color(red: 0, green: 187 / 255, blue: 233 / 255)),
        (1, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (2, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (3, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (4, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (5, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (6, 3, Color(red: 0, green: 153 / 255, blue: 248 / 255)),
        (2, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (3, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (4, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (5, 4, Color(red: 36 / 255, green: 117 / 255, blue: 1)),
        (1, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (2, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (3, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (4, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (5, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (6, 5, Color(red: 109 / 255, green: 78 / 255, blue: 1)),
        (1, 6, Color(red: 182 / 255, green: 39 / 255, blue: 1)),
        (3, 6, Color(red: 182 / 255, green: 39 / 255, blue: 1)),
        (4, 6, Color(red: 182 / 255, green: 39 / 255, blue: 1)),
        (6, 6, Color(red: 182 / 255, green: 39 / 255, blue: 1)),
        (1, 7, Color(red: 1, green: 0, blue: 1)),
        (3, 7, Color(red: 1, green: 0, blue: 1)),
        (4, 7, Color(red: 1, green: 0, blue: 1)),
        (6, 7, Color(red: 1, green: 0, blue: 1)),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, canvasSize in
                let gridSize: CGFloat = 8
                let step = min(canvasSize.width, canvasSize.height) / gridSize
                let pixelSize = step * 0.88
                let xOffset = (canvasSize.width - gridSize * step) / 2
                let yOffset = (canvasSize.height - gridSize * step) / 2

                for pixel in pixels {
                    let wave = sin((time * 5.2) + Double(pixel.x * 0.9) + Double(pixel.y * 0.75))
                    let lift = animate ? CGFloat(wave) * step * 0.10 : 0
                    let opacity = animate ? (0.78 + CGFloat(wave) * 0.22) : 1

                    let rect = CGRect(
                        x: xOffset + (pixel.x * step) + (step - pixelSize) / 2,
                        y: yOffset + (pixel.y * step) + (step - pixelSize) / 2 - lift,
                        width: pixelSize,
                        height: pixelSize
                    )

                    context.opacity = opacity
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: max(1.5, pixelSize * 0.22)),
                        with: .color(pixel.color)
                    )
                    context.opacity = 1
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct ClaudeCrabIcon: View {
    let size: CGFloat
    let color: Color
    var animateLegs: Bool = false

    @State private var legPhase: Int = 0

    // Timer for leg animation
    private let legTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    init(size: CGFloat = 16, color: Color = Color(red: 0.85, green: 0.47, blue: 0.34), animateLegs: Bool = false) {
        self.size = size
        self.color = color
        self.animateLegs = animateLegs
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 52.0  // Original viewBox height is 52
            let xOffset = (canvasSize.width - 66 * scale) / 2

            // Left antenna
            let leftAntenna = Path { p in
                p.addRect(CGRect(x: 0, y: 13, width: 6, height: 13))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(leftAntenna, with: .color(color))

            // Right antenna
            let rightAntenna = Path { p in
                p.addRect(CGRect(x: 60, y: 13, width: 6, height: 13))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(rightAntenna, with: .color(color))

            // Animated legs - alternating up/down pattern for walking effect
            // Legs stay attached to body (y=39), only height changes
            let baseLegPositions: [CGFloat] = [6, 18, 42, 54]
            let baseLegHeight: CGFloat = 13

            // Height offsets: positive = longer leg (down), negative = shorter leg (up)
            let legHeightOffsets: [[CGFloat]] = [
                [3, -3, 3, -3],   // Phase 0: alternating
                [0, 0, 0, 0],     // Phase 1: neutral
                [-3, 3, -3, 3],   // Phase 2: alternating (opposite)
                [0, 0, 0, 0],     // Phase 3: neutral
            ]

            let currentHeightOffsets = animateLegs ? legHeightOffsets[legPhase % 4] : [CGFloat](repeating: 0, count: 4)

            for (index, xPos) in baseLegPositions.enumerated() {
                let heightOffset = currentHeightOffsets[index]
                let legHeight = baseLegHeight + heightOffset
                let leg = Path { p in
                    p.addRect(CGRect(x: xPos, y: 39, width: 6, height: legHeight))
                }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
                context.fill(leg, with: .color(color))
            }

            // Main body
            let body = Path { p in
                p.addRect(CGRect(x: 6, y: 0, width: 54, height: 39))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(body, with: .color(color))

            // Left eye
            let leftEye = Path { p in
                p.addRect(CGRect(x: 12, y: 13, width: 6, height: 6.5))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(leftEye, with: .color(.black))

            // Right eye
            let rightEye = Path { p in
                p.addRect(CGRect(x: 48, y: 13, width: 6, height: 6.5))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(rightEye, with: .color(.black))
        }
        .frame(width: size * (66.0 / 52.0), height: size)
        .onReceive(legTimer) { _ in
            if animateLegs {
                legPhase = (legPhase + 1) % 4
            }
        }
    }
}

// Pixel art permission indicator icon
struct PermissionIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = Color(red: 0.11, green: 0.12, blue: 0.13)) {
        self.size = size
        self.color = color
    }

    // Visible pixel positions from the SVG (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (7, 7), (7, 11),           // Left column
        (11, 3),                    // Top left
        (15, 3), (15, 19), (15, 27), // Center column
        (19, 3), (19, 15),          // Right of center
        (23, 7), (23, 11)           // Right column
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// Pixel art "ready for input" indicator icon (checkmark/done shape)
struct ReadyForInputIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = TerminalColors.green) {
        self.size = size
        self.color = color
    }

    // Checkmark shape pixel positions (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (5, 15),                    // Start of checkmark
        (9, 19),                    // Down stroke
        (13, 23),                   // Bottom of checkmark
        (17, 19),                   // Up stroke begins
        (21, 15),                   // Up stroke
        (25, 11),                   // Up stroke
        (29, 7)                     // End of checkmark
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}
