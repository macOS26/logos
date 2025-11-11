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

    /// Convert CGImage to Metal texture (cached)
    func getTexture(from cgImage: CGImage, cacheKey: String) -> MTLTexture? {
        if let cached = textureCache[cacheKey] {
            return cached
        }

        // Check if image is already in a compatible format
        let needsConversion: Bool = {
            // Check if color space is sRGB or device RGB
            guard let imageColorSpace = cgImage.colorSpace else { return true }
            let srgbColorSpace = CGColorSpace(name: CGColorSpace.sRGB)

            // If not sRGB, needs conversion
            if imageColorSpace != srgbColorSpace && imageColorSpace.name != CGColorSpace.genericRGBLinear {
                return true
            }

            // Check bitmap format - we want 32-bit RGBA with premultiplied alpha
            let byteOrder = cgImage.bitmapInfo.contains(.byteOrder32Big) || cgImage.bitmapInfo.contains(.byteOrder32Little)

            if cgImage.bitsPerPixel != 32 || !byteOrder {
                return true
            }

            return false
        }()

        let imageToLoad: CGImage

        if needsConversion {
            // Convert CGImage to consistent color space (sRGB RGBA)
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

            guard let context = CGContext(
                data: nil,
                width: cgImage.width,
                height: cgImage.height,
                bitsPerComponent: 8,
                bytesPerRow: cgImage.width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                print("❌ Failed to create CGContext for color space conversion")
                return nil
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

            guard let convertedImage = context.makeImage() else {
                print("❌ Failed to convert image to consistent color space")
                return nil
            }

            imageToLoad = convertedImage
        } else {
            imageToLoad = cgImage
        }

        let textureLoader = MTKTextureLoader(device: device)

        do {
            let texture = try textureLoader.newTexture(cgImage: imageToLoad, options: [
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                .SRGB: NSNumber(value: false)
            ])
            textureCache[cacheKey] = texture
            return texture
        } catch {
            print("❌ Failed to create Metal texture: \(error)")
            return nil
        }
    }

    /// Render image tiles to an offscreen texture and return as CGImage using INSTANCED RENDERING
    func compositeImageTiles(
        image: CGImage,
        tiles: [(coord: SIMD2<Int>, rect: CGRect)],
        outputSize: CGSize
    ) -> CGImage? {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let sourceTexture = getTexture(from: image, cacheKey: "\(image.hashValue)") else {
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

        // Synchronize GPU -> CPU for texture readback
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.synchronize(resource: renderTarget)
        blitEncoder?.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Convert Metal texture back to CGImage
        return cgImage(from: renderTarget)
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
        let rowBytes = width * 4
        let length = rowBytes * height

        var data = [UInt8](repeating: 0, count: length)

        let region = MTLRegionMake2D(0, 0, width, height)
        texture.getBytes(&data, bytesPerRow: rowBytes, from: region, mipmapLevel: 0)

        guard let providerRef = CGDataProvider(data: Data(bytes: &data, count: length) as CFData) else {
            return nil
        }

        // Metal texture is .bgra8Unorm_srgb (BGRA with premultiplied alpha, little endian)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: rowBytes,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    /// Clear texture cache
    func clearCache() {
        textureCache.removeAll()
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
