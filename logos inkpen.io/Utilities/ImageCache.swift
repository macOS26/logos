import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Manages downsampled image cache using disk-based scratch storage
class ImageCache {
    static let shared = ImageCache()

    // Lightweight memory cache for most recently used images only
    private var memoryCache = NSCache<NSString, CGImage>()

    // Disk cache directory
    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    private init() {
        // Use temporary directory for scratch disk
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("InkpenImageCache", isDirectory: true)
        diskCacheURL = tempDir

        // Create cache directory if needed
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Small memory cache for hot images only (10 images max, ~50MB)
        memoryCache.countLimit = 10
        memoryCache.totalCostLimit = 50 * 1024 * 1024

        // Clean old cache on init
        cleanOldCache()
    }

    /// Downsample and cache an image based on target display size
    /// - Parameters:
    ///   - imageData: The raw image data
    ///   - targetSize: The size at which the image will be displayed on screen (in points)
    ///   - scale: The display scale factor (1.0 for standard, 2.0 for retina)
    /// - Returns: Downsampled CGImage optimized for display
    func downsampledImage(from imageData: Data, targetSize: CGSize, scale: CGFloat) -> CGImage? {
        // Create cache key based on data hash and target size
        let cacheKey = "\(imageData.hashValue)-\(Int(targetSize.width))-\(Int(targetSize.height))-\(Int(scale))"

        // 1. Check memory cache first (fastest)
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }

        // 2. Check disk cache (fast)
        let diskURL = diskCacheURL.appendingPathComponent(cacheKey + ".png")
        if let diskImage = loadFromDisk(url: diskURL) {
            // Load into memory cache for next time
            let cost = diskImage.bytesPerRow * diskImage.height
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString, cost: cost)
            return diskImage
        }

        // 3. Downsample the image (slow)
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }

        let maxPixelSize = max(targetSize.width, targetSize.height) * scale

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCache: false
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        // 4. Save to disk cache
        saveToDisk(image: downsampledImage, url: diskURL)

        // 5. Save to memory cache (small, hot cache only)
        let cost = downsampledImage.bytesPerRow * downsampledImage.height
        memoryCache.setObject(downsampledImage, forKey: cacheKey as NSString, cost: cost)

        return downsampledImage
    }

    /// Downsample from a file URL
    func downsampledImage(from url: URL, targetSize: CGSize, scale: CGFloat) -> CGImage? {
        // Create cache key based on path and target size
        let cacheKey = "\(url.path)-\(Int(targetSize.width))-\(Int(targetSize.height))-\(Int(scale))"

        // 1. Check memory cache first
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            return cachedImage
        }

        // 2. Check disk cache
        let diskURL = diskCacheURL.appendingPathComponent(cacheKey.addingPercentEncoding(withAllowedCharacters: .alphanumerics)! + ".png")
        if let diskImage = loadFromDisk(url: diskURL) {
            let cost = diskImage.bytesPerRow * diskImage.height
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString, cost: cost)
            return diskImage
        }

        // 3. Downsample directly from source file
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let maxPixelSize = max(targetSize.width, targetSize.height) * scale

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCache: false
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        // 4. Save to disk
        saveToDisk(image: downsampledImage, url: diskURL)

        // 5. Save to memory cache
        let cost = downsampledImage.bytesPerRow * downsampledImage.height
        memoryCache.setObject(downsampledImage, forKey: cacheKey as NSString, cost: cost)

        return downsampledImage
    }

    // MARK: - Disk Cache Helpers

    private func saveToDisk(image: CGImage, url: URL) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    private func loadFromDisk(url: URL) -> CGImage? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }

    private func cleanOldCache() {
        // Remove cache files older than 7 days
        guard let urls = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)

        for url in urls {
            if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
               let modDate = attrs[.modificationDate] as? Date,
               modDate < cutoffDate {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// Clear the entire cache
    func clearCache() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    /// Clear cache for a specific image
    func clearCache(for key: String) {
        memoryCache.removeObject(forKey: key as NSString)
        let diskURL = diskCacheURL.appendingPathComponent(key + ".png")
        try? fileManager.removeItem(at: diskURL)
    }
}
