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
        // Enable pressure-sensitive input tracking
        wantsPressure = true
        
        // Test if pressure is available by checking system capabilities
        detectPressureSupport()
    }
    
    private func detectPressureSupport() {
        // Check if we're running on a system that supports pressure
        // This is a heuristic - we'll also test during actual events
        if NSEvent.pressureSupported {
            hasPressureSupport = true
            print("🎨 PRESSURE: System reports pressure support available")
        } else {
            hasPressureSupport = false
            print("🎨 PRESSURE: System reports no pressure support - will use simulation")
        }
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
        
        // Try to get real pressure data
        switch event.type {
        case .leftMouseDown:
            // For mouse down, pressure is typically 1.0
            pressure = 1.0
            hasPressureSupport = true // We got a real event
            
        case .leftMouseDragged:
            // For drag events, pressure might be available
            if event.pressure > 0.0 {
                pressure = Double(event.pressure)
                hasPressureSupport = true
            } else {
                pressure = 1.0 // Fallback for non-pressure devices
            }
            
        case .pressure:
            // This is the real Apple Pencil pressure event!
            pressure = 1.0 + Double(event.pressure)
            hasPressureSupport = true
            print("🎨 PRESSURE: Real pressure event detected: \(pressure)")
            
        default:
            pressure = 1.0
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