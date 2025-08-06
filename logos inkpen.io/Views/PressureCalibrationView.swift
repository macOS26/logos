//
//  PressureCalibrationView.swift
//  logos inkpen.io
//
//  Pressure calibration window for testing device pressure range
//

import SwiftUI

struct PressureCalibrationView: View {
    @ObservedObject private var pressureManager = PressureManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    // Visual feedback state
    @State private var currentPressureBarWidth: CGFloat = 0
    @State private var minPressureBarWidth: CGFloat = 0
    @State private var maxPressureBarWidth: CGFloat = 0
    @State private var tabletOnlyMode: Bool = true // Focus on Apple Pencil/stylus only
    
    // Event logging for debugging
    @State private var eventLog: [String] = []
    private let maxEventLogEntries = 20
    
    // Drawing state
    @State private var isDrawing = false
    @State private var currentPath: VariableStrokePath?
    @State private var drawingPaths: [VariableStrokePath] = []
    
    // Pressure curve editor state
    @State private var pressureCurve: [CGPoint] = [
        CGPoint(x: 0.0, y: 0.0),   // 0.0 pressure = 0.0 thickness
        CGPoint(x: 0.25, y: 0.25), // 0.25 pressure = 0.25 thickness
        CGPoint(x: 0.5, y: 0.5),   // 0.5 pressure = 0.5 thickness
        CGPoint(x: 0.75, y: 0.75), // 0.75 pressure = 0.75 thickness
        CGPoint(x: 1.0, y: 1.0)    // 1.0 pressure = 1.0 thickness
    ]
    @State private var selectedControlPoint: Int?
    
    // Constants
    private let barMaxWidth: CGFloat = 200 // Narrower pressure bars
    private let maxPressureValue: Double = 1.0
    
    var body: some View {
        VStack(spacing: 12) {
                // Header section
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pressure Calibration")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if tabletOnlyMode {
                            Text("🎯 Tablet/Stylus Mode Active")
                                .font(.caption)
                                .foregroundColor(.blue)
                        } else {
                            Text("🖱️ All Input Devices")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Main content - follows NewDocumentSetupView pattern
                HStack(spacing: 20) {
                    // Left side - Test canvas (takes up most of the space)
                    VStack(spacing: 8) {
                        pressureTestCanvas
                        
                        // Control buttons below canvas
                        controlButtonsSection
                    }
                    .frame(minWidth: 800, maxWidth: .infinity) // Much larger minimum width for canvas
                    .layoutPriority(2) // Give canvas area higher priority
                    
                    // Right side - Data, visualization, and curve editor (fixed width)
                    VStack(spacing: 12) {
                        // Pressure curve editor at the top
                        pressureCurveEditor
                        
                        // Current pressure and range in horizontal layout
                        HStack(spacing: 16) {
                            currentPressureSection
                            pressureRangeSection
                        }
                        
                        // Pressure visualization
                        pressureVisualizationSection
                        
                        // Event log
                        eventLogSection
                    }
                    .frame(width: 320) // Narrower fixed width for right panel
                    .layoutPriority(1) // Lower priority
                }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(width: 1200, height: 800)
        .onAppear {
            updateVisualization()
            // Sync the UI toggle with the pressure manager
            pressureManager.tabletOnlyCalibration = tabletOnlyMode
            
            // Don't start calibration automatically - let user start it manually
            addEventToLog("Pressure calibration tool opened - ready to start")
        }
        .onChange(of: pressureManager.currentPressure) { _ in
            updateVisualization()
        }
    }
    
    // MARK: - Pressure Curve Editor
    
    private var pressureCurveEditor: some View {
        VStack(spacing: 8) {
            Text("Pressure Curve")
                .font(.headline)
                .foregroundColor(.primary)
            
            ZStack {
                // Background grid
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .border(Color.gray.opacity(0.3), width: 1)
                
                // Grid lines
                Path { path in
                    // Vertical lines
                    for i in 0...10 {
                        let x = CGFloat(i) * 25
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: 250))
                    }
                    // Horizontal lines
                    for i in 0...10 {
                        let y = CGFloat(i) * 25
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: 250, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                
                // Curve path
                Path { path in
                    guard pressureCurve.count >= 2 else { return }
                    
                    let firstPoint = pressureCurve[0]
                    path.move(to: CGPoint(x: firstPoint.x * 250, y: 250 - firstPoint.y * 250))
                    
                    for i in 1..<pressureCurve.count {
                        let point = pressureCurve[i]
                        path.addLine(to: CGPoint(x: point.x * 250, y: 250 - point.y * 250))
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
                
                // Control points
                ForEach(0..<pressureCurve.count, id: \.self) { index in
                    let point = pressureCurve[index]
                    Circle()
                        .fill(selectedControlPoint == index ? Color.red : Color.blue)
                        .frame(width: 12, height: 12)
                        .position(x: point.x * 250, y: 250 - point.y * 250)
                        .onTapGesture {
                            selectedControlPoint = index
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if selectedControlPoint == index {
                                        let newX = max(0, min(1, value.location.x / 250))
                                        let newY = max(0, min(1, (250 - value.location.y) / 250))
                                        pressureCurve[index] = CGPoint(x: newX, y: newY)
                                        
                                        // Sort points by x value to maintain order
                                        pressureCurve.sort { $0.x < $1.x }
                                        
                                        // Update selected index after sorting
                                        if let selectedIndex = selectedControlPoint {
                                            selectedControlPoint = pressureCurve.firstIndex { abs($0.x - newX) < 0.01 && abs($0.y - newY) < 0.01 }
                                        }
                                    }
                                }
                        )
                }
            }
            .frame(width: 250, height: 250) // Make it square and taller
            
            // Curve info
            HStack {
                Text("Input: 0.0-1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Output: 0.0-1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Pressure Curve Functions
    
    private func getThicknessFromCurve(pressure: Double) -> Double {
        guard pressureCurve.count >= 2 else { return pressure }
        
        // Find the two control points that bracket the input pressure
        var lowerIndex = 0
        for i in 0..<pressureCurve.count {
            if pressureCurve[i].x <= pressure {
                lowerIndex = i
            } else {
                break
            }
        }
        
        let upperIndex = min(lowerIndex + 1, pressureCurve.count - 1)
        let lowerPoint = pressureCurve[lowerIndex]
        let upperPoint = pressureCurve[upperIndex]
        
        // Linear interpolation between the two points
        if upperPoint.x == lowerPoint.x {
            return lowerPoint.y
        }
        
        let t = (pressure - lowerPoint.x) / (upperPoint.x - lowerPoint.x)
        return lowerPoint.y + t * (upperPoint.y - lowerPoint.y)
    }
    
    // MARK: - Pressure Test Canvas
    
    private var pressureTestCanvas: some View {
        VStack(spacing: 6) {
            Text("Pressure-Sensitive Drawing Canvas")
                .font(.subheadline)
                .fontWeight(.medium)
            
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .border(Color.gray.opacity(0.3), width: 1)
                
                // Drawing instruction overlay
                VStack {
                    Spacer()
                    Text("Draw here to test pressure sensitivity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                
                // Drawing canvas with pressure-sensitive variable-width strokes
                Canvas { context, size in
                    // Draw all completed variable-width strokes
                    for stroke in drawingPaths {
                        context.fill(stroke.path, with: .color(.blue))
                    }
                    
                    // Draw current variable-width stroke if drawing - REAL-TIME UPDATES
                    if let currentPath = currentPath, currentPath.points.count >= 2 {
                        // Generate the current variable-width stroke path
                        let currentStrokePath = createVariableWidthStroke(from: currentPath.points)
                        context.fill(currentStrokePath, with: .color(.red))
                    } else if let currentPath = currentPath, currentPath.points.count == 1 {
                        // Single point - draw a small circle
                        let point = currentPath.points[0]
                        let radius = CGFloat(0.1 + (point.pressure * 0.9)) / 2.0
                        let circlePath = Path { path in
                            path.addEllipse(in: CGRect(x: point.location.x - radius, y: point.location.y - radius, width: radius * 2, height: radius * 2))
                        }
                        context.fill(circlePath, with: .color(.red))
                    }
                    
                    // Draw pressure indicator
                    if isDrawing {
                        let normalizedPressure = max(0.0, min(1.0, pressureManager.currentPressure / 2.0))
                        let thickness = 0.1 + (normalizedPressure * 0.9)
                        let pressureText = String(format: "Pressure: %.2f (Width: %.1f)", normalizedPressure, thickness)
                        context.draw(Text(pressureText).font(.caption).foregroundColor(.black), at: CGPoint(x: 10, y: size.height - 30))
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDrawingGesture(value)
                        }
                        .onEnded { _ in
                            finishDrawing()
                        }
                )
                .frame(minHeight: 500) // Larger minimum height for canvas
                
                // Pressure-sensitive canvas with comprehensive event detection
                PressureSensitiveCanvasRepresentable(
                    onPressureEvent: { location, pressure, eventType, isTabletEvent in
                        print("🎨 CALIBRATION CANVAS: Event received - type: \(eventType), pressure: \(pressure), tablet: \(isTabletEvent)")
                        print("🎨 CALIBRATION CANVAS: Location: (\(location.x), \(location.y))")
                        
                        // Update pressure manager
                        pressureManager.processRealPressure(pressure, at: location, isTabletEvent: isTabletEvent)
                        
                        // Handle drawing based on pressure events
                        handlePressureDrawing(location: location, pressure: pressure, eventType: eventType, isTabletEvent: isTabletEvent)
                        
                        // Update calibration if active
                        if pressureManager.isCalibrating {
                            print("🎨 CALIBRATION CANVAS: Updating calibration with pressure: \(pressure)")
                        }
                        
                        // Log all pressure events regardless of calibration state
                        print("🎨 CALIBRATION CANVAS: ALL PRESSURE EVENTS DETECTED:")
                        print("   - Event Type: \(eventType)")
                        print("   - Pressure Value: \(pressure)")
                        print("   - Is Tablet Event: \(isTabletEvent)")
                        print("   - Location: (\(location.x), \(location.y))")
                        print("   - Calibration Active: \(pressureManager.isCalibrating)")
                        print("   - Current Min: \(pressureManager.calibrationMinPressure)")
                        print("   - Current Max: \(pressureManager.calibrationMaxPressure)")
                        print("   - Sample Count: \(pressureManager.calibrationSampleCount)")
                        print("   ---")
                        
                        // Add to event log for real-time display
                        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                        let logEntry = "[\(timestamp)] \(eventType) - Pressure: \(String(format: "%.3f", pressure)) - Tablet: \(isTabletEvent) - Loc: (\(Int(location.x)), \(Int(location.y)))"
                        
                        DispatchQueue.main.async {
                            eventLog.insert(logEntry, at: 0)
                            if eventLog.count > maxEventLogEntries {
                                eventLog.removeLast()
                            }
                        }
                    },
                    hasPressureSupport: .constant(false) // We'll update this based on actual detection
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Drawing Methods
    
    private func handlePressureDrawing(location: CGPoint, pressure: Double, eventType: PressureSensitiveCanvasView.PressureEventType, isTabletEvent: Bool) {
        // Use raw pressure directly (0-2 range), no normalization
        switch eventType {
        case .began:
            startDrawing(at: location, pressure: pressure)
        case .changed:
            continueDrawing(to: location, pressure: pressure)
        case .ended:
            finishDrawing()
        }
    }
    
    private func handleDrawingGesture(_ value: DragGesture.Value) {
        // Fallback for non-pressure devices
        let pressure = 1.0 // Default pressure for non-pressure devices
        let location = value.location
        
        if !isDrawing {
            startDrawing(at: location, pressure: pressure)
        } else {
            continueDrawing(to: location, pressure: pressure)
        }
    }
    
    private func startDrawing(at location: CGPoint, pressure: Double) {
        isDrawing = true
        // Use pressure curve to get thickness: 0.0 pressure = 0.0 thickness, 1.0 pressure = 10.0 thickness
        let curveThickness = getThicknessFromCurve(pressure: pressure)
        let lineWidth = CGFloat(curveThickness * 10.0) // Scale to line width (0.0-10.0)
        currentPath = VariableStrokePath(points: [PressurePoint(location: location, pressure: pressure)])
        
        // Start calibration if not already started
        if !pressureManager.isCalibrating {
            pressureManager.startCalibration()
        }
    }
    
    private func continueDrawing(to location: CGPoint, pressure: Double) {
        guard isDrawing, var path = currentPath else { return }
        
        // Use pressure curve to get thickness: 0.0 pressure = 0.0 thickness, 1.0 pressure = 10.0 thickness
        let curveThickness = getThicknessFromCurve(pressure: pressure)
        let lineWidth = CGFloat(curveThickness * 10.0) // Scale to line width (0.0-10.0)
        path.points.append(PressurePoint(location: location, pressure: pressure))
        currentPath = path
        
        // Update the canvas immediately to show real-time changes
        updateCanvas()
    }
    
    private func finishDrawing() {
        guard isDrawing, let path = currentPath else { return }
        
        // Create the final variable-width stroke path
        let strokePath = createVariableWidthStroke(from: path.points)
        
        // Add the completed stroke to the drawing
        var completedStroke = VariableStrokePath(points: path.points)
        completedStroke.path = strokePath
        drawingPaths.append(completedStroke)
        
        // Reset drawing state
        isDrawing = false
        currentPath = nil
        
        // Update canvas
        updateCanvas()
    }
    
    private func clearCanvas() {
        drawingPaths.removeAll()
        currentPath = nil
        isDrawing = false
        updateCanvas()
    }
    
    private func updateCanvas() {
        // Force canvas redraw
        // This will be handled by the @State changes
    }
    
    // MARK: - Variable Width Stroke Generation
    
    private func createVariableWidthStroke(from pressurePoints: [PressurePoint]) -> Path {
        guard pressurePoints.count >= 2 else {
            // Single point - create a small circle
            let point = pressurePoints.first!
            // Use pressure curve to get thickness
            let curveThickness = getThicknessFromCurve(pressure: point.pressure)
            let radius = CGFloat(curveThickness * 10.0) * 1.0 // Scale to reasonable size (0.1-10.0)
            return Path { path in
                path.addEllipse(in: CGRect(x: point.location.x - radius, y: point.location.y - radius, 
                                          width: radius * 2, height: radius * 2))
            }
        }
        
        var path = Path()
        
        // Create a variable-width stroke by generating left and right edge points
        var leftEdgePoints: [CGPoint] = []
        var rightEdgePoints: [CGPoint] = []
        
        for i in 0..<pressurePoints.count {
            let point = pressurePoints[i]
            // Use pressure curve to get thickness
            let curveThickness = getThicknessFromCurve(pressure: point.pressure)
            let thickness = CGFloat(curveThickness * 10.0) * 2.0 // Scale to reasonable size (0.2-20.0)
            
            if i == 0 {
                // First point - use direction to next point
                let nextPoint = pressurePoints[i + 1]
                let direction = CGVector(dx: nextPoint.location.x - point.location.x, 
                                       dy: nextPoint.location.y - point.location.y)
                let length = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
                
                if length > 0 {
                    let normalizedDirection = CGVector(dx: direction.dx / length, dy: direction.dy / length)
                    let perpendicular = CGVector(dx: -normalizedDirection.dy, dy: normalizedDirection.dx)
                    
                    leftEdgePoints.append(CGPoint(x: point.location.x + perpendicular.dx * thickness,
                                                y: point.location.y + perpendicular.dy * thickness))
                    rightEdgePoints.append(CGPoint(x: point.location.x - perpendicular.dx * thickness,
                                                 y: point.location.y - perpendicular.dy * thickness))
                } else {
                    leftEdgePoints.append(point.location)
                    rightEdgePoints.append(point.location)
                }
            } else if i == pressurePoints.count - 1 {
                // Last point - use direction from previous point
                let prevPoint = pressurePoints[i - 1]
                let direction = CGVector(dx: point.location.x - prevPoint.location.x, 
                                       dy: point.location.y - prevPoint.location.y)
                let length = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
                
                if length > 0 {
                    let normalizedDirection = CGVector(dx: direction.dx / length, dy: direction.dy / length)
                    let perpendicular = CGVector(dx: -normalizedDirection.dy, dy: normalizedDirection.dx)
                    
                    leftEdgePoints.append(CGPoint(x: point.location.x + perpendicular.dx * thickness,
                                                y: point.location.y + perpendicular.dy * thickness))
                    rightEdgePoints.append(CGPoint(x: point.location.x - perpendicular.dx * thickness,
                                                 y: point.location.y - perpendicular.dy * thickness))
                } else {
                    leftEdgePoints.append(point.location)
                    rightEdgePoints.append(point.location)
                }
            } else {
                // Middle point - use average direction
                let prevPoint = pressurePoints[i - 1]
                let nextPoint = pressurePoints[i + 1]
                
                let prevDirection = CGVector(dx: point.location.x - prevPoint.location.x, 
                                           dy: point.location.y - prevPoint.location.y)
                let nextDirection = CGVector(dx: nextPoint.location.x - point.location.x, 
                                           dy: nextPoint.location.y - point.location.y)
                
                let avgDirection = CGVector(dx: (prevDirection.dx + nextDirection.dx) / 2, 
                                          dy: (prevDirection.dy + nextDirection.dy) / 2)
                let length = sqrt(avgDirection.dx * avgDirection.dx + avgDirection.dy * avgDirection.dy)
                
                if length > 0 {
                    let normalizedDirection = CGVector(dx: avgDirection.dx / length, dy: avgDirection.dy / length)
                    let perpendicular = CGVector(dx: -normalizedDirection.dy, dy: normalizedDirection.dx)
                    
                    leftEdgePoints.append(CGPoint(x: point.location.x + perpendicular.dx * thickness,
                                                y: point.location.y + perpendicular.dy * thickness))
                    rightEdgePoints.append(CGPoint(x: point.location.x - perpendicular.dx * thickness,
                                                 y: point.location.y - perpendicular.dy * thickness))
                } else {
                    leftEdgePoints.append(point.location)
                    rightEdgePoints.append(point.location)
                }
            }
        }
        
        // Create the filled path by connecting left and right edges
        if leftEdgePoints.count >= 2 && rightEdgePoints.count >= 2 {
            path.move(to: leftEdgePoints[0])
            
            // Draw left edge
            for i in 1..<leftEdgePoints.count {
                path.addLine(to: leftEdgePoints[i])
            }
            
            // Draw right edge in reverse
            for i in (0..<rightEdgePoints.count).reversed() {
                path.addLine(to: rightEdgePoints[i])
            }
            
            path.closeSubpath()
        }
        
        return path
    }
    
    // MARK: - Current Pressure Section
    
    private var currentPressureSection: some View {
        VStack(spacing: 6) {
            Text("Current (0-1)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            let rawPressure = pressureManager.isCalibrating ? pressureManager.currentPressure : 0.0
            Text(String(format: "%.3f", rawPressure))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .monospaced()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Pressure Range Section
    
    private var pressureRangeSection: some View {
        VStack(spacing: 8) {
            Text("Range (0-1)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    let rawMin = pressureManager.isCalibrating ? pressureManager.calibrationMinPressure : 0.0
                    Text(String(format: "%.3f", rawMin))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .monospaced()
                }
                
                VStack(spacing: 2) {
                    Text("Max")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    let rawMax = pressureManager.isCalibrating ? pressureManager.calibrationMaxPressure : 0.0
                    Text(String(format: "%.3f", rawMax))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .monospaced()
                }
                
                VStack(spacing: 2) {
                    Text("Samples")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(pressureManager.calibrationSampleCount)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .monospaced()
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Pressure Visualization Section
    
    private var pressureVisualizationSection: some View {
        VStack(spacing: 12) {
            Text("Pressure Visualization")
                .font(.headline)
            
            VStack(spacing: 8) {
                // Current pressure bar
                HStack {
                    Text("Current:")
                        .font(.caption)
                        .frame(width: 60, alignment: .trailing)
                    
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: barMaxWidth, height: 20)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: currentPressureBarWidth, height: 20)
                            .animation(.easeInOut(duration: 0.1), value: currentPressureBarWidth)
                    }
                    .cornerRadius(4)
                }
                
                // Minimum pressure bar
                HStack {
                    Text("Min:")
                        .font(.caption)
                        .frame(width: 60, alignment: .trailing)
                    
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: barMaxWidth, height: 15)
                        
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: minPressureBarWidth, height: 15)
                    }
                    .cornerRadius(4)
                }
                
                // Maximum pressure bar
                HStack {
                    Text("Max:")
                        .font(.caption)
                        .frame(width: 60, alignment: .trailing)
                    
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: barMaxWidth, height: 15)
                        
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: maxPressureBarWidth, height: 15)
                    }
                    .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Event Log Section
    
    private var eventLogSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Event Log")
                    .font(.headline)
                
                Spacer()
                
                Button("Clear") {
                    eventLog.removeAll()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(eventLog, id: \.self) { logEntry in
                        Text(logEntry)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(height: 80)
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .border(Color.gray.opacity(0.3), width: 1)
            .cornerRadius(4)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Control Buttons Section
    
    private var controlButtonsSection: some View {
        HStack(spacing: 12) {
            // Tablet Only toggle
            HStack(spacing: 6) {
                Image(systemName: tabletOnlyMode ? "checkmark.square.fill" : "square")
                    .foregroundColor(tabletOnlyMode ? .blue : .gray)
                    .onTapGesture {
                        tabletOnlyMode.toggle()
                        pressureManager.tabletOnlyCalibration = tabletOnlyMode
                    }
                
                Text("Tablet Only")
                    .font(.caption)
                    .onTapGesture {
                        tabletOnlyMode.toggle()
                        pressureManager.tabletOnlyCalibration = tabletOnlyMode
                    }
            }
            
            // Start/Stop button
            Button(action: {
                if pressureManager.isCalibrating {
                    pressureManager.stopCalibration()
                } else {
                    pressureManager.startCalibration()
                }
            }) {
                Text(pressureManager.isCalibrating ? "Stop" : "Start")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(pressureManager.isCalibrating ? Color.red : Color.blue)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Reset button
            Button(action: {
                pressureManager.resetCalibration()
                pressureManager.calibrationMinPressure = 0.0
                pressureManager.calibrationMaxPressure = 0.0
                addEventToLog("Reset calibration data - Min and Max set to 0.0")
            }) {
                Text("Reset")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Clear Canvas button
            Button(action: {
                clearCanvas()
            }) {
                Text("Clear Canvas")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Close Function
    
    private func closeCalibration() {
        print("🎨 CALIBRATION: Closing calibration window")
        
        // Stop calibration if it's running
        if pressureManager.isCalibrating {
            pressureManager.stopCalibration()
            print("🎨 CALIBRATION: Stopped calibration before closing")
        }
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
        print("🎨 CALIBRATION: Calibration window dismissed")
    }
    
    // MARK: - Event Detection Helper
    
    private func addEventToLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            eventLog.insert(logEntry, at: 0)
            if eventLog.count > maxEventLogEntries {
                eventLog.removeLast()
            }
        }
    }
    
    // MARK: - Visualization Update
    
    private func updateVisualization() {
        // Calculate bar widths based on raw pressure values (0 to 1.0 range)
        let rawCurrentPressure = pressureManager.isCalibrating ? pressureManager.currentPressure : 0.0
        let rawMinPressure = pressureManager.isCalibrating ? pressureManager.calibrationMinPressure : 0.0
        let rawMaxPressure = pressureManager.isCalibrating ? pressureManager.calibrationMaxPressure : 0.0
        
        // Scale to 0-1 for visualization (pressure is already 0-1)
        currentPressureBarWidth = CGFloat(rawCurrentPressure) * barMaxWidth
        minPressureBarWidth = CGFloat(rawMinPressure) * barMaxWidth
        maxPressureBarWidth = CGFloat(rawMaxPressure) * barMaxWidth
    }
}

// MARK: - PressurePoint Struct

struct PressurePoint {
    let location: CGPoint
    let pressure: Double
}

// MARK: - VariableStrokePath Struct

struct VariableStrokePath {
    var points: [PressurePoint]
    var path: Path = Path()
}

// MARK: - Preview

#Preview {
    PressureCalibrationView()
}
