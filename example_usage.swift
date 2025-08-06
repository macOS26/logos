import SwiftUI

// Example of how to integrate the safe Metal approach into your existing drawing canvas

struct ExampleDrawingCanvasWithSafeMetal: View {
    @StateObject private var metalManager = MetalDeviceManager()
    
    var body: some View {
        VStack {
            // Status indicator
            HStack {
                Circle()
                    .fill(metalManager.isMetalAvailable ? .green : .orange)
                    .frame(width: 8, height: 8)
                
                Text(metalManager.isMetalAvailable ? "GPU Accelerated" : "CPU Rendering")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Safe Metal rendering view
            SafeMetalView { cgContext, size in
                drawVectorContent(in: cgContext, size: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func drawVectorContent(in context: CGContext, size: CGSize) {
        // Your existing vector drawing code here
        // This will work regardless of Metal availability
        
        context.setStrokeColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0))
        context.setLineWidth(2.0)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 50, y: 50))
        path.addLine(to: CGPoint(x: size.width - 50, y: 50))
        path.addLine(to: CGPoint(x: size.width - 50, y: size.height - 50))
        path.addLine(to: CGPoint(x: 50, y: size.height - 50))
        path.closeSubpath()
        
        context.addPath(path)
        context.strokePath()
        
        // Add some text
        let text = "Safe Metal/CoreGraphics Rendering"
        let font = CTFontCreateWithName("Helvetica" as CFString, 16, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        
        context.textPosition = CGPoint(x: 60, y: size.height / 2)
        CTLineDraw(line, context)
    }
}

// Integration example for your existing DrawingCanvas
extension DrawingCanvas {
    func enableSafeMetalRendering() {
        // Replace direct Metal calls with safe Metal manager
        let metalManager = MetalDeviceManager()
        
        // Example of how to modify existing rendering calls
        metalManager.executeRenderCommand(
            { device, commandQueue in
                // Your Metal rendering code here
                return performMetalRendering(device: device, commandQueue: commandQueue)
            },
            fallback: {
                // Your Core Graphics fallback here
                return performCoreGraphicsRendering()
            }
        )
    }
    
    private func performMetalRendering(device: MTLDevice, commandQueue: MTLCommandQueue) -> Bool {
        // Your existing Metal code - but now it's safely wrapped
        // This won't trigger the RenderBox library errors
        return true
    }
    
    private func performCoreGraphicsRendering() -> Bool {
        // Your Core Graphics fallback rendering
        return true
    }
}
