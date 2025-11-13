import SwiftUI

//struct PerformanceOverlay: View {
//    @Bindable var performanceMonitor: PerformanceMonitor
//    @State private var isExpanded: Bool = false
//    @State private var showDetailedStats: Bool = false
//
//    var body: some View {
//        VStack {
//            HStack {
//                Spacer()
//                performanceHUD
//            }
//            Spacer()
//        }
//        .allowsHitTesting(false)
//    }
//
//    private var performanceHUD: some View {
//        VStack(alignment: .trailing, spacing: 4) {
//            fpsIndicator
//
//            if isExpanded {
//                detailedStats
//            }
//        }
//        .padding(8)
//        .background(
//            RoundedRectangle(cornerRadius: 8)
//                .fill(.ultraThinMaterial)
//                .shadow(radius: 2)
//        )
//        .onTapGesture {
//            withAnimation(.easeInOut(duration: 0.2)) {
//                isExpanded.toggle()
//            }
//        }
//        .allowsHitTesting(true)
//        .offset(x: 24, y: 12)
//    }
//
//    private var fpsIndicator: some View {
//        HStack(spacing: 6) {
//            Circle()
//                .fill(performanceStatusColor)
//                .frame(width: 8, height: 8)
//
//            Text("\(Int(performanceMonitor.fps)) FPS")
//                .font(.system(.caption, design: .monospaced, weight: .medium))
//                .foregroundColor(.primary)
//
//            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
//                .font(.caption2)
//                .foregroundColor(.secondary)
//        }
//    }
//
//    private var detailedStats: some View {
//        VStack(alignment: .trailing, spacing: 2) {
//            Divider()
//
//            statRow(label: "Frame", value: String(format: "%.1f ms", performanceMonitor.frameTime))
//
//            statRow(label: "Mode", value: performanceMonitor.renderingMode)
//
//            if !performanceMonitor.metalDeviceName.isEmpty && performanceMonitor.metalDeviceName != "None" {
//                statRow(label: "GPU", value: deviceShortName)
//            }
//
//            statRow(label: "Memory", value: String(format: "%.0f MB", performanceMonitor.memoryUsage))
//
//            if performanceMonitor.drawCallCount > 0 {
//                statRow(label: "Draws", value: "\(performanceMonitor.drawCallCount)")
//            }
//
//            statRowWithColor(label: "Grade", value: performanceMonitor.performanceGrade, color: performanceMonitor.performanceGradeColor)
//        }
//        .font(.system(.caption2, design: .monospaced))
//    }
//
//    private func statRow(label: String, value: String) -> some View {
//        HStack(spacing: 4) {
//            Text(label + ":")
//                .foregroundColor(.secondary)
//            Text(value)
//                .foregroundColor(.primary)
//        }
//    }
//
//    private func statRowWithColor(label: String, value: String, color: Color) -> some View {
//        HStack(spacing: 4) {
//            Text(label + ":")
//                .foregroundColor(.secondary)
//            Text(value)
//                .foregroundColor(color)
//        }
//    }
//
//    private var performanceStatusColor: Color {
//        switch performanceMonitor.fps {
//        case 60...: return .green
//        case 30..<60: return .yellow
//        case 15..<30: return .orange
//        default: return .red
//        }
//    }
//
//    private var deviceShortName: String {
//        let deviceName = performanceMonitor.metalDeviceName
//        if deviceName.contains("Apple") {
//            let components = deviceName.components(separatedBy: " ")
//            if let chipIndex = components.firstIndex(where: { $0.hasPrefix("M") }) {
//                return components[chipIndex...]
//                    .joined(separator: " ")
//                    .replacingOccurrences(of: "Apple ", with: "")
//            }
//        }
//        return deviceName
//    }
//}
