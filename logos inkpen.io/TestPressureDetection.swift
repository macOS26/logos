//
//  TestPressureDetection.swift
//  logos inkpen.io
//
//  Test file to verify Apple Pencil pressure detection
//

import SwiftUI

struct TestPressureDetection: View {
    @State private var pressureValue: Double = 1.0
    @State private var hasPressureSupport: Bool = false
    @State private var lastLocation: CGPoint = .zero
    
    var body: some View {
        VStack {
            Text("Pressure Detection Test")
                .font(.title)
                .padding()
            
            HStack {
                Text("Pressure Support:")
                Text(hasPressureSupport ? "✅ Detected" : "❌ Not Available")
                    .foregroundColor(hasPressureSupport ? .green : .red)
            }
            .padding()
            
            HStack {
                Text("Current Pressure:")
                Text(String(format: "%.2f", pressureValue))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding()
            
            // Pressure visualization
            Circle()
                .fill(Color.blue)
                .frame(width: 50 + (pressureValue * 100), height: 50 + (pressureValue * 100))
                .animation(.easeInOut(duration: 0.1), value: pressureValue)
                .padding()
            
            Text("Draw with Apple Pencil on the area below to test pressure")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
            
            // Test area
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .border(Color.gray, width: 1)
                
                PressureSensitiveCanvasRepresentable(
                    onPressureEvent: { location, pressure, eventType in
                        DispatchQueue.main.async {
                            self.pressureValue = pressure
                            self.lastLocation = location
                            
                            if eventType == .began || eventType == .changed {
                                self.hasPressureSupport = true
                            }
                            
                            print("🎨 TEST: Pressure: \(pressure), Location: \(location), Event: \(eventType)")
                        }
                    },
                    hasPressureSupport: $hasPressureSupport
                )
            }
            .frame(height: 300)
            .padding()
            
            Text("Last Location: (\(String(format: "%.1f", lastLocation.x)), \(String(format: "%.1f", lastLocation.y)))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .onAppear {
            // Initialize pressure manager
            hasPressureSupport = PressureManager.shared.hasRealPressureInput
            pressureValue = PressureManager.shared.currentPressure
        }
    }
}

#Preview {
    TestPressureDetection()
}