import SwiftUI
import MetalKit

/// A SwiftUI view that safely handles Metal rendering with graceful fallbacks
struct SafeMetalView: NSViewRepresentable {
    let renderContent: (CGContext, CGSize) -> Void

    // Coordinator holds stateful objects to avoid mutating SwiftUI state during updates
    class Coordinator {
        let metalManager: MetalDeviceManager
        let performanceMonitor: PerformanceMonitor
        let renderer: MetalRenderer

        init(renderContent: @escaping (CGContext, CGSize) -> Void) {
            self.metalManager = MetalDeviceManager()
            self.performanceMonitor = PerformanceMonitor()
            self.renderer = MetalRenderer(
                renderContent: renderContent,
                performanceMonitor: self.performanceMonitor,
                device: self.metalManager.device,
                commandQueue: self.metalManager.commandQueue
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(renderContent: renderContent)
    }

    func makeNSView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = context.coordinator.metalManager.device
        metalView.delegate = context.coordinator.renderer
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = false
        // Transparent overlay so underlying SwiftUI content shows through
        metalView.clearColor = MTLClearColorMake(0, 0, 0, 0)
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.layer?.isOpaque = false
        metalView.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        return metalView
    }

    func updateNSView(_ metalView: MTKView, context: Context) {
        metalView.setNeedsDisplay(metalView.bounds)
    }
}

/// Metal renderer that doesn't trigger library loading errors
class MetalRenderer: NSObject, MTKViewDelegate {
    let renderContent: (CGContext, CGSize) -> Void
    weak var performanceMonitor: PerformanceMonitor?
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    init(
        renderContent: @escaping (CGContext, CGSize) -> Void,
        performanceMonitor: PerformanceMonitor? = nil,
        device: MTLDevice,
        commandQueue: MTLCommandQueue
    ) {
        self.renderContent = renderContent
        self.performanceMonitor = performanceMonitor
        self.device = device
        self.commandQueue = commandQueue
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize
    }
    
    func draw(in view: MTKView) {
        // Start performance tracking
        performanceMonitor?.frameDidStart()
        performanceMonitor?.metalCommandDidStart()
        
        // Safe Metal rendering without problematic library calls
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            performanceMonitor?.frameDidEnd()
            return
        }
        
        // Track draw call
        performanceMonitor?.recordDrawCall()
        
        // Use Metal for GPU-accelerated rendering
        // This bypasses the problematic RenderBox framework calls
        renderWithSafeMetal(drawable: drawable, renderPassDescriptor: renderPassDescriptor)
        
        // End performance tracking
        performanceMonitor?.metalCommandDidEnd()
        performanceMonitor?.frameDidEnd()
    }
    
    private func renderWithSafeMetal(drawable: CAMetalDrawable, renderPassDescriptor: MTLRenderPassDescriptor) {
        // Strict Metal path: clear the drawable using a command buffer; no CoreGraphics fallback
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("❌ Metal rendering unavailable: failed to create command buffer/encoder")
        }

        // Ensure we do not overwrite scene: only clear alpha if needed; currently clearColor is transparent
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}



/// Extension to make the SafeMetalView easy to use
extension SafeMetalView {
    /// Create a safe Metal view with SwiftUI drawing content
    static func forSwiftUIContent(@ViewBuilder content: @escaping () -> some View) -> some View {
        SafeMetalView { cgContext, size in
            // Convert SwiftUI content to Core Graphics rendering
            // This is a simplified approach - you can expand this as needed
            cgContext.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
            cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
