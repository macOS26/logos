import MetalKit
import simd
import UniformTypeIdentifiers

/// GPU-accelerated image tile renderer using Metal
class MetalImageTileRenderer {
    static let shared = MetalImageTileRenderer()

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    // NOTE: No texture cache - render directly from CGImage to SwiftUI Canvas
    // Metal is fast enough that we don't need to cache textures in VRAM

    // Disk cache for rendered CGImages (stores paths, not images in RAM)
    private var diskCachePaths: [String: String] = [:] // [renderKey: /tmp/path]
    private let diskCacheLock = NSLock()

    // Get cached CGImage from disk
    func getCachedImage(for key: String) -> CGImage? {
        diskCacheLock.lock()
        defer { diskCacheLock.unlock() }

        guard let cachedPath = diskCachePaths[key],
              FileManager.default.fileExists(atPath: cachedPath) else {
            return nil
        }

        return loadImageFromDisk(path: cachedPath)
    }

    private init?() {
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

        // Setup vertex descriptor to match shader attributes
        let vertexDescriptor = MTLVertexDescriptor()
        // Position: float2 at attribute(0)
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        // TexCoord: float2 at attribute(1)
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
        vertexDescriptor.attributes[1].bufferIndex = 0
        // Layout stride (4 floats per vertex: x, y, u, v)
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // Disable blending - straight copy
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = false

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("❌ Failed to create Metal pipeline: \(error)")
            return nil
        }
    }

    /// Convert CGImage to Metal texture (no caching - render directly)
    func getTexture(from cgImage: CGImage) -> MTLTexture? {
        // Don't use MTKTextureLoader - it always converts to BGRA
        // Instead, manually create texture with correct RGBA format

        let width = cgImage.width
        let height = cgImage.height

        // Create RGBA context to normalize the image
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            print("❌ Failed to create CGContext")
            return nil
        }

        // Draw image into RGBA context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get RGBA pixel data
        guard let data = context.data else {
            print("❌ Failed to get context data")
            return nil
        }

        // Create RGBA Metal texture descriptor (.shared so we can upload data directly)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,  // Use RGBA, not BGRA
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared  // Must be .shared to upload from CPU

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            print("❌ Failed to create Metal texture")
            return nil
        }

        // Upload RGBA data to texture
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: width * 4)

        print("📊 Created Metal texture format: \(texture.pixelFormat.rawValue) (10=RGBA8Unorm, 80=BGRA8Unorm)")

        return texture
    }

    /// Render image tiles to an offscreen texture and return as CGImage using INSTANCED RENDERING
    func compositeImageTiles(
        image: CGImage,
        tiles: [(coord: SIMD2<Int>, rect: CGRect)],
        outputSize: CGSize,
        shapeID: UUID
    ) -> CGImage? {
        let cacheKey = shapeID.uuidString

        // Check disk cache first
        diskCacheLock.lock()
        if let cachedPath = diskCachePaths[cacheKey],
           FileManager.default.fileExists(atPath: cachedPath),
           let cachedImage = loadImageFromDisk(path: cachedPath) {
            diskCacheLock.unlock()
            print("✅ MetalImageTileRenderer: DISK CACHE HIT for \(cacheKey)")
            return cachedImage
        }
        diskCacheLock.unlock()

        print("❌ MetalImageTileRenderer: DISK CACHE MISS for \(cacheKey), compositing...")

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let sourceTexture = getTexture(from: image) else {
            return nil
        }

        // Create offscreen render target
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]

        guard let renderTarget = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        // Setup render pass
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderTarget
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return nil
        }

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setFragmentTexture(sourceTexture, index: 0)

        // Create orthographic projection matrix for the output size
        var mvpMatrix = createOrthographicMatrix(width: Float(outputSize.width), height: Float(outputSize.height))
        renderEncoder.setVertexBytes(&mvpMatrix, length: MemoryLayout<simd_float4x4>.size, index: 1)

        // Calculate scale factors
        let scaleX = Float(outputSize.width / CGFloat(image.width))
        let scaleY = Float(outputSize.height / CGFloat(image.height))
        let imageWidth = Float(image.width)
        let imageHeight = Float(image.height)

        // Build instance data for ALL tiles (one quad per tile)
        var vertices: [Float] = []
        var indices: [UInt16] = []

        for (index, (_, tileRect)) in tiles.enumerated() {
            let baseVertex = UInt16(index * 4)

            // Calculate destination rect
            let destX = Float(tileRect.minX) * scaleX
            let destY = Float(tileRect.minY) * scaleY
            let destW = Float(tileRect.width) * scaleX
            let destH = Float(tileRect.height) * scaleY

            // Texture coordinates (normalized 0-1)
            let texMinX = Float(tileRect.minX / CGFloat(imageWidth))
            let texMinY = Float(tileRect.minY / CGFloat(imageHeight))
            let texMaxX = Float(tileRect.maxX / CGFloat(imageWidth))
            let texMaxY = Float(tileRect.maxY / CGFloat(imageHeight))

            // Quad vertices for this tile (position + texCoord)
            vertices.append(contentsOf: [
                destX,        destY,        texMinX, texMinY,  // Bottom-left
                destX + destW, destY,        texMaxX, texMinY,  // Bottom-right
                destX,        destY + destH, texMinX, texMaxY,  // Top-left
                destX + destW, destY + destH, texMaxX, texMaxY   // Top-right
            ])

            // Two triangles per tile
            indices.append(contentsOf: [
                baseVertex + 0, baseVertex + 1, baseVertex + 2,
                baseVertex + 2, baseVertex + 1, baseVertex + 3
            ])
        }

        // Upload vertex and index buffers to GPU
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Float>.size, options: []),
              let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: []) else {
            return nil
        }

        // ONE DRAW CALL for ALL tiles
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indices.count,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )

        renderEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Convert Metal texture back to CGImage
        guard let resultImage = cgImage(from: renderTarget) else {
            return nil
        }

        // Save to disk cache
        if let diskPath = saveImageToDisk(image: resultImage, key: cacheKey) {
            diskCacheLock.lock()
            diskCachePaths[cacheKey] = diskPath
            diskCacheLock.unlock()
            print("💾 MetalImageTileRenderer: CACHED to disk at \(diskPath)")
        }

        return resultImage
    }

    /// Render image tiles to a Metal drawable (legacy - for direct screen rendering)
    func renderTiles(
        image: CGImage,
        tiles: [(coord: SIMD2<Int>, rect: CGRect)],
        renderBounds: CGRect,
        opacity: Float,
        to drawable: CAMetalDrawable,
        viewportSize: CGSize
    ) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let texture = getTexture(from: image) else {
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

        // Create orthographic projection matrix for the viewport
        var mvpMatrix = createOrthographicMatrix(width: Float(viewportSize.width), height: Float(viewportSize.height))
        renderEncoder.setVertexBytes(&mvpMatrix, length: MemoryLayout<simd_float4x4>.size, index: 1)

        // Calculate scale factors
        let scaleX = Float(renderBounds.width / CGFloat(image.width))
        let scaleY = Float(renderBounds.height / CGFloat(image.height))

        // Render each tile as a quad
        for (_, tileRect) in tiles {
            renderTileQuad(
                encoder: renderEncoder,
                tileRect: tileRect,
                imageSize: CGSize(width: image.width, height: image.height),
                outputSize: viewportSize,
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
        outputSize: CGSize,
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

    /// Convert Metal texture to CGImage
    private func cgImage(from texture: MTLTexture) -> CGImage? {
        let width = texture.width
        let height = texture.height

        // Metal texture is RGBA, CGImage expects RGBA - direct copy!
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // Read RGBA data from Metal texture
        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(context.data!, bytesPerRow: width * 4, from: region, mipmapLevel: 0)

        print("📊 Reading texture format: \(texture.pixelFormat.rawValue) - should be 10 (RGBA)")

        return context.makeImage()
    }

    /// Clear texture cache (no-op - we don't cache textures anymore)
    func clearCache() {
        diskCacheLock.lock()
        // Delete all cached files
        for (_, path) in diskCachePaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        diskCachePaths.removeAll()
        diskCacheLock.unlock()
        print("🗑️ MetalImageTileRenderer.clearCache() - cleared disk cache")
    }

    /// Save CGImage to disk in /tmp
    private func saveImageToDisk(image: CGImage, key: String) -> String? {
        let tmpDir = NSTemporaryDirectory()
        let filename = "metal_tile_\(key).png"
        let filePath = (tmpDir as NSString).appendingPathComponent(filename)

        guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: filePath) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            print("❌ Failed to create image destination for disk cache")
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            print("❌ Failed to write image to disk cache")
            return nil
        }

        return filePath
    }

    /// Load CGImage from disk
    private func loadImageFromDisk(path: String) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            print("❌ Failed to load image from disk cache at \(path)")
            return nil
        }
        return image
    }

    /// Create orthographic projection matrix for 2D rendering
    private func createOrthographicMatrix(width: Float, height: Float) -> simd_float4x4 {
        // Convert from pixel coordinates (0,0 at top-left) to NDC (-1,-1 to 1,1)
        let left: Float = 0
        let right = width
        let bottom = height
        let top: Float = 0
        let near: Float = -1
        let far: Float = 1

        let scaleX = 2.0 / (right - left)
        let scaleY = 2.0 / (top - bottom)
        let scaleZ = -2.0 / (far - near)

        let translateX = -(right + left) / (right - left)
        let translateY = -(top + bottom) / (top - bottom)
        let translateZ = -(far + near) / (far - near)

        return simd_float4x4(
            SIMD4<Float>(scaleX, 0, 0, 0),
            SIMD4<Float>(0, scaleY, 0, 0),
            SIMD4<Float>(0, 0, scaleZ, 0),
            SIMD4<Float>(translateX, translateY, translateZ, 1)
        )
    }
}
