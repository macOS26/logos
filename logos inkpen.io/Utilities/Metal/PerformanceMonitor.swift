import SwiftUI
import Combine

class PerformanceMonitor: ObservableObject {

    @Published var fps: Double = 0.0
    @Published var frameTime: Double = 0.0
    @Published var renderingMode: String = "Unknown"
    @Published var metalDeviceName: String = "None"
    @Published var memoryUsage: Double = 0.0
    @Published var drawCallCount: Int = 0
    @Published var vertexCount: Int = 0

    private var frameStartTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFTimeInterval = 0
    private var frameTimeHistory: [Double] = []
    private let maxHistorySize = 60

    private var metalDevice: MTLDevice?
    private var commandBufferStartTime: CFTimeInterval = 0

    init() {
        setupMetalTracking()
        startPerformanceTracking()
    }

    private func setupMetalTracking() {
        if let device = MTLCreateSystemDefaultDevice() {
            self.metalDevice = device
            self.metalDeviceName = device.name
            self.renderingMode = "Metal GPU"
        } else {
            self.renderingMode = "Core Graphics CPU"
        }
    }

    private func startPerformanceTracking() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.updateMemoryUsage()
        }
    }

    func frameDidStart() {
        frameStartTime = CACurrentMediaTime()
        frameCount += 1
    }

    func frameDidEnd() {
        let frameEndTime = CACurrentMediaTime()
        let currentFrameTime = (frameEndTime - frameStartTime) * 1000.0

        DispatchQueue.main.async {
            self.frameTime = currentFrameTime
        }

        frameTimeHistory.append(currentFrameTime)
        if frameTimeHistory.count > maxHistorySize {
            frameTimeHistory.removeFirst()
        }

        if frameEndTime - lastFPSUpdate >= 0.5 {
            let fps = Double(frameCount) / (frameEndTime - lastFPSUpdate)
            DispatchQueue.main.async {
                self.fps = fps
            }
            frameCount = 0
            lastFPSUpdate = frameEndTime
        }
    }

    func metalCommandDidStart() {
        commandBufferStartTime = CACurrentMediaTime()
    }

    func metalCommandDidEnd() {
        DispatchQueue.main.async {
        }
    }

    func recordDrawCall(vertexCount: Int = 0) {
        DispatchQueue.main.async {
            self.drawCallCount += 1
            self.vertexCount += vertexCount
        }
    }

    func resetDrawingStats() {
        DispatchQueue.main.async {
            self.drawCallCount = 0
            self.vertexCount = 0
        }
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Double(info.resident_size) / (1024.0 * 1024.0)
            DispatchQueue.main.async {
                self.memoryUsage = memoryUsageMB
            }
        }
    }

    var averageFrameTime: Double {
        guard !frameTimeHistory.isEmpty else { return 0.0 }
        return frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
    }

    var isPerformingWell: Bool {
        return fps >= 30.0 && frameTime <= 33.33
    }

    var performanceGrade: String {
        switch fps {
        case 60...: return "Excellent"
        case 30..<60: return "Good"
        case 15..<30: return "Fair"
        default: return "Poor"
        }
    }

    var performanceGradeColor: Color {
        switch performanceGrade {
        case "Excellent": return .green
        case "Good": return .green
        case "Fair": return .orange
        case "Poor": return .red
        default: return .green
        }
    }
}

private struct mach_task_basic_info {
    var virtual_size: mach_vm_size_t = 0
    var resident_size: mach_vm_size_t = 0
    var resident_size_max: mach_vm_size_t = 0
    var user_time: time_value_t = time_value_t()
    var system_time: time_value_t = time_value_t()
    var policy: policy_t = 0
    var suspend_count: integer_t = 0
}
