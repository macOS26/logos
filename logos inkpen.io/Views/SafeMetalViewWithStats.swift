import SwiftUI

/// SafeMetalView with built-in performance monitoring overlay
struct SafeMetalViewWithStats: View {
    let renderContent: (CGContext, CGSize) -> Void
    @State private var showPerformanceOverlay: Bool = true
    
    var body: some View {
        ZStack {
            // Main Metal rendering view
            SafeMetalView(renderContent: renderContent)
            
            // Performance overlay
            if showPerformanceOverlay {
                PerformanceOverlay(performanceMonitor: performanceMonitor)
            }
        }
        .onTapGesture(count: 3) {
            // Triple-tap to toggle performance overlay
            withAnimation(.easeInOut(duration: 0.2)) {
                showPerformanceOverlay.toggle()
            }
        }
    }
    
    // Access the performance monitor from the SafeMetalView
    private var performanceMonitor: PerformanceMonitor {
        // This is a simplified approach - in a real implementation,
        // you'd need to pass the performance monitor reference
        PerformanceMonitor()
    }
}

// MARK: - Enhanced Drawing Canvas Integration

extension DrawingCanvas {
    
    /// Enhanced canvas content with performance monitoring
    @ViewBuilder
    internal func canvasWithPerformanceMonitoring(geometry: GeometryProxy) -> some View {
        ZStack {
            // Original canvas content
            canvasMainContent(geometry: geometry)
            
            // Performance overlay (top-right corner)
            VStack {
                HStack {
                    Spacer()
                    PerformanceOverlay(performanceMonitor: getOrCreatePerformanceMonitor())
                        .padding(.top, 8)
                        .padding(.trailing, 8)
                }
                Spacer()
            }
        }
    }
    
    /// Get or create a performance monitor for this canvas
    private func getOrCreatePerformanceMonitor() -> PerformanceMonitor {
        // Store this in your AppState or as a @StateObject in your main view
        // For now, we'll create a shared instance
        PerformanceMonitor.shared
    }
}

// MARK: - Shared Performance Monitor

extension PerformanceMonitor {
    static let shared = PerformanceMonitor()
}

// MARK: - Integration Example

struct ExampleCanvasWithPerformanceStats: View {
    @StateObject private var performanceMonitor = PerformanceMonitor()
    
    var body: some View {
        ZStack {
            // Your canvas content with Safe Metal integration
            SafeMetalView { cgContext, size in
                drawExampleContent(cgContext: cgContext, size: size)
            }
            
            // Performance overlay
            VStack {
                HStack {
                    Spacer()
                    PerformanceOverlay(performanceMonitor: performanceMonitor)
                        .padding()
                }
                Spacer()
            }
        }
        .navigationTitle("Canvas with Performance Stats")
    }
    
    private func drawExampleContent(cgContext: CGContext, size: CGSize) {
        // Reset draw stats for this frame
        performanceMonitor.resetDrawingStats()
        
        // Example: Draw a grid
        cgContext.setStrokeColor(CGColor(gray: 0.8, alpha: 1.0))
        cgContext.setLineWidth(1.0)
        
        let gridSpacing: CGFloat = 20
        
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
        
        // Example: Draw some shapes
        cgContext.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.5))
        cgContext.fillEllipse(in: CGRect(x: 50, y: 50, width: 100, height: 100))
        performanceMonitor.recordDrawCall(vertexCount: 24) // Approximate vertices for a circle
        
        cgContext.setFillColor(CGColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 0.7))
        cgContext.fill(CGRect(x: 200, y: 100, width: 150, height: 80))
        performanceMonitor.recordDrawCall(vertexCount: 4)
    }
}

#Preview {
    ExampleCanvasWithPerformanceStats()
        .frame(width: 600, height: 400)
}
