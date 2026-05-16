//
//  LoadingScreenView.swift
//  OptiUniverse
//
//  Created by Codex on 06.05.2026.
//

import SwiftUI

struct LoadingScreenView: View {

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            GeometryReader { geometry in
                ZStack {
                    LoadingSpaceBackground(date: timeline.date)
                    LoadingIndicator(date: timeline.date,
                                     screenSize: geometry.size)
                }
                .frame(width: geometry.size.width,
                       height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading")
    }
}

private struct LoadingSpaceBackground: View {

    let date: Date

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.loadingBackgroundTop,
                         .loadingBackgroundUpper,
                         .loadingBackgroundLower,
                         .loadingBackgroundBottom],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            RadialGradient(
                colors: [
                    .loadingGlowPrimary,
                    .clear
                ],
                center: UnitPoint(x: 0.12, y: 0.42),
                startRadius: 24,
                endRadius: 390
            )

            RadialGradient(
                colors: [
                    .loadingGlowSecondary,
                    .clear
                ],
                center: UnitPoint(x: 0.86, y: 0.66),
                startRadius: 18,
                endRadius: 360
            )

            StarFieldCanvas(date: date)
                .blendMode(.screen)
        }
    }
}

private struct StarFieldCanvas: View {

    let date: Date

    private static let stars: [LoadingStar] = LoadingStar.makeStars(count: 105)

    var body: some View {
        Canvas { context, size in
            let seconds = date.timeIntervalSinceReferenceDate

            for star in Self.stars {
                let drift = CGFloat((seconds * star.driftSpeed).truncatingRemainder(dividingBy: 1.0))
                let starX = star.positionX * size.width
                let starY = (star.positionY + drift).truncatingRemainder(dividingBy: 1.0) * size.height
                let twinkle = 0.62 + 0.38 * sin(seconds * star.twinkleSpeed + star.phase)
                let opacity = max(0.0, min(1.0, star.opacity * twinkle))

                let rect = CGRect(
                    x: starX - star.width / 2,
                    y: starY - star.height / 2,
                    width: star.width,
                    height: star.height
                )
                let path = Path(roundedRect: rect,
                                cornerRadius: min(star.width, star.height) / 2)

                context.fill(path, with: .color(star.color.opacity(opacity)))

                if star.glow > 0 {
                    let glowRect = rect.insetBy(dx: -star.glow, dy: -star.glow)
                    let glowPath = Path(ellipseIn: glowRect)
                    context.fill(glowPath, with: .color(star.color.opacity(opacity * 0.22)))
                }
            }
        }
    }
}

private struct LoadingIndicator: View {

    let date: Date
    let screenSize: CGSize

    private var seconds: Double {
        date.timeIntervalSinceReferenceDate
    }

    private var ringRotation: Angle {
        .degrees(seconds * 116.0)
    }

    private var indicatorSize: CGFloat {
        min(max(min(screenSize.width, screenSize.height) * 0.22, 88), 118)
    }

    var body: some View {
        VStack(spacing: 24) {
            RotatingLoadingRing(seconds: seconds,
                                rotation: ringRotation)
                .frame(width: indicatorSize, height: indicatorSize)

            PulsingDots(seconds: seconds)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RotatingLoadingRing: View {

    let seconds: Double
    let rotation: Angle

    private var sectorLength: CGFloat {
        let wave = (sin(seconds * 1.45) + 1.0) / 2.0
        let eased = wave * wave * (3.0 - 2.0 * wave)
        return CGFloat(0.17 + eased * 0.163)
    }

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let start = CGFloat(index) / 3.0
                let end = min(start + sectorLength, 1.0)

                Circle()
                    .trim(from: start, to: end)
                    .stroke(
                        AngularGradient(
                            colors: [
                                .loadingRingPink,
                                .loadingRingBlue,
                                .loadingRingCyan,
                                .loadingRingPurple,
                                .loadingRingPink
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 7,
                                           lineCap: .butt)
                    )
            }
        }
        .rotationEffect(rotation)
        .shadow(color: .loadingRingShadow,
                radius: 16,
                y: 4)
    }
}

private struct PulsingDots: View {

    let seconds: Double

    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<3, id: \.self) { index in
                let phase = seconds * 2.8 - Double(index) * 0.55
                let scale = 0.82 + 0.22 * (sin(phase) + 1.0) / 2.0
                let opacity = 0.66 + 0.30 * (sin(phase) + 1.0) / 2.0

                Circle()
                    .fill(.loadingDot.opacity(opacity))
                    .frame(width: 22, height: 22)
                    .scaleEffect(scale)
            }
        }
    }
}

private struct LoadingStar {

    let positionX: CGFloat
    let positionY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let opacity: Double
    let phase: Double
    let twinkleSpeed: Double
    let driftSpeed: Double
    let glow: CGFloat
    let color: Color

    static func makeStars(count: Int) -> [LoadingStar] {
        var random = LoadingScreenRandom(seed: 0x5A17_0B71)

        return (0..<count).map { index in
            let bright = random.next()
            let elongated = random.next() > 0.68
            let largeGlow = random.next() > 0.88
            let baseSize = CGFloat(1.4 + random.next() * 4.4)
            let width = elongated ? baseSize * CGFloat(1.8 + random.next() * 1.7) : baseSize
            let height = elongated ? max(1.6, baseSize * CGFloat(0.40 + random.next() * 0.25)) : baseSize
            let verticalPosition = Double(index) / Double(count) + random.next() * 0.22

            return LoadingStar(
                positionX: CGFloat(random.next()),
                positionY: CGFloat(verticalPosition.truncatingRemainder(dividingBy: 1.0)),
                width: width,
                height: height,
                opacity: 0.28 + bright * 0.62,
                phase: random.next() * .pi * 2.0,
                twinkleSpeed: 0.65 + random.next() * 1.8,
                driftSpeed: 0.006 + random.next() * 0.018,
                glow: largeGlow ? CGFloat(6.0 + random.next() * 7.0) : 0,
                color: starColor(random.next())
            )
        }
    }

    private static func starColor(_ value: Double) -> Color {
        switch value {
        case 0..<0.18:
            .loadingStarPurple
        case 0..<0.34:
            .loadingStarMuted
        case 0..<0.48:
            .loadingStarBlue
        default:
            .loadingStarWhite
        }
    }
}

private struct LoadingScreenRandom {

    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / 9_007_199_254_740_992.0
    }
}

#Preview {
    LoadingScreenView()
}
