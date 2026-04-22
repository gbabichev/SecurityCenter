//
//  QuietHoursSaverView.swift
//  Security Cameras
//
//  Created by Codex on 4/22/26.
//

import SwiftUI

struct QuietHoursSaverView: View {
    let endLabel: String
    @State private var positionIndex = 0

    private let positions: [UnitPoint] = [
        .topLeading,
        .top,
        .topTrailing,
        .leading,
        .center,
        .trailing,
        .bottomLeading,
        .bottom,
        .bottomTrailing
    ]

    var body: some View {
        GeometryReader { proxy in
            let anchor = positions[positionIndex % positions.count]

            ZStack {
                Color.black
                    .ignoresSafeArea()

                saverCard
                    .frame(maxWidth: 420)
                    .padding(36)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: alignment(for: anchor)
                    )
                    .animation(.easeInOut(duration: 1.8), value: positionIndex)
            }
        }
        .task {
            guard positions.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                await MainActor.run {
                    positionIndex = (positionIndex + 1) % positions.count
                }
            }
        }
    }

    private var saverCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "moon.fill")
                .font(.system(size: 34))
            Text("Quiet Hours")
                .font(.title3.weight(.semibold))
            Text("Screen is blacked out and camera traffic is paused until \(endLabel).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func alignment(for point: UnitPoint) -> Alignment {
        switch point {
        case .topLeading:
            return .topLeading
        case .top:
            return .top
        case .topTrailing:
            return .topTrailing
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        case .bottomLeading:
            return .bottomLeading
        case .bottom:
            return .bottom
        case .bottomTrailing:
            return .bottomTrailing
        default:
            return .center
        }
    }
}
