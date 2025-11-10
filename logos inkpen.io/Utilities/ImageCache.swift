import Foundation
import AppKit
import ImageIO

/// Manages downsampled image cache for performance
class ImageCache {
    static let shared = ImageCache()

    private var cache = NSCache<NSString, CGImage>()

    private init() {
        cache.countLimit = 100  // Maximum 100 cached images
        cache.totalCostLimit = 500 * 1024 * 1024  // 500MB cache limit
    }

    /// Downsample and cache an image to a reasonable display size
    /// - Parameters:
    ///   - imageData: The raw image data
    /// - Returns: Downsampled CGImage (max 2048px) - let GPU handle further scaling
    func downsampledImage(from imageData: Data) -> CGImage? {
        // Create cache key based on data hash only (single cached version)
        let cacheKey = "\(imageData.hashValue)" as NSString

        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        // Downsample the image to reasonable size (2048px max)
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }

        // Fixed max size - good balance between quality and memory
        // GPU scaling is fast, so we don't need multiple versions
        let maxPixelSize: CGFloat = 2048

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCache: false  // Don't cache full image
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        // Cache the downsampled image
        let cost = downsampledImage.bytesPerRow * downsampledImage.height
        cache.setObject(downsampledImage, forKey: cacheKey, cost: cost)

        return downsampledImage
    }

    /// Downsample from a file URL to reasonable size (max 2048px)
    func downsampledImage(from url: URL) -> CGImage? {
        // Create cache key based on path only (single cached version per file)
        let cacheKey = url.path as NSString

        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        // Downsample directly from file (more efficient than loading full image)
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        // Fixed max size - GPU handles the rest
        let maxPixelSize: CGFloat = 2048

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCache: false
        ]

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        // Cache the downsampled image
        let cost = downsampledImage.bytesPerRow * downsampledImage.height
        cache.setObject(downsampledImage, forKey: cacheKey, cost: cost)

        return downsampledImage
    }

    /// Clear the entire cache
    func clearCache() {
        cache.removeAllObjects()
    }

    /// Clear cache for a specific image
    func clearCache(for key: String) {
        cache.removeObject(forKey: key as NSString)
    }
}
