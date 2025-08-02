//
//  PressureSensitiveCanvasView.swift
//  logos inkpen.io
//
//  Real Apple Pencil pressure detection for macOS
//

import SwiftUI
import AppKit

/// NSView that handles real Apple Pencil pressure events on macOS
class PressureSensitiveCanvasView: NSView {
    
    // MARK: - Pressure Detection Properties
    
    /// Callback for pressure events with location and pressure data
    var onPressureEvent: ((CGPoint, Double, PressureEventType) -> Void)?
    
    /// Whether this device/setup supports real pressure input
    private(set) var hasPressureSupport = false
    
    /// Current pressure state tracking
    private var isDragging = false
    private var startLocation: CGPoint = .zero
    
    // MARK: - Pressure Event Types
    
    enum PressureEventType {
        case began
        case changed
        case ended
    }
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupPressureDetection()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPressureDetection()
    }
    
    private func setupPressureDetection() {
        // We don't need to set wantsPressure - NSView handles pressure events automatically
        // when the system has pressure-sensitive input available
        
        // Test if pressure is available by checking system capabilities
        detectPressureSupport()
    }
    
    private func detectPressureSupport() {
        // We'll detect pressure support dynamically when we receive actual pressure events
        // Starting with false and updating when real pressure is detected
        hasPressureSupport = false
        print("🎨 PRESSURE: Will detect pressure support from actual events")
    }
    
    // MARK: - Mouse/Touch Event Handling
    
    override func mouseDown(with event: NSEvent) {
        startLocation = convert(event.locationInWindow, from: nil)
        isDragging = true
        
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(startLocation)
        
        onPressureEvent?(canvasLocation, pressure, .began)
        
        print("🎨 PRESSURE: Mouse down - pressure: \(pressure)")
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        
        onPressureEvent?(canvasLocation, pressure, .changed)
        
        super.mouseDragged(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        
        onPressureEvent?(canvasLocation, pressure, .ended)
        
        isDragging = false
        print("🎨 PRESSURE: Mouse up - final pressure: \(pressure)")
        super.mouseUp(with: event)
    }
    
    override func pressureChange(with event: NSEvent) {
        guard isDragging else { return }
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        
        // This is the key method for real Apple Pencil pressure!
        onPressureEvent?(canvasLocation, pressure, .changed)
        
        print("🎨 PRESSURE: Pressure change - pressure: \(pressure)")
        super.pressureChange(with: event)
    }
    
    // MARK: - Pressure Extraction
    
    private func extractPressure(from event: NSEvent) -> Double {
        var pressure: Double = 1.0
        var foundRealPressure = false
        
        // Try to get real pressure data
        switch event.type {
        case .leftMouseDown:
            // For mouse down, check if pressure is available
            if event.pressure > 0.0 && event.pressure != 1.0 {
                pressure = Double(event.pressure)
                foundRealPressure = true
                print("🎨 PRESSURE: Real pressure in mouse down: \(pressure)")
            } else {
                pressure = 1.0
            }
            
        case .leftMouseDragged:
            // For drag events, pressure might be available
            if event.pressure > 0.0 && event.pressure != 1.0 {
                pressure = Double(event.pressure)
                foundRealPressure = true
                print("🎨 PRESSURE: Real pressure in drag: \(pressure)")
            } else {
                pressure = 1.0 // Fallback for non-pressure devices
            }
            
        case .pressure:
            // This is the real Apple Pencil pressure event!
            // The pressure value in this event is the change, so we add it to base
            pressure = 1.0 + Double(event.pressure)
            foundRealPressure = true
            print("🎨 PRESSURE: Real pressure event detected: \(pressure)")
            
        default:
            pressure = 1.0
        }
        
        // Update pressure support status if we found real pressure
        if foundRealPressure && !hasPressureSupport {
            hasPressureSupport = true
            print("🎨 PRESSURE: Pressure support detected and enabled!")
        }
        
        // Clamp pressure to valid range
        return max(0.1, min(2.0, pressure))
    }
    
    private func convertToCanvasCoordinates(_ point: CGPoint) -> CGPoint {
        // Convert NSView coordinates to canvas coordinates
        // NSView has origin at bottom-left, but we want top-left
        return CGPoint(x: point.x, y: frame.height - point.y)
    }
}

/// SwiftUI wrapper for pressure-sensitive canvas
struct PressureSensitiveCanvasRepresentable: NSViewRepresentable {
    let onPressureEvent: (CGPoint, Double, PressureSensitiveCanvasView.PressureEventType) -> Void
    @Binding var hasPressureSupport: Bool
    
    func makeNSView(context: Context) -> PressureSensitiveCanvasView {
        let view = PressureSensitiveCanvasView()
        view.onPressureEvent = onPressureEvent
        return view
    }
    
    func updateNSView(_ nsView: PressureSensitiveCanvasView, context: Context) {
        nsView.onPressureEvent = onPressureEvent
        hasPressureSupport = nsView.hasPressureSupport
    }
}