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

/// Cached tile data
struct ImageTile {
    let coordinate: TileCoordinate
    let image: CGImage
    let rect: CGRect  // Position in original image coordinates
}

/// Manages tiled image loading and caching with viewport culling
class ImageTileCache {
    static let shared = ImageTileCache()

    private let tileSize: Int = 512  // 512x512 pixel tiles
    private var tileCache: [String: [TileCoordinate: CGImage]] = [:]  // imageKey -> tiles
    private var tileCacheLock = NSLock()

    private let maxCachedTiles = 200  // Maximum tiles in memory
    private var tileAccessOrder: [(String, TileCoordinate)] = []  // LRU tracking

    private init() {}

    /// Get the tile size
    var tileSizePixels: Int { tileSize }

    /// Calculate which tiles are visible in the viewport
    /// - Parameters:
    ///   - imageRect: The image bounds in canvas coordinates
    ///   - viewportRect: The visible viewport in canvas coordinates
    ///   - imageSize: The original image dimensions
    /// - Returns: Array of tile coordinates that are visible
    func visibleTiles(imageRect: CGRect, viewportRect: CGRect, imageSize: CGSize) -> [TileCoordinate] {
        // Calculate intersection
        guard imageRect.intersects(viewportRect) else { return [] }
        let intersection = imageRect.intersection(viewportRect)

        // Convert intersection to image-local coordinates
        let localIntersection = CGRect(
            x: intersection.origin.x - imageRect.origin.x,
            y: intersection.origin.y - imageRect.origin.y,
            width: intersection.width,
            height: intersection.height
        )

        // Calculate scale factor (image rect vs actual image size)
        let scaleX = imageSize.width / imageRect.width
        let scaleY = imageSize.height / imageRect.height

        // Convert to pixel coordinates in original image
        let pixelIntersection = CGRect(
            x: localIntersection.origin.x * scaleX,
            y: localIntersection.origin.y * scaleY,
            width: localIntersection.width * scaleX,
            height: localIntersection.height * scaleY
        )

        // Calculate tile range using SIMD
        let minCol = max(0, Int(floor(pixelIntersection.minX / CGFloat(tileSize))))
        let maxCol = min(Int(ceil(imageSize.width / CGFloat(tileSize))) - 1,
                        Int(ceil(pixelIntersection.maxX / CGFloat(tileSize))))
        let minRow = max(0, Int(floor(pixelIntersection.minY / CGFloat(tileSize))))
        let maxRow = min(Int(ceil(imageSize.height / CGFloat(tileSize))) - 1,
                        Int(ceil(pixelIntersection.maxY / CGFloat(tileSize))))

        // Generate tile coordinates
        var tiles: [TileCoordinate] = []
        for row in minRow...maxRow {
            for col in minCol...maxCol {
                tiles.append(TileCoordinate(col: col, row: row))
            }
        }

        return tiles
    }

    /// Load tiles for an image from data
    /// - Parameters:
    ///   - imageData: The image data
    ///   - tileCoords: Which tiles to load
    ///   - quality: Quality factor (0.1-1.0)
    /// - Returns: Dictionary of loaded tiles
    func loadTiles(from imageData: Data, tiles tileCoords: [TileCoordinate], quality: Double) -> [TileCoordinate: CGImage] {
        let imageKey = "\(imageData.hashValue)-\(Int(quality * 100))"

        var loadedTiles: [TileCoordinate: CGImage] = [:]

        // Check cache first
        tileCacheLock.lock()
        if let cachedImageTiles = tileCache[imageKey] {
            for coord in tileCoords {
                if let tile = cachedImageTiles[coord] {
                    loadedTiles[coord] = tile
                    // Update LRU
                    updateAccessOrder(imageKey: imageKey, tileCoord: coord)
                }
            }
        }
        tileCacheLock.unlock()

        // Load missing tiles
        let missingTiles = tileCoords.filter { loadedTiles[$0] == nil }
        guard !missingTiles.isEmpty else { return loadedTiles }

        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return loadedTiles
        }

        // Get original image properties
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return loadedTiles
        }

        // Decode full image at quality level (we need source to extract tiles)
        let maxDimension = max(width, height)
        let targetPixelSize = CGFloat(maxDimension) * quality

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]

        guard let fullImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return loadedTiles
        }

        let scaledWidth = fullImage.width
        let scaledHeight = fullImage.height
        let scaleX = CGFloat(scaledWidth) / CGFloat(width)
        let scaleY = CGFloat(scaledHeight) / CGFloat(height)

        // Extract tiles
        for coord in missingTiles {
            let tileX = coord.col * tileSize
            let tileY = coord.row * tileSize
            let tileW = min(tileSize, width - tileX)
            let tileH = min(tileSize, height - tileY)

            // Scale to actual decoded image size
            let scaledRect = CGRect(
                x: CGFloat(tileX) * scaleX,
                y: CGFloat(tileY) * scaleY,
                width: CGFloat(tileW) * scaleX,
                height: CGFloat(tileH) * scaleY
            )

            if let tileImage = fullImage.cropping(to: scaledRect) {
                loadedTiles[coord] = tileImage

                // Cache the tile
                tileCacheLock.lock()
                if tileCache[imageKey] == nil {
                    tileCache[imageKey] = [:]
                }
                tileCache[imageKey]?[coord] = tileImage
                updateAccessOrder(imageKey: imageKey, tileCoord: coord)
                enforceCacheLimit()
                tileCacheLock.unlock()
            }
        }

        return loadedTiles
    }

    /// Load tiles from file URL
    func loadTiles(from url: URL, tiles tileCoords: [TileCoordinate], quality: Double) -> [TileCoordinate: CGImage] {
        let imageKey = "\(url.path)-\(Int(quality * 100))"

        var loadedTiles: [TileCoordinate: CGImage] = [:]

        // Check cache
        tileCacheLock.lock()
        if let cachedImageTiles = tileCache[imageKey] {
            for coord in tileCoords {
                if let tile = cachedImageTiles[coord] {
                    loadedTiles[coord] = tile
                    updateAccessOrder(imageKey: imageKey, tileCoord: coord)
                }
            }
        }
        tileCacheLock.unlock()

        // Load missing tiles
        let missingTiles = tileCoords.filter { loadedTiles[$0] == nil }
        guard !missingTiles.isEmpty else { return loadedTiles }

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return loadedTiles
        }

        // Get original image properties
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return loadedTiles
        }

        // Decode and extract tiles (same as data version)
        let maxDimension = max(width, height)
        let targetPixelSize = CGFloat(maxDimension) * quality

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetPixelSize,
            kCGImageSourceShouldCache: false
        ]

        guard let fullImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return loadedTiles
        }

        let scaledWidth = fullImage.width
        let scaledHeight = fullImage.height
        let scaleX = CGFloat(scaledWidth) / CGFloat(width)
        let scaleY = CGFloat(scaledHeight) / CGFloat(height)

        for coord in missingTiles {
            let tileX = coord.col * tileSize
            let tileY = coord.row * tileSize
            let tileW = min(tileSize, width - tileX)
            let tileH = min(tileSize, height - tileY)

            let scaledRect = CGRect(
                x: CGFloat(tileX) * scaleX,
                y: CGFloat(tileY) * scaleY,
                width: CGFloat(tileW) * scaleX,
                height: CGFloat(tileH) * scaleY
            )

            if let tileImage = fullImage.cropping(to: scaledRect) {
                loadedTiles[coord] = tileImage

                tileCacheLock.lock()
                if tileCache[imageKey] == nil {
                    tileCache[imageKey] = [:]
                }
                tileCache[imageKey]?[coord] = tileImage
                updateAccessOrder(imageKey: imageKey, tileCoord: coord)
                enforceCacheLimit()
                tileCacheLock.unlock()
            }
        }

        return loadedTiles
    }

    // LRU cache management
    private func updateAccessOrder(imageKey: String, tileCoord: TileCoordinate) {
        // Remove if exists
        tileAccessOrder.removeAll { $0.0 == imageKey && $0.1 == tileCoord }
        // Add to end (most recently used)
        tileAccessOrder.append((imageKey, tileCoord))
    }

    private func enforceCacheLimit() {
        while tileAccessOrder.count > maxCachedTiles {
            let (oldKey, oldCoord) = tileAccessOrder.removeFirst()
            tileCache[oldKey]?.removeValue(forKey: oldCoord)
            if tileCache[oldKey]?.isEmpty == true {
                tileCache.removeValue(forKey: oldKey)
            }
        }
    }

    /// Clear all cached tiles
    func clearCache() {
        tileCacheLock.lock()
        tileCache.removeAll()
        tileAccessOrder.removeAll()
        tileCacheLock.unlock()
    }
}
