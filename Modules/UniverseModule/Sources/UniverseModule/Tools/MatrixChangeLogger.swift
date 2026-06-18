//
//  MatrixChangeLogger.swift
//  UniverseModule
//
//  Created by max on 03.05.2026.
//

import simd
import os
import Foundation

final class MatrixChangeLogger: @unchecked Sendable {
    private struct PendingChange {
        let previous: float4x4
        let current: float4x4
    }

    private let logger: Logger
    private let caption: String
    private let level: OSLogType
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var pendingChange: PendingChange?
    private var isDrainScheduled = false

    init(logger: Logger, caption: String,
         level: OSLogType = .debug,
         queueLabel: String) {
        self.logger = logger
        self.caption = caption
        self.level = level
        queue = DispatchQueue(label: queueLabel, qos: .utility)
    }

    func logChange(from previous: float4x4, to current: float4x4) {
        lock.withLock {
            pendingChange = PendingChange(previous: previous, current: current)
            guard !isDrainScheduled else { return }

            isDrainScheduled = true
            queue.async { [self] in
                drain()
            }
        }
    }

    private func drain() {
        while let change = nextChange() {
            logger.logMatricies(matrix1: change.previous,
                                matrix2: change.current,
                                caption: caption,
                                level: level)
        }
    }

    private func nextChange() -> PendingChange? {
        lock.withLock {
            guard let change = pendingChange else {
                isDrainScheduled = false
                return nil
            }

            pendingChange = nil
            return change
        }
    }
}
