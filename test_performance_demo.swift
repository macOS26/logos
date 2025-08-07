#!/usr/bin/env swift

import SwiftUI

// Simple demo to test Metal pseudo-object performance monitoring
struct PerformanceDemoApp: App {
    var body: some Scene {
        WindowGroup {
            PerformanceDemoView()
                .frame(minWidth: 800, minHeight: 600)
        }
    }
}

struct PerformanceDemoView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor()
    @State private var animationOffset: CGFloat = 0
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.05)
            
            // Main content with performance monitoring
            SafeMetalView { cgContext, size in
                drawAnimatedContent(cgContext: cgContext, size: size)
            }
            
            // Performance overlay
            VStack {
                HStack {
                    Spacer()
                    PerformanceOverlay(performanceMonitor: performanceMonitor)
                        .padding()
                }
                Spacer()
                
                // Controls
                HStack {
                    Button(isAnimating ? "Stop Animation" : "Start Animation") {
                        isAnimating.toggle()
                    }
                    .padding()
                    
                    Text("Triple-tap to toggle stats")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .navigationTitle("Metal Performance Demo")
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            if isAnimating {
                animationOffset += 2.0
                if animationOffset > 400 {
                    animationOffset = -100
                }
            }
        }
    }
    
    private func drawAnimatedContent(cgContext: CGContext, size: CGSize) {
        // Reset draw stats for this frame
        performanceMonitor.resetDrawingStats()
        
        // Clear background
        cgContext.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0))
        cgContext.fill(CGRect(origin: .zero, size: size))
        performanceMonitor.recordDrawCall(vertexCount: 4)
        
        // Draw grid
        drawGrid(cgContext: cgContext, size: size)
        
        // Draw animated shapes
        drawAnimatedShapes(cgContext: cgContext, size: size)
        
        // Draw performance info directly on canvas
        drawPerformanceText(cgContext: cgContext, size: size)
    }
    
    private func drawGrid(cgContext: CGContext, size: CGSize) {
        cgContext.setStrokeColor(CGColor(gray: 0.2, alpha: 1.0))
        cgContext.setLineWidth(0.5)
        
        let gridSpacing: CGFloat = 40
        
        // Vertical lines
        var x: CGFloat = 0
        while x <= size.width {
            cgContext.move(to: CGPoint(x: x, y: 0))
            cgContext.addLine(to: CGPoint(x: x, y: size.height))
            cgContext.strokePath()
            performanceMonitor.recordDrawCall(vertexCount: 2)
            x += gridSpacing
        }
        
        // Horizontal lines
        var y: CGFloat = 0
        while y <= size.height {
            cgContext.move(to: CGPoint(x: 0, y: y))
            cgContext.addLine(to: CGPoint(x: size.width, y: y))
            cgContext.strokePath()
            performanceMonitor.recordDrawCall(vertexCount: 2)
            y += gridSpacing
        }
    }
    
    private func drawAnimatedShapes(cgContext: CGContext, size: CGSize) {
        // Moving circle
        cgContext.setFillColor(CGColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.8))
        let circleX = animationOffset
        let circleY = size.height / 2 - 25
        cgContext.fillEllipse(in: CGRect(x: circleX, y: circleY, width: 50, height: 50))
        performanceMonitor.recordDrawCall(vertexCount: 24)
        
        // Rotating squares
        for i in 0..<5 {
            let angle = (animationOffset / 50.0) + Double(i) * 0.5
            let centerX = 100 + CGFloat(i) * 120
            let centerY = size.height / 3
            
            cgContext.saveGState()
            cgContext.translateBy(x: centerX, y: centerY)
            cgContext.rotate(by: CGFloat(angle))
            
            let hue = Double(i) / 5.0
            cgContext.setFillColor(CGColor(red: CGFloat(sin(hue * .pi)), 
                                         green: CGFloat(cos(hue * .pi)), 
                                         blue: CGFloat(sin(hue * .pi * 2)), 
                                         alpha: 0.7))
            cgContext.fill(CGRect(x: -20, y: -20, width: 40, height: 40))
            performanceMonitor.recordDrawCall(vertexCount: 4)
            
            cgContext.restoreGState()
        }
        
        // Sine wave
        cgContext.setStrokeColor(CGColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0))
        cgContext.setLineWidth(3.0)
        
        cgContext.beginPath()
        for x in stride(from: 0, through: size.width, by: 2) {
            let y = size.height * 0.7 + sin((x + animationOffset) * 0.02) * 50
            if x == 0 {
                cgContext.move(to: CGPoint(x: x, y: y))
            } else {
                cgContext.addLine(to: CGPoint(x: x, y: y))
            }
        }
        cgContext.strokePath()
        performanceMonitor.recordDrawCall(vertexCount: Int(size.width / 2))
    }
    
    private func drawPerformanceText(cgContext: CGContext, size: CGSize) {
        cgContext.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9))
        
        let text = """
        FPS: \(Int(performanceMonitor.fps))
        Frame: \(String(format: "%.1f", performanceMonitor.frameTime))ms
        Mode: \(performanceMonitor.renderingMode)
        Draw Calls: \(performanceMonitor.drawCallCount)
        """
        
        // Note: For a real implementation, you'd use proper text rendering
        // This is just a demo showing where the text would go
    }
}

// For testing in a playground or standalone app
// This would be used in a real SwiftUI app

print("🎯 Performance Demo Created!")
print("✅ Features:")
print("   • Real-time FPS monitoring") 
print("   • Frame time tracking")
print("   • Draw call counting")
print("   • Memory usage tracking")
print("   • Metal vs Core Graphics detection")
print("   • Performance grade (Excellent/Good/Fair/Poor)")
print("")
print("🚀 To use in your app:")
print("   1. Add PerformanceOverlay to any view")
print("   2. Use SafeMetalView for hardware acceleration")
print("   3. Call performanceMonitor.recordDrawCall() for each draw operation")
print("   4. Triple-tap to toggle detailed stats")
