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
    
    private let barMaxWidth: CGFloat = 300
    private let maxPressureValue: Double = 2.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header section
                VStack(spacing: 16) {
                    Text("Apple Pencil Pressure Calibration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        Text("Connect your iPad via Sidecar and use your Apple Pencil on the main drawing canvas to test pressure range.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Apply varying pressure from lightest touch to heaviest press.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if tabletOnlyMode {
                            Text("🎯 Tablet/Stylus Mode: Only detecting Apple Pencil and stylus events (via NSTabletPoint)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.center)
                        }
                        
                        Text("Expected: Apple Pencil generates NSTabletPoint events or mouse events with NSTabletPointEventSubtype")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                }
                
                // Device support status
                statusSection
                
                // Current pressure display
                currentPressureSection
                
                // Min/Max pressure tracking
                pressureRangeSection
                
                // Pressure visualization bars
                pressureVisualizationSection
                
                // Control buttons
                controlButtonsSection
                
                Spacer()
            }
            .padding()
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
        .frame(width: 450, height: 600)
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