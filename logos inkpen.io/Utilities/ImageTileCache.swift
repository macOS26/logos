import Foundation
import AppKit
import ImageIO
import simd

/// Represents a tile coordinate using SIMD for efficient computation
struct TileCoordinate: Hashable {
    let coord: SIMD2<Int>  // (col, row)

    init(col: Int, row: Int) {
        self.coord = SIMD2(col, row)
    }

    var col: Int { coord.x }
    var row: Int { coord.y }
}

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

        // Convert intersection to image-local coordinates (0,0 = top-left of image)
        let localIntersection = CGRect(
            x: intersection.origin.x - imageRect.origin.x,
            y: intersection.origin.y - imageRect.origin.y,
            width: intersection.width,
            height: intersection.height
        )

        // Calculate scale from displayed size to actual image pixels
        let scaleX = imageSize.width / imageRect.width
        let scaleY = imageSize.height / imageRect.height

        // Convert to pixel coordinates
        let pixelIntersection = CGRect(
            x: localIntersection.origin.x * scaleX,
            y: localIntersection.origin.y * scaleY,
            width: localIntersection.width * scaleX,
            height: localIntersection.height * scaleY
        )

        // Calculate tile range
        let minCol = max(0, Int(floor(pixelIntersection.minX / CGFloat(tileSize))))
        let maxCol = min(Int(ceil(imageSize.width / CGFloat(tileSize))) - 1,
                        Int(ceil(pixelIntersection.maxX / CGFloat(tileSize))))
        let minRow = max(0, Int(floor(pixelIntersection.minY / CGFloat(tileSize))))
        let maxRow = min(Int(ceil(imageSize.height / CGFloat(tileSize))) - 1,
                        Int(ceil(pixelIntersection.maxY / CGFloat(tileSize))))

        // Generate tile coordinates with their rects in image pixel space
        var tiles: [(TileCoordinate, CGRect)] = []
        for row in minRow...maxRow {
            for col in minCol...maxCol {
                let tileX = CGFloat(col * tileSize)
                let tileY = CGFloat(row * tileSize)
                let tileW = min(CGFloat(tileSize), imageSize.width - tileX)
                let tileH = min(CGFloat(tileSize), imageSize.height - tileY)

                let tileRect = CGRect(x: tileX, y: tileY, width: tileW, height: tileH)
                tiles.append((TileCoordinate(col: col, row: row), tileRect))
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
