//
//  ObjectInfoOverlayFramingState.swift
//  MetalModule
//
//  Created by Codex on 31.05.2026.
//

import CoreGraphics

@MainActor
final class ObjectInfoOverlayFramingState {
    struct ProjectionAdjustment: Equatable {
        let verticalFieldOfView: Float
        let verticalCenterOffset: Float

        static let identity = ProjectionAdjustment(
            verticalFieldOfView: CameraFit.verticalFieldOfView,
            verticalCenterOffset: 0
        )
    }

    private enum Constants {
        static let transitionDuration: Float = 0.36
        static let verticalOffsetScale: Float = 0.70
        static let maximumVerticalOffset: Float = 0.30
        static let fieldOfViewScale: Float = 0.20
        static let maximumFieldOfViewIncrease: Float = 0.10
        static let maximumBottomCoverage: Float = 0.75
    }

    private var targetProgress: Float = 0
    private var currentProgress: Float = 0
    private var bottomCoverage: Float = 0

    func setPresentation(isPresented: Bool,
                         bottomInset: CGFloat,
                         viewportHeight: CGFloat) {
        targetProgress = isPresented ? 1 : 0

        guard isPresented else { return }
        guard viewportHeight > 0,
              bottomInset.isFinite,
              viewportHeight.isFinite else {
            bottomCoverage = 0
            return
        }

        bottomCoverage = min(max(Float(bottomInset / viewportHeight), 0),
                             Constants.maximumBottomCoverage)
    }

    func advance(delta: Float) -> ProjectionAdjustment {
        let step = max(delta, 0) / Constants.transitionDuration
        if currentProgress < targetProgress {
            currentProgress = min(currentProgress + step, targetProgress)
        } else if currentProgress > targetProgress {
            currentProgress = max(currentProgress - step, targetProgress)
        }

        if currentProgress == 0,
           targetProgress == 0 {
            bottomCoverage = 0
            return .identity
        }

        let easedProgress = smoothstep(currentProgress)
        let activeCoverage = bottomCoverage * easedProgress
        let verticalCenterOffset = -min(activeCoverage * Constants.verticalOffsetScale,
                                        Constants.maximumVerticalOffset)
        let fieldOfViewIncrease = min(activeCoverage * Constants.fieldOfViewScale,
                                      Constants.maximumFieldOfViewIncrease)

        return ProjectionAdjustment(
            verticalFieldOfView: CameraFit.verticalFieldOfView * (1 + fieldOfViewIncrease),
            verticalCenterOffset: verticalCenterOffset
        )
    }

    private func smoothstep(_ value: Float) -> Float {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - 2 * clampedValue)
    }
}
