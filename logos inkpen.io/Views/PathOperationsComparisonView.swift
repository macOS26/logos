import SwiftUI
import CoreGraphics

struct PathOperationsComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var document: VectorDocument
    @State private var selectedPathA: CGPath? = nil
    @State private var selectedPathB: CGPath? = nil
    @State private var selectedOperation: ComparisonOperation = .union
    @State private var fillRule: CGPathFillRule = .winding
    @State private var showSourcePaths = true
    @State private var showTimingInfo = true
    @State private var coreGraphicsResult: CGPath? = nil
    @State private var clipperResult: [CGPath] = []
    @State private var coreGraphicsTime: Double = 0
    @State private var clipperTime: Double = 0
    @State private var errorMessage: String? = nil
    
    enum ComparisonOperation: String, CaseIterable {
        case union = "Union"
        case intersection = "Intersection"
        case subtracting = "Subtracting"
        case symmetricDifference = "Symmetric Difference"
        
        var description: String {
            switch self {
            case .union: return "Combines both paths"
            case .intersection: return "Only overlapping areas"
            case .subtracting: return "Path A minus Path B"
            case .symmetricDifference: return "Areas in either path but not both"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection
            
            // Controls
            controlsSection
            
            // Comparison Results
            HStack(spacing: 20) {
                // CoreGraphics Results
                coreGraphicsSection
                
                Divider()
                
                // ClipperPath Results
                clipperPathSection
            }
            
            // Performance Comparison
            if showTimingInfo {
                performanceSection
            }
            
            // Error Display
            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            loadSelectedPaths()
        }
        .onChange(of: selectedOperation) { _ in
            performComparison()
        }
        .onChange(of: fillRule) { _ in
            performComparison()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Path Operations Comparison")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("CoreGraphics (macOS 14+) vs ClipperPath Implementation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
            }
            
            if selectedPathA == nil || selectedPathB == nil {
                Text("Select two shapes in the main document to compare operations")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        HStack {
            // Operation Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Operation")
                    .font(.headline)
                
                Picker("Operation", selection: $selectedOperation) {
                    ForEach(ComparisonOperation.allCases, id: \.self) { operation in
                        VStack(alignment: .leading) {
                            Text(operation.rawValue)
                            Text(operation.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(operation)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Spacer()
            
            // Fill Rule
            VStack(alignment: .leading, spacing: 4) {
                Text("Fill Rule")
                    .font(.headline)
                
                Picker("Fill Rule", selection: $fillRule) {
                    Text("Winding").tag(CGPathFillRule.winding)
                    Text("Even-Odd").tag(CGPathFillRule.evenOdd)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Spacer()
            
            // Display Options
            VStack(alignment: .leading, spacing: 4) {
                Text("Display")
                    .font(.headline)
                
                Toggle("Show Source Paths", isOn: $showSourcePaths)
                Toggle("Show Timing Info", isOn: $showTimingInfo)
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 8) {
                Button("Refresh Paths") {
                    loadSelectedPaths()
                }
                .buttonStyle(.bordered)
                
                Button("Run Comparison") {
                    performComparison()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPathA == nil || selectedPathB == nil)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - CoreGraphics Section
    
    private var coreGraphicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                Text("CoreGraphics")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                if #available(macOS 14.0, *) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .help("Available on this system")
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .help("Requires macOS 14+")
                }
                
                Spacer()
            }
            
            // Canvas
            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .border(Color.gray)
                
                // Source paths
                if showSourcePaths, let pathA = selectedPathA, let pathB = selectedPathB {
                    Path(pathA)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                    Path(pathB)
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                }
                
                // Result
                if let result = coreGraphicsResult {
                    Path(result)
                        .fill(Color.blue.opacity(0.3))
                        .overlay(
                            Path(result)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }
                
                // Availability overlay
                if #unavailable(macOS 14.0) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.7))
                        .overlay(
                            VStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.title)
                                Text("macOS 14+ Required")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 300, height: 200)
            .clipped()
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Native Boolean Operations")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("• Preserves smooth curves")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• Hardware accelerated")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• No tessellation required")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if showTimingInfo && coreGraphicsTime > 0 {
                    Text("Time: \(String(format: "%.4f", coreGraphicsTime))s")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    // MARK: - ClipperPath Section
    
    private var clipperPathSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scissors")
                    .foregroundColor(.orange)
                Text("ClipperPath")
                    .font(.headline)
                    .foregroundColor(.orange)
                
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .help("Available on all systems")
                
                Spacer()
            }
            
            // Canvas
            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .border(Color.gray)
                
                // Source paths
                if showSourcePaths, let pathA = selectedPathA, let pathB = selectedPathB {
                    Path(pathA)
                        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                    Path(pathB)
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                }
                
                // Results (ClipperPath can return multiple paths)
                ForEach(Array(clipperResult.enumerated()), id: \.offset) { index, result in
                    Path(result)
                        .fill(Color.orange.opacity(0.3))
                        .overlay(
                            Path(result)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                }
            }
            .frame(width: 300, height: 200)
            .clipped()
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Polygon-Based Operations")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Text("• Converts curves to line segments")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• Robust for complex shapes")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("• Cross-platform compatible")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if showTimingInfo && clipperTime > 0 {
                    Text("Time: \(String(format: "%.4f", clipperTime))s")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
                
                if !clipperResult.isEmpty {
                    Text("Results: \(clipperResult.count) path(s)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Comparison")
                .font(.headline)
            
            if coreGraphicsTime > 0 && clipperTime > 0 {
                HStack {
                    Text("CoreGraphics:")
                        .foregroundColor(.blue)
                    Text("\(String(format: "%.4f", coreGraphicsTime))s")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("ClipperPath:")
                        .foregroundColor(.orange)
                    Text("\(String(format: "%.4f", clipperTime))s")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    let speedup = clipperTime / max(coreGraphicsTime, 0.0001)
                    Text("Speedup: \(String(format: "%.2f", speedup))x")
                        .foregroundColor(speedup > 1 ? .green : .red)
                        .fontWeight(.bold)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("Run comparison to see performance metrics")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadSelectedPaths() {
        // Get the first two selected shapes from the document
        let selectedShapes = document.getSelectedShapes()
        
        if selectedShapes.count >= 2 {
            selectedPathA = selectedShapes[0].path.cgPath
            selectedPathB = selectedShapes[1].path.cgPath
            errorMessage = nil
            performComparison()
        } else {
            selectedPathA = nil
            selectedPathB = nil
            errorMessage = "Please select at least 2 shapes in the main document"
        }
    }
    
    private func performComparison() {
        guard let pathA = selectedPathA, let pathB = selectedPathB else {
            errorMessage = "No paths selected for comparison"
            return
        }
        
        errorMessage = nil
        
        // Run CoreGraphics operation
        if #available(macOS 14.0, *) {
            let coreStart = CFAbsoluteTimeGetCurrent()
            
            do {
                switch selectedOperation {
                case .union:
                    coreGraphicsResult = pathA.union(pathB, using: fillRule)
                case .intersection:
                    coreGraphicsResult = pathA.intersection(pathB, using: fillRule)
                case .subtracting:
                    coreGraphicsResult = pathA.subtracting(pathB, using: fillRule)
                case .symmetricDifference:
                    coreGraphicsResult = pathA.symmetricDifference(pathB, using: fillRule)
                }
                
                coreGraphicsTime = CFAbsoluteTimeGetCurrent() - coreStart
            } catch {
                coreGraphicsResult = nil
                errorMessage = "CoreGraphics operation failed: \(error.localizedDescription)"
            }
        } else {
            coreGraphicsResult = nil
            coreGraphicsTime = 0
        }
        
        // Run ClipperPath operation
        let clipperStart = CFAbsoluteTimeGetCurrent()
        
        do {
            let clipperPathA = pathA.toClipperPath()
            let clipperPathB = pathB.toClipperPath()
            
            let clipperResults: ClipperPaths
            
            switch selectedOperation {
            case .union:
                clipperResults = clipperPathA.union(clipperPathB)
            case .intersection:
                clipperResults = clipperPathA.intersection(clipperPathB)
            case .subtracting:
                clipperResults = clipperPathA.difference(clipperPathB)
            case .symmetricDifference:
                clipperResults = clipperPathA.xor(clipperPathB)
            }
            
            // Convert ClipperPaths back to CGPaths
            clipperResult = clipperResults.map { clipperPath in
                let path = CGMutablePath()
                if !clipperPath.isEmpty {
                    path.move(to: clipperPath[0])
                    for i in 1..<clipperPath.count {
                        path.addLine(to: clipperPath[i])
                    }
                    path.closeSubpath()
                }
                return path
            }
            
            clipperTime = CFAbsoluteTimeGetCurrent() - clipperStart
            
        } catch {
            clipperResult = []
            errorMessage = "ClipperPath operation failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

struct PathOperationsComparisonView_Previews: PreviewProvider {
    static var previews: some View {
        PathOperationsComparisonView(document: VectorDocument())
            .frame(width: 1000, height: 700)
    }
} 