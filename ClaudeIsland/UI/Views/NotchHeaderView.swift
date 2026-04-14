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

    var body: some View {
        Group {
            if prefersClaudeTheme || source == .claude {
                ClaudeCrabIcon(size: size, color: SessionSource.claude.accentColor, animateLegs: animate)
            } else {
                MultiCliPixelIcon(size: size, animate: animate)
            }
        }
    }
}

struct MultiCliPixelIcon: View {
    let size: CGFloat
    var animate: Bool = false

    // Coordinates in an 8x8 grid mapped from the provided 142x142 SVG.
    private let pixels: [(x: CGFloat, y: CGFloat, color: Color)] = [
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
