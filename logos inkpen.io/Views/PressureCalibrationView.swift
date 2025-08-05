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
    
    // Event logging for real-time display
    @State private var eventLog: [String] = []
    @State private var maxEventLogEntries: Int = 20
    
    private let barMaxWidth: CGFloat = 300
    private let maxPressureValue: Double = 2.0
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                // Header section
                VStack(spacing: 12) {
                    Text("Apple Pencil Pressure Calibration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        Text("Use the test canvas below to test pressure sensitivity with any device.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Draw with Apple Pencil, trackpad, or mouse to test pressure range.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if tabletOnlyMode {
                            Text("🎯 Tablet/Stylus Mode: Only detecting Apple Pencil and stylus events (via NSTabletPoint)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("Raw pressure values from input devices (varies by device and OS)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                }
                
                // Pressure-sensitive test canvas
                pressureTestCanvas
                
                // Device support status
                statusSection
                
                // Current pressure display
                currentPressureSection
                
                // Min/Max pressure tracking
                pressureRangeSection
                
                // Pressure visualization bars
                pressureVisualizationSection
                
                // Event log section
                eventLogSection
                
                // Control buttons
                controlButtonsSection
                }
                .padding()
            }
            .navigationTitle("Pressure Calibration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if pressureManager.isCalibrating {
                            pressureManager.stopCalibration()
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(
            minWidth: 550, idealWidth: 650, maxWidth: 800,
            minHeight: 900, idealHeight: 1100, maxHeight: 1400
        )
        .onAppear {
            updateVisualization()
            // Sync the UI toggle with the pressure manager
            pressureManager.tabletOnlyCalibration = tabletOnlyMode
        }
        .onChange(of: pressureManager.currentPressure) {
            updateVisualization()
        }
        .onChange(of: pressureManager.calibrationMinPressure) {
            updateVisualization()
        }
        .onChange(of: pressureManager.calibrationMaxPressure) {
            updateVisualization()
        }
        .onAppear {
            // Start monitoring for all pressure events
            addEventToLog("Calibration tool opened - monitoring ALL pressure events")
            addEventToLog("Waiting for input from any device (trackpad, Apple Pencil, mouse)")
        }
    }
    
    // MARK: - Pressure Test Canvas
    
    private var pressureTestCanvas: some View {
        VStack(spacing: 8) {
            Text("Test Canvas - Draw here to test pressure")
                .font(.headline)
            
            ZStack {
                // Background
                Rectangle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .border(Color.gray.opacity(0.3), width: 1)
                
                // Pressure-sensitive canvas with comprehensive event detection
                PressureSensitiveCanvasRepresentable(
                    onPressureEvent: { location, pressure, eventType, isTabletEvent in
                        print("🎨 CALIBRATION CANVAS: Event received - type: \(eventType), pressure: \(pressure), tablet: \(isTabletEvent)")
                        print("🎨 CALIBRATION CANVAS: Location: (\(location.x), \(location.y))")
                        
                        // Update pressure manager
                        pressureManager.processRealPressure(pressure, at: location, isTabletEvent: isTabletEvent)
                        
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
                .frame(height: 280)
                
                // Instructions overlay
                VStack {
                    Text("Draw here with your device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("(Apple Pencil, trackpad, or mouse)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.black.opacity(0.1))
                .cornerRadius(4)
            }
            .frame(height: 280)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: pressureManager.hasRealPressureInput ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(pressureManager.hasRealPressureInput ? .green : .orange)
                .font(.title3)
            
            VStack(alignment: .leading) {
                Text(pressureManager.hasRealPressureInput ? "Pressure Input Detected" : "No Pressure Input")
                    .font(.headline)
                    .foregroundColor(pressureManager.hasRealPressureInput ? .green : .orange)
                
                Text(pressureManager.hasRealPressureInput ? 
                     "Your device supports real pressure sensitivity" :
                     "Draw on the canvas to detect pressure support")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Current Pressure Section
    
    private var currentPressureSection: some View {
        VStack(spacing: 8) {
            Text("Current Pressure")
                .font(.headline)
            
            Text(String(format: "%.3f", pressureManager.currentPressure))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .monospaced()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Pressure Range Section
    
    private var pressureRangeSection: some View {
        VStack(spacing: 16) {
            Text("Recorded Range")
                .font(.headline)
            
            HStack(spacing: 40) {
                VStack {
                    Text("Minimum")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.3f", pressureManager.calibrationMinPressure))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .monospaced()
                }
                
                VStack {
                    Text("Maximum")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.3f", pressureManager.calibrationMaxPressure))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .monospaced()
                }
                
                VStack {
                    Text("Samples")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(pressureManager.calibrationSampleCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .monospaced()
                }
            }
        }
        .padding()
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
            .frame(height: 120)
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
        VStack(spacing: 16) {
            // Mode toggle
            HStack(spacing: 12) {
                Image(systemName: tabletOnlyMode ? "checkmark.square.fill" : "square")
                    .foregroundColor(tabletOnlyMode ? .blue : .gray)
                    .onTapGesture {
                        tabletOnlyMode.toggle()
                        pressureManager.tabletOnlyCalibration = tabletOnlyMode
                    }
                
                Text("Tablet/Stylus Only Mode")
                    .font(.body)
                    .onTapGesture {
                        tabletOnlyMode.toggle()
                        pressureManager.tabletOnlyCalibration = tabletOnlyMode
                    }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Control buttons
            HStack(spacing: 16) {
                Button(action: {
                    if pressureManager.isCalibrating {
                        pressureManager.stopCalibration()
                    } else {
                        pressureManager.startCalibration()
                    }
                }) {
                    Text(pressureManager.isCalibrating ? "Stop Calibration" : "Start Calibration")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(pressureManager.isCalibrating ? Color.red : Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    pressureManager.resetCalibration()
                }) {
                    Text("Reset")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.gray)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!pressureManager.isCalibrating)
                
                Button(action: {
                    closeCalibration()
                }) {
                    Text("Close")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
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
        // Calculate bar widths based on pressure values (0.1 to 2.0 range)
        currentPressureBarWidth = CGFloat(pressureManager.currentPressure / maxPressureValue) * barMaxWidth
        minPressureBarWidth = CGFloat(pressureManager.calibrationMinPressure / maxPressureValue) * barMaxWidth
        maxPressureBarWidth = CGFloat(pressureManager.calibrationMaxPressure / maxPressureValue) * barMaxWidth
    }
}

// MARK: - Preview

#Preview {
    PressureCalibrationView()
}