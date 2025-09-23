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
        Log.info("🎨 PRESSURE MANAGER: Initial detection - will detect on first pressure event", category: .pressure)
    }
    
    /// Updates pressure support status based on actual events
    func updatePressureSupport(_ isSupported: Bool) {
        DispatchQueue.main.async {
            self.hasRealPressureInput = isSupported
            Log.info("🎨 PRESSURE MANAGER: Updated pressure support: \(isSupported)", category: .pressure)
        }
    }
    
    // MARK: - Pressure Processing
    
    /// Processes pressure from real input events
    func processRealPressure(_ pressure: Double, at location: CGPoint, timestamp: Date = Date(), isTabletEvent: Bool = false) {
        Log.info("🎨 PRESSURE MANAGER: processRealPressure called with pressure: \(pressure)", category: .pressure)
        Log.info("🎨 PRESSURE MANAGER: AppState pressure sensitivity enabled: \(AppState.shared.pressureSensitivityEnabled)", category: .pressure)
        
        guard AppState.shared.pressureSensitivityEnabled else {
            Log.info("🎨 PRESSURE MANAGER: Pressure sensitivity disabled, setting to 1.0", category: .pressure)
            currentPressure = 1.0
            return
        }
        
        Log.info("🎨 PRESSURE MANAGER: Pressure sensitivity enabled, processing pressure", category: .pressure)
        
        // If in tablet-only calibration mode, ignore non-tablet events during calibration
        if isCalibrating && tabletOnlyCalibration && !isTabletEvent {
            Log.info("🎨 CALIBRATION: Ignoring non-tablet event (tablet-only mode)", category: .pressure)
            return
        }
        
        // Mark that we have real pressure input
        if !hasRealPressureInput {
            hasRealPressureInput = true
            Log.info("🎨 PRESSURE MANAGER: ✅ Real pressure input detected and enabled!", category: .pressure)
        }
        
        // Real pressure is already in good range, just clamp it
        let clampedPressure = max(0.0, min(2.0, pressure))
        
        DispatchQueue.main.async {
            self.currentPressure = clampedPressure
            Log.info("🎨 PRESSURE MANAGER: Updated currentPressure to: \(clampedPressure)", category: .pressure)
        }
        
        // Update tracking for hybrid scenarios
        lastLocation = location
        lastTimestamp = timestamp
        
        // Update calibration if active
        if isCalibrating {
            updateCalibrationData(pressure: clampedPressure, isTabletEvent: isTabletEvent)
        }
        
        // Debug output for pressure changes (only log significant changes to avoid spam)
        if let lastPressure = lastRecordedPressure, abs(pressure - lastPressure) > 0.1 {
            let eventType = isTabletEvent ? "TABLET" : "TRACKPAD"
            Log.info("🎨 \(eventType): \(String(format: "%.3f", pressure)) at (\(Int(location.x)), \(Int(location.y)))", category: .pressure)
            lastRecordedPressure = pressure
        } else if lastRecordedPressure == nil {
            lastRecordedPressure = pressure
            let eventType = isTabletEvent ? "TABLET" : "TRACKPAD"
            Log.info("🎨 \(eventType): First pressure reading: \(String(format: "%.3f", pressure))", category: .pressure)
        }
    }
    
    /// Simulates pressure based on drawing speed when real pressure unavailable
    func processSimulatedPressure(at location: CGPoint, sensitivity: Double = 0.5, timestamp: Date = Date()) -> Double {
        guard AppState.shared.pressureSensitivityEnabled else {
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
        
        return max(0.0, min(2.0, smoothedPressure))
    }
    
    // MARK: - Reset Methods
    
    /// Resets pressure state for new drawing
    func resetForNewDrawing() {
        lastLocation = nil
        lastTimestamp = nil
        lastRecordedPressure = nil
        currentPressure = 1.0
        Log.info("🎨 PRESSURE MANAGER: Reset for new stroke", category: .pressure)
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
    
    // MARK: - Pressure Calibration
    
    /// Starts pressure calibration tracking
    func startCalibration() {
        DispatchQueue.main.async {
            self.isCalibrating = true
            self.calibrationMinPressure = 0.0
            self.calibrationMaxPressure = 0.0
            self.calibrationSampleCount = 0
            Log.info("🎨 CALIBRATION: Started pressure calibration", category: .pressure)
        }
    }
    
    /// Stops pressure calibration tracking
    func stopCalibration() {
        DispatchQueue.main.async {
            self.isCalibrating = false
            Log.info("🎨 CALIBRATION: Stopped pressure calibration", category: .pressure)
            Log.info("🎨 CALIBRATION: Final range: \(String(format: "%.3f", self.calibrationMinPressure)) - \(String(format: "%.3f", self.calibrationMaxPressure))", category: .pressure)
            Log.info("🎨 CALIBRATION: Total samples: \(self.calibrationSampleCount)", category: .pressure)
        }
    }
    
    /// Resets calibration data
    func resetCalibration() {
        DispatchQueue.main.async {
            self.calibrationMinPressure = 0.0
            self.calibrationMaxPressure = 0.0
            self.calibrationSampleCount = 0
            Log.info("🎨 CALIBRATION: Reset calibration data to 0.0", category: .pressure)
        }
    }
    
    /// Updates calibration tracking with new pressure value
    private func updateCalibrationData(pressure: Double, isTabletEvent: Bool = false) {
        DispatchQueue.main.async {
            if pressure < self.calibrationMinPressure {
                self.calibrationMinPressure = pressure
                let eventType = isTabletEvent ? "TABLET" : "TRACKPAD"
                Log.info("🎨 CALIBRATION (\(eventType)): New minimum pressure: \(String(format: "%.3f", pressure))", category: .pressure)
            }
            if pressure > self.calibrationMaxPressure {
                self.calibrationMaxPressure = pressure
                let eventType = isTabletEvent ? "TABLET" : "TRACKPAD"
                Log.info("🎨 CALIBRATION (\(eventType)): New maximum pressure: \(String(format: "%.3f", pressure))", category: .pressure)
            }
            self.calibrationSampleCount += 1
        }
    }
}

// MARK: - Global Pressure Manager Instance

/// Shared pressure manager instance
extension PressureManager {
    static let shared = PressureManager()
}
