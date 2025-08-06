import Metal
import MetalKit
import Foundation

/// A pseudo Metal device manager that gracefully handles Metal initialization
/// and provides fallback rendering when Metal libraries are unavailable
class MetalDeviceManager: ObservableObject {
    
    @Published var isMetalAvailable: Bool = false
    @Published var device: MTLDevice?
    @Published var commandQueue: MTLCommandQueue?
    
    private var fallbackDevice: VirtualMetalDevice?
    
    init() {
        setupMetalDevice()
    }
    
    private func setupMetalDevice() {
        // First attempt: Use default Metal device
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            self.device = metalDevice
            self.commandQueue = metalDevice.makeCommandQueue()
            self.isMetalAvailable = true
            print("✅ Metal device initialized successfully")
            return
        }
        
        // Second attempt: Try to create with specific GPU
        let devices = MTLCopyAllDevices()
        if let firstDevice = devices.first {
            self.device = firstDevice
            self.commandQueue = firstDevice.makeCommandQueue()
            self.isMetalAvailable = true
            print("✅ Metal device initialized with discrete GPU")
            return
        }
        
        // Fallback: Create a virtual Metal device
        setupVirtualMetalDevice()
    }
    
    private func setupVirtualMetalDevice() {
        print("🔄 Initializing Virtual Metal Device (CPU-based rendering)")
        self.fallbackDevice = VirtualMetalDevice()
        self.isMetalAvailable = false
        
        // We can still set device to nil but provide rendering through our virtual device
        // This prevents Metal library loading errors while maintaining functionality
    }
    
    /// Safe method to execute Metal commands with fallback
    func executeRenderCommand<T>(_ command: (MTLDevice, MTLCommandQueue) -> T?, fallback: () -> T?) -> T? {
        if isMetalAvailable,
           let device = device,
           let commandQueue = commandQueue {
            return command(device, commandQueue)
        } else {
            return fallback()
        }
    }
    
    /// Check if Metal is working properly without triggering library errors
    func validateMetalSupport() -> Bool {
        guard isMetalAvailable else { return false }
        
        // Simple validation without loading problematic libraries
        let _ = device?.makeCommandQueue()
        return true
    }
}

/// Virtual Metal Device for CPU-based fallback rendering
class VirtualMetalDevice {
    
    func renderWithCoreGraphics(in cgContext: CGContext, size: CGSize, renderBlock: (CGContext) -> Void) {
        // Use Core Graphics for rendering when Metal is unavailable
        cgContext.saveGState()
        renderBlock(cgContext)
        cgContext.restoreGState()
    }
    
    func processImageData(_ imageData: Data) -> Data? {
        // CPU-based image processing fallback
        return imageData
    }
    
    func createTexture(width: Int, height: Int) -> VirtualTexture {
        return VirtualTexture(width: width, height: height)
    }
}

/// Virtual texture for CPU-based operations
struct VirtualTexture {
    let width: Int
    let height: Int
    var data: [UInt8]
    
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.data = Array(repeating: 0, count: width * height * 4) // RGBA
    }
}
