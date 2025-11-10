import Foundation
import AppKit
import ImageIO
import simd

/// Tile coordinate using SIMD for efficient computation (x=col, y=row)
typealias TileCoordinate = SIMD2<Int>

/// Manages image sources and calculates visible tiles (CATiledLayer approach)
class ImageTileCache {
    static let shared = ImageTileCache()

    private let tileSize: Int = 512  // 512x512 pixel tiles
    private var sourceImageCache: [String: CGImage] = [:]  // imageKey -> source image
    private var cacheLock = NSLock()

    private init() {}

    /// Get the tile size
    var tileSizePixels: Int { tileSize }

    /// Calculate which tiles intersect the viewport
    /// - Parameters:
    ///   - imageRect: The image bounds in canvas coordinates
    ///   - viewportRect: The visible viewport in canvas coordinates
    ///   - imageSize: The original image pixel dimensions
    /// - Returns: Array of tile coordinates and their rects in image coordinates
    func visibleTiles(imageRect: CGRect, viewportRect: CGRect, imageSize: CGSize) -> [(coord: TileCoordinate, rect: CGRect)] {
        guard imageRect.intersects(viewportRect) else { return [] }

        let intersection = imageRect.intersection(viewportRect)

        // Calculate scale from displayed size to actual image pixels
        let scaleX = imageSize.width / imageRect.width
        let scaleY = imageSize.height / imageRect.height

        // Convert intersection to pixel coordinates (relative to image origin)
        let pixelMinX = (intersection.minX - imageRect.minX) * scaleX
        let pixelMinY = (intersection.minY - imageRect.minY) * scaleY
        let pixelMaxX = (intersection.maxX - imageRect.minX) * scaleX
        let pixelMaxY = (intersection.maxY - imageRect.minY) * scaleY

        // Calculate tile range using integer math for speed
        let tileSizeF = CGFloat(tileSize)
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
            let tileY = CGFloat(row * tileSize)
            let tileH = min(tileSizeF, imageHeight - tileY)

            for col in minCol...maxCol {
                let tileX = CGFloat(col * tileSize)
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
