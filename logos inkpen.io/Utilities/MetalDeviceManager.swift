import Metal
import MetalKit
import Foundation

/// Metal device manager for GPU-only systems
/// Requires Metal GPU support - no CPU fallbacks
class MetalDeviceManager: ObservableObject {
    
    @Published var device: MTLDevice
    @Published var commandQueue: MTLCommandQueue
    
    init() {
        // Metal GPU is required - fail fast if not available
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("❌ Metal GPU not available. This application requires Metal GPU support.")
        }
        
        guard let cmdQueue = metalDevice.makeCommandQueue() else {
            fatalError("❌ Failed to create Metal command queue. GPU may be unavailable.")
        }
        
        self.device = metalDevice
        self.commandQueue = cmdQueue
        
        print("✅ Metal GPU initialized successfully: \(metalDevice.name)")
    }
    
    /// Execute Metal commands (no fallbacks - GPU required)
    func executeRenderCommand<T>(_ command: (MTLDevice, MTLCommandQueue) -> T) -> T {
        return command(device, commandQueue)
    }
    
    /// Validate Metal GPU support
    func validateMetalSupport() -> Bool {
        // If we got here, Metal is available (otherwise init would have failed)
        return true
    }
}
