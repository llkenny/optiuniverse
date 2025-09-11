import Foundation
import Metal
import QuartzCore
import Darwin

/// Determines whether the application was launched in QA mode.
struct QALaunch {
    /// Flag indicating if `-QA` was passed as a launch argument.
    static let enabled: Bool = ProcessInfo.processInfo.arguments.contains("-QA")
}

/// Collects memory usage samples for the running process.
final class QAMemory {
    private(set) var samples: [UInt64] = []

    /// Takes a memory usage sample and stores it in `samples`.
    func sample() {
        samples.append(Self.currentUsage())
    }

    /// Returns the current resident memory size of the process.
    private static func currentUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
    }
}

/// Gathers frame, GPU and memory metrics during rendering.
final class QAMetrics {
    private var frameTimes: [Double] = []
    private var gpuTimes: [Double] = []
    private var lastFrameTimestamp: CFTimeInterval?
    private let memory = QAMemory()

    /// Should be called once per frame with the active command buffer.
    func tick(commandBuffer: MTLCommandBuffer) {
        let now = CACurrentMediaTime()
        if let last = lastFrameTimestamp {
            frameTimes.append(now - last)
        }
        lastFrameTimestamp = now

        memory.sample()

        let start = now
        commandBuffer.addCompletedHandler { [weak self] _ in
            let end = CACurrentMediaTime()
            let ms = (end - start) * 1000
            self?.gpuTimes.append(ms)
        }
    }

    /// Records a standalone memory sample.
    func sampleMemory() {
        memory.sample()
    }

    /// Creates a dictionary suitable for JSON serialization of collected metrics.
    func exportJSON() -> [String: Any] {
        let fps: Double
        if frameTimes.isEmpty {
            fps = 0
        } else {
            let avg = frameTimes.reduce(0, +) / Double(frameTimes.count)
            fps = avg > 0 ? 1.0 / avg : 0
        }
        let sortedGPU = gpuTimes.sorted()
        func percentile(_ p: Double) -> Double {
            guard !sortedGPU.isEmpty else { return 0 }
            let pos = (Double(sortedGPU.count - 1)) * p
            return sortedGPU[Int(pos.rounded(.towardZero))]
        }
        return [
            "fps": fps,
            "gpu_ms_p50": percentile(0.50),
            "gpu_ms_p95": percentile(0.95),
            "mem_samples": memory.samples
        ]
    }
}

/// Public hooks for QA metrics collection and exporting.
enum QAHooks {
    private static let metrics = QAMetrics()

    /// Called from the render loop every frame to gather metrics.
    static func tick(commandBuffer: MTLCommandBuffer) {
        guard QALaunch.enabled else { return }
        metrics.tick(commandBuffer: commandBuffer)
    }

    /// Records a manual memory sample.
    static func sampleMemory() {
        guard QALaunch.enabled else { return }
        metrics.sampleMemory()
    }

    /// Writes collected metrics to a JSON file in the temporary directory.
    static func export() {
        guard QALaunch.enabled else { return }
        let json = metrics.exportJSON()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("qa_metrics.json")
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            try data.write(to: url)
            print("QA metrics exported to \(url.path)")
        } catch {
            print("Failed to export QA metrics: \(error)")
        }
    }

    /// Exports stability metrics to a separate JSON file.
    static func exportStability() {
        guard QALaunch.enabled else { return }
        let json = metrics.exportJSON()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("qa_stability.json")
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
            try data.write(to: url)
            print("QA stability exported to \(url.path)")
        } catch {
            print("Failed to export QA stability: \(error)")
        }
    }
}

