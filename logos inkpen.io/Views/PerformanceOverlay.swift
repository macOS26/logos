import SwiftUI

/// Performance statistics overlay for monitoring Metal pseudo-object performance
struct PerformanceOverlay: View {
    @ObservedObject var performanceMonitor: PerformanceMonitor
    @State private var isExpanded: Bool = false
    @State private var showDetailedStats: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                performanceHUD
            }
            Spacer()
        }
        .allowsHitTesting(false) // Don't interfere with canvas interactions
    }
    
    private var performanceHUD: some View {
        VStack(alignment: .trailing, spacing: 4) {
            // Main FPS indicator
            fpsIndicator
            
            if isExpanded {
                detailedStats
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(radius: 2)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .allowsHitTesting(true) // Allow tapping to expand
    }
    
    private var fpsIndicator: some View {
        HStack(spacing: 6) {
            // Performance status indicator
            Circle()
                .fill(performanceStatusColor)
                .frame(width: 8, height: 8)
            
            // FPS display
            Text("\(Int(performanceMonitor.fps)) FPS")
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundColor(.primary)
            
            // Expand/collapse chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var detailedStats: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Divider()
            
            // Frame time
            statRow(label: "Frame", value: String(format: "%.1f ms", performanceMonitor.frameTime))
            
            // Rendering mode
            statRow(label: "Mode", value: performanceMonitor.renderingMode)
            
            // Metal device
            if !performanceMonitor.metalDeviceName.isEmpty && performanceMonitor.metalDeviceName != "None" {
                statRow(label: "GPU", value: deviceShortName)
            }
            
            // Memory usage
            statRow(label: "Memory", value: String(format: "%.0f MB", performanceMonitor.memoryUsage))
            
            // Draw calls (reset every frame)
            if performanceMonitor.drawCallCount > 0 {
                statRow(label: "Draws", value: "\(performanceMonitor.drawCallCount)")
            }
            
            // Performance grade
            statRow(label: "Grade", value: performanceMonitor.performanceGrade)
        }
        .font(.system(.caption2, design: .monospaced))
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .foregroundColor(.secondary)
            Text(value)
                .foregroundColor(.primary)
        }
    }
    
    private var performanceStatusColor: Color {
        switch performanceMonitor.fps {
        case 60...: return .green
        case 30..<60: return .yellow
        case 15..<30: return .orange
        default: return .red
        }
    }
    
    private var deviceShortName: String {
        let deviceName = performanceMonitor.metalDeviceName
        if deviceName.contains("Apple") {
            // Extract just the chip name (e.g., "M4", "M3 Pro")
            let components = deviceName.components(separatedBy: " ")
            if let chipIndex = components.firstIndex(where: { $0.hasPrefix("M") }) {
                return components[chipIndex...]
                    .joined(separator: " ")
                    .replacingOccurrences(of: "Apple ", with: "")
            }
        }
        return deviceName
    }
}

#Preview {
    ZStack {
        Rectangle()
            .fill(.gray.opacity(0.2))
            .frame(width: 400, height: 300)
        
        PerformanceOverlay(performanceMonitor: PerformanceMonitor())
    }
}
