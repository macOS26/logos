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
        // Use provided tile size or default to preferences
        let currentTileSize = tileSize ?? tileSizePixels

        // Calculate total number of tiles in the image
        let numCols = Int(ceil(imageSize.width / CGFloat(currentTileSize)))
        let numRows = Int(ceil(imageSize.height / CGFloat(currentTileSize)))

        var tiles: [(TileCoordinate, CGRect)] = []

        // Return ALL tiles - no culling
        for row in 0..<numRows {
            for col in 0..<numCols {
                let tileX = CGFloat(col * currentTileSize)
                let tileY = CGFloat(row * currentTileSize)
                let tileW = min(CGFloat(currentTileSize), imageSize.width - tileX)
                let tileH = min(CGFloat(currentTileSize), imageSize.height - tileY)
                let tileRect = CGRect(x: tileX, y: tileY, width: tileW, height: tileH)

                tiles.append((SIMD2(col, row), tileRect))
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

        print("📊 ImageTileCache [Data]: original=\(width)×\(height), quality=\(quality), target=\(Int(targetPixelSize))px")

        // Use thumbnail API for all cases, but set size to full resolution when quality is 1.0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]

        let resultImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)

        guard let downsampledImage = resultImage else {
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

        print("📊 ImageTileCache [URL]: original=\(width)×\(height), quality=\(quality), target=\(Int(targetPixelSize))px")

        // Use thumbnail API for all cases, but set size to full resolution when quality is 1.0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]

        let resultImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)

        guard let downsampledImage = resultImage else {
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
