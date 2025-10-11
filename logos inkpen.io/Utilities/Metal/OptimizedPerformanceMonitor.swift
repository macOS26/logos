import SwiftUI
import Combine

class OptimizedPerformanceMonitor: ObservableObject {

    static let shared = OptimizedPerformanceMonitor()

    @Published var fps: Double = 0.0
    @Published var frameTime: Double = 0.0
    @Published var renderingMode: String = "Core Graphics CPU"
    @Published var metalDeviceName: String = "None"
    @Published var memoryUsage: Double = 0.0
    @Published var drawCallCount: Int = 0
    @Published var cpuUsage: Double = 0.0

    private var frameCount: Int = 0
    private var lastUpdateTime: CFTimeInterval = 0
    private var isTracking: Bool = false

    private var lastCPUTime: Double = 0
    private var cpuTimer: Timer?
    private var activityCounter: Int = 0
    private var lastActivityTime: CFTimeInterval = 0

    private var activityFrameCount: Int = 0
    private var activityLastFrameTime: CFTimeInterval = 0

    private var previousTotalTicks: UInt32?
    private var previousIdleTicks: UInt32 = 0

    init() {
        setupOptimizedTracking()
    }

    deinit {
        stopTracking()
    }


    private func setupOptimizedTracking() {
        let metalEngine = MetalComputeEngine.shared
        self.metalDeviceName = metalEngine.device.name
        self.renderingMode = metalEngine.getPerformanceMode()

        cpuTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateSystemMetrics()
        }

        lastUpdateTime = CACurrentMediaTime()
        lastActivityTime = CACurrentMediaTime()
        isTracking = true

        DispatchQueue.main.async {
            self.cpuUsage = 0.0
        }
    }

    private func stopTracking() {
        cpuTimer?.invalidate()
        cpuTimer = nil
        isTracking = false
    }


    func trackDrawingEvent(elementCount: Int = 0) {
        guard isTracking else { return }

        frameCount += 1
        drawCallCount = elementCount

        activityCounter += 1
        let currentTime = CACurrentMediaTime()

        if currentTime - lastActivityTime >= 1.0 {
            activityCounter = 0
            lastActivityTime = currentTime
        }

        let timeDelta = currentTime - lastUpdateTime

        if timeDelta >= 1.0 {
            let fps = Double(frameCount) / timeDelta

            DispatchQueue.main.async {
                self.fps = fps
                self.frameTime = timeDelta * 1000.0 / Double(self.frameCount)
            }

            frameCount = 0
            lastUpdateTime = currentTime
        }
    }

    func metalCommandStart() {
        if renderingMode.contains("Metal") {
            trackDrawingEvent()
        }
    }


    private func updateSystemMetrics() {
        updateCPUUsage()

        if cpuUsage == 0.0 && activityCounter > 0 {
            let activityLevel = min(100.0, Double(activityCounter))
            let scaledActivity = activityLevel * 0.3
            if scaledActivity >= 5.0 {
                DispatchQueue.main.async {
                    self.cpuUsage = min(100.0, max(0.0, scaledActivity))
                }
            }
        }

        updateMemoryUsage()
    }

    private func updateCPUUsage() {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let totalTicks = cpuLoad.cpu_ticks.0 + cpuLoad.cpu_ticks.1 + cpuLoad.cpu_ticks.2 + cpuLoad.cpu_ticks.3

            if let previousTotalTicks = previousTotalTicks {
                let totalDelta = Int(totalTicks) - Int(previousTotalTicks)
                let idleDelta = Int(cpuLoad.cpu_ticks.3) - Int(previousIdleTicks)

                if totalDelta > 0 {
                    let cpuUsagePercent = Double(totalDelta - idleDelta) / Double(totalDelta) * 100.0

                    DispatchQueue.main.async {
                        let scaledCPU = cpuUsagePercent * 0.3

                        if scaledCPU < 5.0 {
                            self.cpuUsage = 0.0
                        } else {
                            self.cpuUsage = min(100.0, max(0.0, scaledCPU))
                        }
                    }
                }
            }

            previousTotalTicks = totalTicks
            previousIdleTicks = cpuLoad.cpu_ticks.3
        } else {
            updateCPUUsingLoadAverage()
        }
    }

    private func updateCPUUsingLoadAverage() {
        var loadAvg = [Double](repeating: 0, count: 3)
        let result = getloadavg(&loadAvg, 3)

        if result > 0 {
            let processInfo = ProcessInfo.processInfo
            let cpuLoad = min(100.0, loadAvg[0] * 100.0 / Double(processInfo.processorCount))

            DispatchQueue.main.async {
                if cpuLoad < 5.0 {
                    self.cpuUsage = 0.0
                } else {
                    self.cpuUsage = cpuLoad
                }
            }
        } else {
            updateCPUUsingActivityMonitor()
        }
    }

    private func updateCPUUsingActivityMonitor() {
        let now = CACurrentMediaTime()

        activityFrameCount += 1

        if now - activityLastFrameTime >= 2.0 {
            let estimatedCPU = min(100.0, Double(activityFrameCount) * 2.0)

            DispatchQueue.main.async {
                let scaledCPU = estimatedCPU * 0.3
                if scaledCPU < 5.0 {
                    self.cpuUsage = 0.0
                } else {
                    self.cpuUsage = min(100.0, max(0.0, scaledCPU))
                }
            }

            activityFrameCount = 0
            activityLastFrameTime = now
        }
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kern = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kern == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / (1024.0 * 1024.0)
            DispatchQueue.main.async {
                self.memoryUsage = memoryMB
            }
        }
    }


    var performanceGrade: String {
        if cpuUsage > 80 { return "CPU Overload" }
        if cpuUsage > 60 { return "High CPU" }
        if cpuUsage > 40 { return "Moderate CPU" }
        return "Efficient"
    }

    var cpuStatusColor: Color {
        switch cpuUsage {
        case 0..<30: return .green
        case 30..<60: return .yellow
        case 60..<80: return .orange
        default: return .red
        }
    }

    var performanceGradeColor: Color {
        switch performanceGrade {
        case "Efficient": return .green
        case "Moderate CPU": return .yellow
        case "High CPU": return .orange
        case "CPU Overload": return .red
        default: return .green
        }
    }
}


struct LightweightPerformanceOverlay: View {
    @ObservedObject var monitor: OptimizedPerformanceMonitor
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(monitor.cpuStatusColor)
                    .frame(width: 6, height: 6)

                Text("CPU \(Int(monitor.cpuUsage))%")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.primary)

                if isExpanded {
                    Image(systemName: "chevron.up")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if isExpanded {
                VStack(alignment: .trailing, spacing: 1) {
                    Divider()

                    Text("FPS: \(Int(monitor.fps))")
                        .font(.system(.caption2, design: .monospaced))

                    Text("Memory: \(Int(monitor.memoryUsage))MB")
                        .font(.system(.caption2, design: .monospaced))

                    Text("Mode: \(monitor.renderingMode)")
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)

                    Text("Grade: \(monitor.performanceGrade)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(monitor.performanceGradeColor)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
                .shadow(radius: 1)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}
