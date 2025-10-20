import SwiftUI
import MetalKit

struct SafeMetalView: NSViewRepresentable {
    let renderContent: (CGContext, CGSize) -> Void
    let performanceMonitor: PerformanceMonitor?

    init(performanceMonitor: PerformanceMonitor? = nil, renderContent: @escaping (CGContext, CGSize) -> Void) {
        self.performanceMonitor = performanceMonitor
        self.renderContent = renderContent
    }

    class Coordinator {
        let metalManager: MetalDeviceManager
        let performanceMonitor: PerformanceMonitor
        let renderer: MetalRenderer

        init(renderContent: @escaping (CGContext, CGSize) -> Void, externalMonitor: PerformanceMonitor?) {
            self.metalManager = MetalDeviceManager()
            self.performanceMonitor = externalMonitor ?? PerformanceMonitor()
            self.renderer = MetalRenderer(
                renderContent: renderContent,
                performanceMonitor: self.performanceMonitor,
                device: self.metalManager.device,
                commandQueue: self.metalManager.commandQueue
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(renderContent: renderContent, externalMonitor: performanceMonitor)
    }

    func makeNSView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.device = context.coordinator.metalManager.device
        metalView.delegate = context.coordinator.renderer
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.framebufferOnly = false
        metalView.clearColor = MTLClearColorMake(0, 0, 0, 0)

        // Support high refresh rate displays (120fps ProMotion, etc)
        if let screen = NSScreen.main {
            let maxFPS = Int(screen.maximumFramesPerSecond)
            metalView.preferredFramesPerSecond = maxFPS
        } else {
            metalView.preferredFramesPerSecond = 120 // Default to 120fps for ProMotion
        }

        metalView.isPaused = true
        metalView.enableSetNeedsDisplay = true
        metalView.layer?.isOpaque = false
        metalView.layer?.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        return metalView
    }

    func updateNSView(_ metalView: MTKView, context: Context) {
        metalView.setNeedsDisplay(metalView.bounds)
    }
}

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
    }

    func draw(in view: MTKView) {
        performanceMonitor?.frameDidStart()
        performanceMonitor?.metalCommandDidStart()

        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            performanceMonitor?.frameDidEnd()
            return
        }

        performanceMonitor?.recordDrawCall()

        renderWithSafeMetal(drawable: drawable, renderPassDescriptor: renderPassDescriptor)

        performanceMonitor?.metalCommandDidEnd()
        performanceMonitor?.frameDidEnd()
    }

    private func renderWithSafeMetal(drawable: CAMetalDrawable, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("❌ Metal rendering unavailable: failed to create command buffer/encoder")
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

extension SafeMetalView {
    static func forSwiftUIContent(@ViewBuilder content: @escaping () -> some View) -> some View {
        SafeMetalView { cgContext, size in
            cgContext.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0))
            cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
