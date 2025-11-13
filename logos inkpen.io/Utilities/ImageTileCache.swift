import Foundation
import AppKit
import ImageIO
import simd

/// Tile coordinate using SIMD for efficient computation (x=col, y=row)
typealias TileCoordinate = SIMD2<Int>

/// Manages image sources and calculates visible tiles (CATiledLayer approach)
class ImageTileCache {
    static let shared = ImageTileCache()

    private init() {}

    /// Get the current tile size from preferences
    var tileSizePixels: Int {
        UserDefaults.standard.object(forKey: "imageTileSize") as? Int ?? 512
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

    /// Get downsampled source image (no caching - render directly)
    func getSourceImage(from imageData: Data, quality: Double, shapeID: UUID) -> CGImage? {
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

        // Use thumbnail API for all cases, but set size to full resolution when quality is 1.0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]

        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }

    /// Get downsampled source image from URL (no caching - render directly)
    func getSourceImage(from url: URL, quality: Double, shapeID: UUID) -> CGImage? {
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

        // Use thumbnail API for all cases, but set size to full resolution when quality is 1.0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]

        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }
}
