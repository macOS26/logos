import Foundation
import AppKit
import ImageIO
import simd

/// Tile coordinate using SIMD for efficient computation (x=col, y=row)
typealias TileCoordinate = SIMD2<Int>

/// Manages image sources and calculates visible tiles (CATiledLayer approach)
class ImageTileCache {
    static let shared = ImageTileCache()

    private var sourceImageCache: [String: CGImage] = [:]  // imageKey -> source image
    private var cacheLock = NSLock()

    private init() {}

    /// Get the current tile size from preferences
    var tileSizePixels: Int {
        ApplicationSettings.shared.imageTileSize
    }

    /// Calculate which tiles intersect the viewport
    /// - Parameters:
    ///   - imageRect: The image bounds in SCREEN coordinates (with zoom applied)
    ///   - viewportRect: The visible viewport in SCREEN coordinates
    ///   - imageSize: The actual image pixel dimensions
    ///   - canvasSize: The image size in CANVAS coordinates (before zoom)
    ///   - tileSize: The tile size in pixels (optional, defaults to user preference)
    /// - Returns: Array of tile coordinates and their rects in image coordinates
    func visibleTiles(imageRect: CGRect, viewportRect: CGRect, imageSize: CGSize, canvasSize: CGSize, tileSize: Int? = nil) -> [(coord: TileCoordinate, rect: CGRect)] {
        guard imageRect.intersects(viewportRect) else { return [] }

        let intersection = imageRect.intersection(viewportRect)

        // Calculate scale from CANVAS size to actual image pixels
        let scaleX = imageSize.width / canvasSize.width
        let scaleY = imageSize.height / canvasSize.height

        // Calculate scale from SCREEN size to CANVAS size (inverse of zoom)
        let screenToCanvasScaleX = canvasSize.width / imageRect.width
        let screenToCanvasScaleY = canvasSize.height / imageRect.height

        // Convert intersection from SCREEN space to CANVAS space, then to pixels
        let canvasMinX = (intersection.minX - imageRect.minX) * screenToCanvasScaleX
        let canvasMinY = (intersection.minY - imageRect.minY) * screenToCanvasScaleY
        let canvasMaxX = (intersection.maxX - imageRect.minX) * screenToCanvasScaleX
        let canvasMaxY = (intersection.maxY - imageRect.minY) * screenToCanvasScaleY

        // Now convert from canvas space to pixel space
        let pixelMinX = canvasMinX * scaleX
        let pixelMinY = canvasMinY * scaleY
        let pixelMaxX = canvasMaxX * scaleX
        let pixelMaxY = canvasMaxY * scaleY

        // Use provided tile size or default to preferences
        let currentTileSize = tileSize ?? tileSizePixels
        let tileSizeF = CGFloat(currentTileSize)

        // Calculate tile range using integer math for speed
        let minCol = max(0, Int(pixelMinX / tileSizeF))
        let maxCol = min(Int(imageSize.width / tileSizeF), Int(pixelMaxX / tileSizeF))
        let minRow = max(0, Int(pixelMinY / tileSizeF))
        let maxRow = min(Int(imageSize.height / tileSizeF), Int(pixelMaxY / tileSizeF))

        // Pre-allocate array size for performance
        let numTiles = (maxCol - minCol + 1) * (maxRow - minRow + 1)
        var tiles: [(TileCoordinate, CGRect)] = []
        tiles.reserveCapacity(numTiles)

        // Generate tile coordinates with their rects in image pixel space
        let imageWidth = imageSize.width
        let imageHeight = imageSize.height

        for row in minRow...maxRow {
            let tileY = CGFloat(row * currentTileSize)
            let tileH = min(tileSizeF, imageHeight - tileY)

            for col in minCol...maxCol {
                let tileX = CGFloat(col * currentTileSize)
                let tileW = min(tileSizeF, imageWidth - tileX)

                tiles.append((SIMD2(col, row), CGRect(x: tileX, y: tileY, width: tileW, height: tileH)))
            }
        }

        return tiles
    }

    /// Get downsampled source image (cached)
    func getSourceImage(from imageData: Data, quality: Double) -> CGImage? {
        let imageKey = "\(imageData.hashValue)-\(Int(quality * 100))"

        cacheLock.lock()
        if let cached = sourceImageCache[imageKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }

        let maxDimension = max(width, height)
        let targetPixelSize = CGFloat(maxDimension) * quality

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        cacheLock.lock()
        sourceImageCache[imageKey] = downsampledImage
        cacheLock.unlock()

        return downsampledImage
    }

    /// Get downsampled source image from URL (cached)
    func getSourceImage(from url: URL, quality: Double) -> CGImage? {
        let imageKey = "\(url.path)-\(Int(quality * 100))"

        cacheLock.lock()
        if let cached = sourceImageCache[imageKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }

        let maxDimension = max(width, height)
        let targetPixelSize = CGFloat(maxDimension) * quality

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        cacheLock.lock()
        sourceImageCache[imageKey] = downsampledImage
        cacheLock.unlock()

        return downsampledImage
    }

    /// Clear all cached images
    func clearCache() {
        cacheLock.lock()
        sourceImageCache.removeAll()
        cacheLock.unlock()
    }
}
