//
//  PressureManager.swift
//  logos inkpen.io
//
//  Manages pressure detection and fallback simulation
//

import SwiftUI
import Combine

/// Manages pressure detection with smart fallback to simulation
class PressureManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether real pressure input is available and detected
    @Published var hasRealPressureInput = false
    
    /// Current pressure value (raw from input device)
    @Published var currentPressure: Double = 1.0
    
    /// Calibration tracking - whether calibration is active
    @Published var isCalibrating = false
    
    /// Minimum pressure recorded during calibration
    @Published var calibrationMinPressure: Double = 0.0
    
    /// Maximum pressure recorded during calibration  
    @Published var calibrationMaxPressure: Double = 0.0
    
    /// Number of pressure samples recorded during calibration
    @Published var calibrationSampleCount: Int = 0
    
    /// Whether to only track tablet/stylus events during calibration
    @Published var tabletOnlyCalibration: Bool = true
    
    // MARK: - Private Properties

    /// Tracks points for simulation fallback
    private var lastLocation: CGPoint?
    private var lastTimestamp: Date?

    /// Debug tracking for pressure changes
    private var lastRecordedPressure: Double?

    /// Track recent pressure values to detect if "real pressure" is actually constant
    private var recentPressureValues: [Double] = []
    private let pressureHistorySize = 10
    private let pressureVariationThreshold = 0.01

    /// Speed-based pressure simulation parameters
    private let maxSpeed: Double = 100.0
    private let speedSmoothingFactor: Double = 0.3
    
    // MARK: - Initialization
    
    init() {
        detectInitialPressureSupport()
    }
    
    // MARK: - Pressure Detection
    
    private func detectInitialPressureSupport() {
        // Check if the system supports pressure by checking available input devices
        // We'll detect this more accurately when we actually receive pressure events
        hasRealPressureInput = false // Start as false, will be updated when real events detected
    }
    
    /// Updates pressure support status based on actual events
    func updatePressureSupport(_ isSupported: Bool) {
        DispatchQueue.main.async {
            self.hasRealPressureInput = isSupported
        }
    }
    
    // MARK: - Pressure Processing
    
    /// Processes pressure from real input events
    func processRealPressure(_ pressure: Double, at location: CGPoint, timestamp: Date = Date(), isTabletEvent: Bool = false) {
        // Always process real pressure - the pressure curve will handle whether to apply it

        // If in tablet-only calibration mode, ignore non-tablet events during calibration
        if isCalibrating && tabletOnlyCalibration && !isTabletEvent {
            return
        }

        // Track pressure variation to detect constant "fake" pressure (like trackpad)
        recentPressureValues.append(pressure)
        if recentPressureValues.count > pressureHistorySize {
            recentPressureValues.removeFirst()
        }

        // Only mark as real pressure input if values actually vary (not constant like mouse/trackpad)
        if recentPressureValues.count >= pressureHistorySize && !isPressureConstant() {
            if !hasRealPressureInput {
                hasRealPressureInput = true
            }
        } else if recentPressureValues.count >= pressureHistorySize && isPressureConstant() {
            if hasRealPressureInput {
                hasRealPressureInput = false
            }
        }

        // Use raw pressure directly - NO CLAMPING - SYNCHRONOUS UPDATE TO AVOID RACE CONDITION
        if Thread.isMainThread {
            self.currentPressure = pressure // Raw 0.0-1.0 pressure
        } else {
            DispatchQueue.main.sync {
                self.currentPressure = pressure // Raw 0.0-1.0 pressure
            }
        }

        // Update tracking for hybrid scenarios
        lastLocation = location
        lastTimestamp = timestamp

        // Update calibration if active
        if isCalibrating {
            updateCalibrationData(pressure: pressure, isTabletEvent: isTabletEvent)
        }

        // Debug output for pressure changes (only log significant changes to avoid spam)
        if let lastPressure = lastRecordedPressure, abs(pressure - lastPressure) > 0.1 {
            lastRecordedPressure = pressure
        } else if lastRecordedPressure == nil {
            lastRecordedPressure = pressure
        }
    }
    
    /// Simulates pressure based on drawing speed when real pressure unavailable
    func processSimulatedPressure(at location: CGPoint, sensitivity: Double = 0.5, timestamp: Date = Date()) -> Double {
        // Always calculate speed-based pressure simulation
        // The pressure curve will handle whether to apply sensitivity or flatten to 1.0
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

        // Use sensitivity to control the pressure range
        // Higher sensitivity = more variation, lower sensitivity = flatter response
        let pressureRange = sensitivity // Use sensitivity directly as range multiplier
        let basePressure = 1.0 - (normalizedSpeed * pressureRange)

        // Clamp to 0.1-1.0 range
        let finalPressure = max(0.1, min(1.0, basePressure))

        // Smooth the pressure transition
        let smoothedPressure = (currentPressure * (1.0 - speedSmoothingFactor)) + (finalPressure * speedSmoothingFactor)

        return smoothedPressure
    }
    
    // MARK: - Pressure Variation Detection

    /// Checks if recent pressure values are constant (like trackpad 1.0)
    private func isPressureConstant() -> Bool {
        guard recentPressureValues.count >= pressureHistorySize else {
            return false // Not enough data yet
        }

        let minPressure = recentPressureValues.min() ?? 0
        let maxPressure = recentPressureValues.max() ?? 0
        let variation = maxPressure - minPressure

        return variation < pressureVariationThreshold
    }

    // MARK: - Reset Methods

    /// Resets pressure state for new drawing
    func resetForNewDrawing() {
        lastLocation = nil
        lastTimestamp = nil
        lastRecordedPressure = nil
        currentPressure = 1.0
        recentPressureValues.removeAll()
    }

    /// Gets pressure for a specific point in a drawing operation
    func getPressure(for location: CGPoint, sensitivity: Double = 0.5) -> Double {
        if hasRealPressureInput {
            // Check if "real pressure" is actually constant (like trackpad sending 1.0)
            if isPressureConstant() {
                // Constant pressure detected - use simulated pressure for variation
                return processSimulatedPressure(at: location, sensitivity: sensitivity)
            } else {
                // Real varying pressure - use it directly
                return currentPressure
            }
        } else {
            // Fall back to simulation
            return processSimulatedPressure(at: location, sensitivity: sensitivity)
        }
    }
    
    // MARK: - Pressure Calibration
    
    /// Starts pressure calibration tracking
    func startCalibration() {
        DispatchQueue.main.async {
            self.isCalibrating = true
            self.calibrationMinPressure = 0.0
            self.calibrationMaxPressure = 0.0
            self.calibrationSampleCount = 0
        }
    }
    
    /// Stops pressure calibration tracking
    func stopCalibration() {
        DispatchQueue.main.async {
            self.isCalibrating = false
        }
    }
    
    /// Resets calibration data
    func resetCalibration() {
        DispatchQueue.main.async {
            self.calibrationMinPressure = 0.0
            self.calibrationMaxPressure = 0.0
            self.calibrationSampleCount = 0
        }
    }
    
    /// Updates calibration tracking with new pressure value
    private func updateCalibrationData(pressure: Double, isTabletEvent: Bool = false) {
        DispatchQueue.main.async {
            self.calibrationSampleCount += 1
        }
    }
}

// MARK: - Global Pressure Manager Instance

/// Shared pressure manager instance
extension PressureManager {
    static let shared = PressureManager()
}
