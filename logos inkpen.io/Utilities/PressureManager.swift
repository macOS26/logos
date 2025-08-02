//
//  PressureManager.swift
//  logos inkpen.io
//
//  Manages pressure detection and fallback simulation
//

import Foundation
import AppKit

/// Manages pressure detection with smart fallback to simulation
class PressureManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether real pressure input is available and detected
    @Published var hasRealPressureInput = false
    
    /// Current pressure value (0.1 to 2.0)
    @Published var currentPressure: Double = 1.0
    
    /// Whether pressure sensitivity is enabled by user
    @Published var pressureSensitivityEnabled = true
    
    // MARK: - Private Properties
    
    /// Tracks points for simulation fallback
    private var lastLocation: CGPoint?
    private var lastTimestamp: Date?
    
    /// Speed-based pressure simulation parameters
    private let maxSpeed: Double = 100.0
    private let speedSmoothingFactor: Double = 0.3
    
    // MARK: - Initialization
    
    init() {
        detectInitialPressureSupport()
    }
    
    // MARK: - Pressure Detection
    
    private func detectInitialPressureSupport() {
        hasRealPressureInput = NSEvent.pressureSupported
        print("🎨 PRESSURE MANAGER: Initial detection - hasRealPressureInput: \(hasRealPressureInput)")
    }
    
    /// Updates pressure support status based on actual events
    func updatePressureSupport(_ isSupported: Bool) {
        DispatchQueue.main.async {
            self.hasRealPressureInput = isSupported
            print("🎨 PRESSURE MANAGER: Updated pressure support: \(isSupported)")
        }
    }
    
    // MARK: - Pressure Processing
    
    /// Processes pressure from real input events
    func processRealPressure(_ pressure: Double, at location: CGPoint, timestamp: Date = Date()) {
        guard pressureSensitivityEnabled else {
            currentPressure = 1.0
            return
        }
        
        // Real pressure is already in good range, just clamp it
        let clampedPressure = max(0.1, min(2.0, pressure))
        
        DispatchQueue.main.async {
            self.currentPressure = clampedPressure
        }
        
        // Update tracking for hybrid scenarios
        lastLocation = location
        lastTimestamp = timestamp
    }
    
    /// Simulates pressure based on drawing speed when real pressure unavailable
    func processSimulatedPressure(at location: CGPoint, sensitivity: Double = 0.5, timestamp: Date = Date()) -> Double {
        guard pressureSensitivityEnabled else {
            return 1.0
        }
        
        // Calculate speed-based pressure simulation
        let simulatedPressure = calculateSimulatedPressure(at: location, timestamp: timestamp, sensitivity: sensitivity)
        
        DispatchQueue.main.async {
            self.currentPressure = simulatedPressure
        }
        
        return simulatedPressure
    }
    
    private func calculateSimulatedPressure(at location: CGPoint, timestamp: Date, sensitivity: Double) -> Double {
        defer {
            lastLocation = location
            lastTimestamp = timestamp
        }
        
        // Need previous point for speed calculation
        guard let lastLoc = lastLocation, let lastTime = lastTimestamp else {
            return 1.0
        }
        
        // Calculate drawing speed
        let distance = sqrt(pow(location.x - lastLoc.x, 2) + pow(location.y - lastLoc.y, 2))
        let timeInterval = timestamp.timeIntervalSince(lastTime)
        
        guard timeInterval > 0 else { return currentPressure } // Keep current pressure for same timestamp
        
        let speed = distance / timeInterval
        
        // Convert speed to pressure (fast = light, slow = heavy)
        let normalizedSpeed = min(speed / maxSpeed, 1.0)
        let basePressure = 1.0 - (normalizedSpeed * 0.5) // Reduce pressure with speed
        
        // Apply sensitivity
        let pressureVariation = (basePressure - 0.5) * sensitivity
        let finalPressure = 0.5 + pressureVariation
        
        // Smooth the pressure transition
        let smoothedPressure = (currentPressure * (1.0 - speedSmoothingFactor)) + (finalPressure * speedSmoothingFactor)
        
        return max(0.1, min(2.0, smoothedPressure))
    }
    
    // MARK: - Reset Methods
    
    /// Resets pressure state for new drawing
    func resetForNewDrawing() {
        lastLocation = nil
        lastTimestamp = nil
        currentPressure = 1.0
    }
    
    /// Gets pressure for a specific point in a drawing operation
    func getPressure(for location: CGPoint, sensitivity: Double = 0.5) -> Double {
        if hasRealPressureInput {
            // When real pressure is available, currentPressure is updated by real events
            return currentPressure
        } else {
            // Fall back to simulation
            return processSimulatedPressure(at: location, sensitivity: sensitivity)
        }
    }
}

// MARK: - Global Pressure Manager Instance

/// Shared pressure manager instance
extension PressureManager {
    static let shared = PressureManager()
}
