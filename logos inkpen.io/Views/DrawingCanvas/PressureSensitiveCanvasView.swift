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
    var onPressureEvent: ((CGPoint, Double, PressureEventType, Bool) -> Void)?
    
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
        
        let isTabletEvent = (event.subtype == .tabletPoint)
        onPressureEvent?(canvasLocation, pressure, .began, isTabletEvent)
        
        print("🎨 PRESSURE: Mouse down - pressure: \(pressure), subtype: \(event.subtype.rawValue), tablet: \(isTabletEvent)")
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        
        let isTabletEvent = (event.subtype == .tabletPoint)
        onPressureEvent?(canvasLocation, pressure, .changed, isTabletEvent)
        
        super.mouseDragged(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        
        let isTabletEvent = (event.subtype == .tabletPoint)
        onPressureEvent?(canvasLocation, pressure, .ended, isTabletEvent)
        
        isDragging = false
        print("🎨 PRESSURE: Mouse up - final pressure: \(pressure)")
        super.mouseUp(with: event)
    }
    
    override func pressureChange(with event: NSEvent) {
        guard isDragging else { return }
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        
        // This handles trackpad pressure changes (never tablet events)
        onPressureEvent?(canvasLocation, pressure, .changed, false)
        
        print("🎨 PRESSURE: Pressure change - pressure: \(pressure)")
        super.pressureChange(with: event)
    }
    
    // MARK: - Tablet Event Handling (Apple Pencil)
    
    override func tabletPoint(with event: NSEvent) {
        let currentLocation = convert(event.locationInWindow, from: nil)
        let pressure = extractPressure(from: event)
        let canvasLocation = convertToCanvasCoordinates(currentLocation)
        
        // Determine event type based on current state and pressure
        let eventType: PressureEventType
        if !isDragging && pressure > 0.1 {
            // Starting a new stroke
            isDragging = true
            eventType = .began
            startLocation = currentLocation
        } else if isDragging && pressure <= 0.1 {
            // Ending the stroke
            isDragging = false
            eventType = .ended
        } else {
            // Continuing the stroke
            eventType = .changed
        }
        
        onPressureEvent?(canvasLocation, pressure, eventType, true) // Always tablet event
        
        print("🎨 TABLET: Tablet point - pressure: \(pressure), type: \(eventType)")
        super.tabletPoint(with: event)
    }
    
    override func tabletProximity(with event: NSEvent) {
        if event.isEnteringProximity {
            print("🎨 TABLET: Apple Pencil entering proximity")
        } else {
            print("🎨 TABLET: Apple Pencil leaving proximity")
            // End any current drawing when stylus leaves proximity
            if isDragging {
                isDragging = false
                let canvasLocation = convertToCanvasCoordinates(startLocation)
                onPressureEvent?(canvasLocation, 0.1, .ended, true) // Tablet proximity end
            }
        }
        super.tabletProximity(with: event)
    }
    
    // MARK: - Pressure Extraction
    
    private func extractPressure(from event: NSEvent) -> Double {
        var pressure: Double = 1.0
        var foundRealPressure = false
        
        // Try to get real pressure data based on event type and subtype
        switch event.type {
        case .tabletPoint:
            // Native tablet events (Apple Pencil, Wacom, etc.)
            pressure = Double(event.pressure)
            foundRealPressure = true
            print("🎨 PRESSURE: Tablet point pressure: \(pressure)")
            
        case .leftMouseDown, .leftMouseDragged, .leftMouseUp:
            // Check if this is a tablet event disguised as a mouse event
            if event.subtype == .tabletPoint {
                // Apple Pencil events often come as mouse events with tablet subtype
                pressure = Double(event.pressure)
                foundRealPressure = true
                print("🎨 PRESSURE: Tablet subtype pressure: \(pressure)")
            } else if event.pressure > 0.0 && event.pressure != 1.0 {
                // Regular trackpad pressure
                pressure = Double(event.pressure)
                foundRealPressure = true
                print("🎨 PRESSURE: Mouse/trackpad pressure: \(pressure)")
            } else {
                pressure = 1.0
            }
            
        case .pressure:
            // Trackpad pressure change events (relative to baseline pressure)
            pressure = 1.0 + Double(event.pressure)
            foundRealPressure = true
            print("🎨 PRESSURE: Pressure change event: 1.0 + \(event.pressure) = \(pressure)")
            
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
    let onPressureEvent: (CGPoint, Double, PressureSensitiveCanvasView.PressureEventType, Bool) -> Void
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