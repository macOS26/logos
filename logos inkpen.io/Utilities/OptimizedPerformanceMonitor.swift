import SwiftUI
import Metal
import Foundation

/// Optimized performance monitor that doesn't add CPU overhead
class OptimizedPerformanceMonitor: ObservableObject {
    
    static let shared = OptimizedPerformanceMonitor()
    
    @Published var fps: Double = 0.0
    @Published var frameTime: Double = 0.0
    @Published var renderingMode: String = "Core Graphics CPU"
    @Published var metalDeviceName: String = "None"
    @Published var memoryUsage: Double = 0.0
    @Published var drawCallCount: Int = 0
    @Published var cpuUsage: Double = 0.0
    
    // Efficient tracking without high-frequency timers
    private var frameCount: Int = 0
    private var lastUpdateTime: CFTimeInterval = 0
    private var isTracking: Bool = false
    
    // CPU usage tracking
    private var lastCPUTime: Double = 0
    private var cpuTimer: Timer?
    private var activityCounter: Int = 0
    private var lastActivityTime: CFTimeInterval = 0
    
    // Activity monitor fallback
    private var activityFrameCount: Int = 0
    private var activityLastFrameTime: CFTimeInterval = 0
    
    init() {
        setupOptimizedTracking()
    }
    
    deinit {
        stopTracking()
    }
    
    // MARK: - Optimized Tracking Setup
    
    private func setupOptimizedTracking() {
        if let metalEngine = MetalComputeEngine.shared {
            self.metalDeviceName = metalEngine.device.name
            self.renderingMode = metalEngine.getPerformanceMode()
        } else if let device = MTLCreateSystemDefaultDevice() {
            self.metalDeviceName = device.name
            self.renderingMode = "Metal GPU Available"
        }
        
        // Use low-frequency CPU monitoring (every 2 seconds instead of 60 FPS)
        cpuTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.updateSystemMetrics()
        }
        
        lastUpdateTime = CACurrentMediaTime()
        lastActivityTime = CACurrentMediaTime()
        isTracking = true
        
        // Initialize with baseline CPU
        DispatchQueue.main.async {
            self.cpuUsage = 10.0 // Start with 10% baseline
        }
    }
    
    private func stopTracking() {
        cpuTimer?.invalidate()
        cpuTimer = nil
        isTracking = false
    }
    
    // MARK: - Efficient Frame Tracking
    
    /// Call this only when actual drawing occurs (not continuously)
    func trackDrawingEvent(elementCount: Int = 0) {
        guard isTracking else { return }
        
        frameCount += 1
        drawCallCount = elementCount
        
        // Track activity for CPU estimation
        activityCounter += 1
        let currentTime = CACurrentMediaTime()
        
        // Update CPU based on activity
        if currentTime - lastActivityTime >= 1.0 {
            let activityLevel = min(100.0, Double(activityCounter)) // Direct activity to CPU %
            
            DispatchQueue.main.async {
                self.cpuUsage = activityLevel
            }
            
            activityCounter = 0
            lastActivityTime = currentTime
        }
        
        let timeDelta = currentTime - lastUpdateTime
        
        // Update FPS every 1 second (instead of 60 times per second)
        if timeDelta >= 1.0 {
            let fps = Double(frameCount) / timeDelta
            
            DispatchQueue.main.async {
                self.fps = fps
                self.frameTime = timeDelta * 1000.0 / Double(self.frameCount) // Average frame time
            }
            
            frameCount = 0
            lastUpdateTime = currentTime
        }
    }
    
    /// Track Metal command start (lightweight)
    func metalCommandStart() {
        // Only track if Metal is actually being used
        if renderingMode.contains("Metal") {
            trackDrawingEvent()
        }
    }
    
    // MARK: - System Metrics (Low Frequency)
    
    private func updateSystemMetrics() {
        // CPU usage
        updateCPUUsage()
        
        // Memory usage (already low frequency)
        updateMemoryUsage()
    }
    
    private func updateCPUUsage() {
        // Use a simpler, more reliable CPU monitoring approach
        let processInfo = ProcessInfo.processInfo
        
        // Get current system load (simple approximation)
        var loadAvg = [Double](repeating: 0, count: 3)
        let result = getloadavg(&loadAvg, 3)
        
        if result > 0 {
            // Use 1-minute load average as CPU indicator
            let cpuLoad = min(100.0, loadAvg[0] * 100.0 / Double(processInfo.processorCount))
            
            DispatchQueue.main.async {
                self.cpuUsage = cpuLoad
            }
        } else {
            // Fallback: Use activity monitor approach
            updateCPUUsingActivityMonitor()
        }
    }
    
    private func updateCPUUsingActivityMonitor() {
        // Simple activity-based CPU estimation
        let now = CACurrentMediaTime()
        
        activityFrameCount += 1
        
        if now - activityLastFrameTime >= 2.0 { // Update every 2 seconds
            let estimatedCPU = min(100.0, Double(activityFrameCount)) // Direct frame count to CPU %
            
            DispatchQueue.main.async {
                self.cpuUsage = estimatedCPU
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
    
    // MARK: - Performance Assessment
    
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
    
    /// Color specifically for performance grade text
    var performanceGradeColor: Color {
        switch performanceGrade {
        case "Efficient": return .green
        case "Moderate CPU": return .yellow
        case "High CPU": return .orange
        case "CPU Overload": return .red
        default: return .green // Default to green for any other cases
        }
    }
}

// MARK: - Lightweight Performance Overlay

struct LightweightPerformanceOverlay: View {
    @ObservedObject var monitor: OptimizedPerformanceMonitor
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Compact CPU indicator
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
