//
//  ProcessingSpinner.swift
//  ClaudeIsland
//
//  Animated symbol spinner for processing state
//

import Combine
import SwiftUI

struct ProcessingSpinner: View {
    let source: SessionSource
    @State private var phase: Int = 0

    private let symbols = ["·", "✢", "✳", "∗", "✻", "✽"]

    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    init(source: SessionSource = .claude) {
        self.source = source
    }

    var body: some View {
        Text(symbols[phase % symbols.count])
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(source.accentColor)
            .frame(width: 12, alignment: .center)
            .onReceive(timer) { _ in
                phase = (phase + 1) % symbols.count
            }
    }
}

#Preview {
    ProcessingSpinner()
        .frame(width: 30, height: 30)
        .background(.black)
}
