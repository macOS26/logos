import SwiftUI
import CoreGraphics

struct CoreGraphicsPathTestView: View {
    @State private var pathA: CGPath = createSamplePath(center: CGPoint(x: 150, y: 150), size: 80)
    @State private var pathB: CGPath = createSamplePath(center: CGPoint(x: 200, y: 150), size: 80)
    @State private var resultPath: CGPath?
    @State private var selectedOperation: PathOperation = .union
    @State private var fillRule: CGPathFillRule = .winding
    @State private var threshold: Double = 1.0
    @State private var showOriginalPaths = true
    @State private var showResultPath = true
    @State private var animateResults = false
    
    enum PathOperation: String, CaseIterable {
        case union = "Union"
        case intersection = "Intersection" 
        case subtracting = "Subtracting"
        case symmetricDifference = "Symmetric Difference"
        case lineIntersection = "Line Intersection"
        case lineSubtracting = "Line Subtracting"
        case flattened = "Flattened"
        case normalized = "Normalized"
        case componentsSeparated = "Components Separated"
        case intersects = "Intersects (Bool)"
        
        var requiresTwoPaths: Bool {
            switch self {
            case .union, .intersection, .subtracting, .symmetricDifference, .lineIntersection, .lineSubtracting, .intersects:
                return true
            case .flattened, .normalized, .componentsSeparated:
                return false
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            // Left Panel - Controls
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("CoreGraphics Path Operations Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Testing new native CoreGraphics boolean operations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                // Operation Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Operation")
                        .font(.headline)
                    
                    Picker("Operation", selection: $selectedOperation) {
                        ForEach(PathOperation.allCases, id: \.self) { operation in
                            Text(operation.rawValue).tag(operation)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Fill Rule
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fill Rule")
                        .font(.headline)
                    
                    Picker("Fill Rule", selection: $fillRule) {
                        Text("Winding").tag(CGPathFillRule.winding)
                        Text("Even-Odd").tag(CGPathFillRule.evenOdd)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Threshold (for flattened operation)
                if selectedOperation == .flattened {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Threshold: \(threshold, specifier: "%.1f")")
                            .font(.headline)
                        
                        Slider(value: $threshold, in: 0.1...10.0)
                    }
                }
                
                // Display Options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display")
                        .font(.headline)
                    
                    Toggle("Show Original Paths", isOn: $showOriginalPaths)
                    Toggle("Show Result Path", isOn: $showResultPath)
                    Toggle("Animate Results", isOn: $animateResults)
                }
                
                // Test Path Controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Paths")
                        .font(.headline)
                    
                    Button("Generate Circle Paths") {
                        generateCirclePaths()
                    }
                    
                    Button("Generate Rectangle Paths") {
                        generateRectanglePaths()
                    }
                    
                    Button("Generate Complex Paths") {
                        generateComplexPaths()
                    }
                    
                    Button("Generate Star Paths") {
                        generateStarPaths()
                    }
                }
                
                // Execute Operation
                Button("Execute Operation") {
                    executeOperation()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Spacer()
                
                // Results Info
                if let result = resultPath {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Result Info")
                            .font(.headline)
                        
                        Text("Bounds: \(formatRect(result.boundingBox))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Empty: \(result.isEmpty)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Contains Points: \(!result.isEmpty)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 280)
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // Right Panel - Canvas
            VStack {
                Text("Canvas Preview")
                    .font(.headline)
                
                ZStack {
                    // Background
                    Rectangle()
                        .fill(Color.white)
                        .border(Color.gray)
                    
                    // Grid
                    GridPattern()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    
                    // Original Paths
                    if showOriginalPaths {
                        // Path A
                        Path(pathA)
                            .fill(Color.blue.opacity(0.3))
                            .overlay(
                                Path(pathA)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                        
                        // Path B (if operation requires two paths)
                        if selectedOperation.requiresTwoPaths {
                            Path(pathB)
                                .fill(Color.red.opacity(0.3))
                                .overlay(
                                    Path(pathB)
                                        .stroke(Color.red, lineWidth: 2)
                                )
                        }
                    }
                    
                    // Result Path
                    if showResultPath, let result = resultPath {
                        if animateResults {
                            Path(result)
                                .fill(Color.green.opacity(0.4))
                                .overlay(
                                    Path(result)
                                        .stroke(Color.green, lineWidth: 3)
                                )
                                .scaleEffect(animateResults ? 1.0 : 0.8)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateResults)
                        } else {
                            Path(result)
                                .fill(Color.green.opacity(0.4))
                                .overlay(
                                    Path(result)
                                        .stroke(Color.green, lineWidth: 3)
                                )
                        }
                    }
                    
                    // Labels
                    if showOriginalPaths {
                        VStack {
                            HStack {
                                Text("A")
                                    .foregroundColor(.blue)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .position(x: 150, y: 100)
                                
                                if selectedOperation.requiresTwoPaths {
                                    Text("B")
                                        .foregroundColor(.red)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .position(x: 200, y: 100)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .frame(width: 400, height: 300)
                .clipped()
                
                // Performance/Error Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("CoreGraphics Performance Notes:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Text("• Native boolean operations preserve curves")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("• No tessellation required unlike Clipper")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("• Hardware-accelerated rendering")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("• Available in macOS 14+ / iOS 17+")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .padding(.top)
            }
            .padding()
        }
        .onAppear {
            executeOperation() // Show initial result
        }
        .onChange(of: selectedOperation) { _ in
            executeOperation()
        }
        .onChange(of: fillRule) { _ in
            executeOperation()
        }
        .onChange(of: threshold) { _ in
            if selectedOperation == .flattened {
                executeOperation()
            }
        }
    }
    
    // MARK: - Operations
    
    private func executeOperation() {
        DispatchQueue.main.async {
            do {
                switch selectedOperation {
                case .union:
                    resultPath = pathA.union(pathB, using: fillRule)
                    
                case .intersection:
                    resultPath = pathA.intersection(pathB, using: fillRule)
                    
                case .subtracting:
                    resultPath = pathA.subtracting(pathB, using: fillRule)
                    
                case .symmetricDifference:
                    resultPath = pathA.symmetricDifference(pathB, using: fillRule)
                    
                case .lineIntersection:
                    resultPath = pathA.lineIntersection(pathB, using: fillRule)
                    
                case .lineSubtracting:
                    resultPath = pathA.lineSubtracting(pathB, using: fillRule)
                    
                case .flattened:
                    resultPath = pathA.flattened(threshold: CGFloat(threshold))
                    
                case .normalized:
                    resultPath = pathA.normalized(using: fillRule)
                    
                case .componentsSeparated:
                    let components = pathA.componentsSeparated(using: fillRule)
                    // For display, create a union of all components
                    if !components.isEmpty {
                        var combined = components[0]
                        for i in 1..<components.count {
                            combined = combined.union(components[i], using: fillRule)
                        }
                        resultPath = combined
                    }
                    
                case .intersects:
                    // For boolean result, create a visual indicator
                    let intersects = pathA.intersects(pathB, using: fillRule)
                    // Create a text path or simple indicator
                    resultPath = createTextIndicator(text: intersects ? "TRUE" : "FALSE")
                }
                
                if animateResults {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        animateResults = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            animateResults = true
                        }
                    }
                }
                
            } catch {
                print("CoreGraphics operation failed: \(error)")
                resultPath = nil
            }
        }
    }
    
    // MARK: - Path Generators
    
    private func generateCirclePaths() {
        pathA = createCirclePath(center: CGPoint(x: 150, y: 150), radius: 50)
        pathB = createCirclePath(center: CGPoint(x: 200, y: 150), radius: 40)
        executeOperation()
    }
    
    private func generateRectanglePaths() {
        pathA = createRectanglePath(rect: CGRect(x: 100, y: 100, width: 100, height: 100))
        pathB = createRectanglePath(rect: CGRect(x: 150, y: 125, width: 100, height: 100))
        executeOperation()
    }
    
    private func generateComplexPaths() {
        pathA = createComplexPath1()
        pathB = createComplexPath2()
        executeOperation()
    }
    
    private func generateStarPaths() {
        pathA = createStarPath(center: CGPoint(x: 150, y: 150), outerRadius: 50, innerRadius: 25, points: 5)
        pathB = createStarPath(center: CGPoint(x: 200, y: 150), outerRadius: 40, innerRadius: 20, points: 6)
        executeOperation()
    }
    
    // MARK: - Helper Functions
    
    private func formatRect(_ rect: CGRect) -> String {
        return String(format: "(%.1f,%.1f) %.1fx%.1f", rect.origin.x, rect.origin.y, rect.width, rect.height)
    }
}

// MARK: - Path Creation Helpers

private func createSamplePath(center: CGPoint, size: CGFloat) -> CGPath {
    return createCirclePath(center: center, radius: size / 2)
}

private func createCirclePath(center: CGPoint, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.addEllipse(in: CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    ))
    return path
}

private func createRectanglePath(rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    path.addRect(rect)
    return path
}

private func createStarPath(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int) -> CGPath {
    let path = CGMutablePath()
    let angleIncrement = CGFloat.pi * 2 / CGFloat(points * 2)
    
    for i in 0..<(points * 2) {
        let angle = CGFloat(i) * angleIncrement - CGFloat.pi / 2
        let radius = i % 2 == 0 ? outerRadius : innerRadius
        let x = center.x + cos(angle) * radius
        let y = center.y + sin(angle) * radius
        
        if i == 0 {
            path.move(to: CGPoint(x: x, y: y))
        } else {
            path.addLine(to: CGPoint(x: x, y: y))
        }
    }
    
    path.closeSubpath()
    return path
}

private func createComplexPath1() -> CGPath {
    let path = CGMutablePath()
    // Create a path with curves
    path.move(to: CGPoint(x: 100, y: 150))
    path.addCurve(to: CGPoint(x: 200, y: 150), 
                  control1: CGPoint(x: 125, y: 100), 
                  control2: CGPoint(x: 175, y: 200))
    path.addCurve(to: CGPoint(x: 150, y: 100), 
                  control1: CGPoint(x: 225, y: 125), 
                  control2: CGPoint(x: 175, y: 75))
    path.closeSubpath()
    return path
}

private func createComplexPath2() -> CGPath {
    let path = CGMutablePath()
    // Create another curved path
    path.move(to: CGPoint(x: 175, y: 125))
    path.addCurve(to: CGPoint(x: 250, y: 175), 
                  control1: CGPoint(x: 200, y: 100), 
                  control2: CGPoint(x: 225, y: 150))
    path.addCurve(to: CGPoint(x: 200, y: 200), 
                  control1: CGPoint(x: 275, y: 200), 
                  control2: CGPoint(x: 225, y: 225))
    path.closeSubpath()
    return path
}

private func createTextIndicator(text: String) -> CGPath {
    // Create a simple rectangular indicator
    let path = CGMutablePath()
    path.addRect(CGRect(x: 150, y: 140, width: 100, height: 20))
    return path
}

// MARK: - Grid Pattern

struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let gridSpacing: CGFloat = 20
        
        // Vertical lines
        for x in stride(from: 0, through: rect.width, by: gridSpacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        // Horizontal lines
        for y in stride(from: 0, through: rect.height, by: gridSpacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        return path
    }
}

// MARK: - Preview

struct CoreGraphicsPathTestView_Previews: PreviewProvider {
    static var previews: some View {
        CoreGraphicsPathTestView()
            .frame(width: 1000, height: 700)
    }
} 