import MetalKit
import simd

/// GPU-accelerated image tile renderer using Metal
class MetalImageTileRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private var textureCache: [String: MTLTexture] = [:]

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue

        // Load Metal shaders
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "tileVertexShader"),
              let fragmentFunction = library.makeFunction(name: "tileFragmentShader") else {
            return nil
        }

        // Create render pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable blending for transparency
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("❌ Failed to create Metal pipeline: \(error)")
            return nil
        }
    }

    /// Convert CGImage to Metal texture (cached)
    func getTexture(from cgImage: CGImage, cacheKey: String) -> MTLTexture? {
        if let cached = textureCache[cacheKey] {
            return cached
        }

        let textureLoader = MTKTextureLoader(device: device)

        do {
            let texture = try textureLoader.newTexture(cgImage: cgImage, options: [
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
            ])
            textureCache[cacheKey] = texture
            return texture
        } catch {
            print("❌ Failed to create Metal texture: \(error)")
            return nil
        }
    }

    /// Render image tiles to a Metal drawable
    func renderTiles(
        image: CGImage,
        tiles: [(coord: SIMD2<Int>, rect: CGRect)],
        renderBounds: CGRect,
        opacity: Float,
        to drawable: CAMetalDrawable,
        viewportSize: CGSize
    ) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let texture = getTexture(from: image, cacheKey: "\(image.hashValue)") else {
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(texture, index: 0)

        var opacityBuffer = opacity
        renderEncoder.setFragmentBytes(&opacityBuffer, length: MemoryLayout<Float>.size, index: 0)

        // Calculate scale factors
        let scaleX = Float(renderBounds.width / CGFloat(image.width))
        let scaleY = Float(renderBounds.height / CGFloat(image.height))

        // Render each tile as a quad
        for (_, tileRect) in tiles {
            renderTileQuad(
                encoder: renderEncoder,
                tileRect: tileRect,
                imageSize: CGSize(width: image.width, height: image.height),
                renderBounds: renderBounds,
                viewportSize: viewportSize,
                scaleX: scaleX,
                scaleY: scaleY
            )
        }

        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func renderTileQuad(
        encoder: MTLRenderCommandEncoder,
        tileRect: CGRect,
        imageSize: CGSize,
        renderBounds: CGRect,
        viewportSize: CGSize,
        scaleX: Float,
        scaleY: Float
    ) {
        // Calculate destination rect in screen space
        let destX = Float(tileRect.minX) * scaleX
        let destY = Float(tileRect.minY) * scaleY
        let destW = Float(tileRect.width) * scaleX
        let destH = Float(tileRect.height) * scaleY

        // Texture coordinates (normalized 0-1)
        let texMinX = Float(tileRect.minX / imageSize.width)
        let texMinY = Float(tileRect.minY / imageSize.height)
        let texMaxX = Float(tileRect.maxX / imageSize.width)
        let texMaxY = Float(tileRect.maxY / imageSize.height)

        // Quad vertices (position + texCoord)
        let vertices: [Float] = [
            // Position (x, y)     TexCoord (u, v)
            destX,        destY,        texMinX, texMinY,  // Bottom-left
            destX + destW, destY,        texMaxX, texMinY,  // Bottom-right
            destX,        destY + destH, texMinX, texMaxY,  // Top-left
            destX + destW, destY + destH, texMaxX, texMaxY   // Top-right
        ]

        let indices: [UInt16] = [0, 1, 2, 2, 1, 3]  // Two triangles

        encoder.setVertexBytes(vertices, length: vertices.count * MemoryLayout<Float>.size, index: 0)
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indices.count,
            indexType: .uint16,
            indexBuffer: device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])!,
            indexBufferOffset: 0
        )
    }

    /// Clear texture cache
    func clearCache() {
        textureCache.removeAll()
    }
}
