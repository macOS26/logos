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

    /// Downsample and cache an image based on quality preference
    /// - Parameters:
    ///   - imageData: The raw image data
    /// - Returns: Downsampled CGImage based on user's quality setting
    func downsampledImage(from imageData: Data) -> CGImage? {
        // Get quality setting from preferences
        let quality = ApplicationSettings.shared.imagePreviewQuality

        // Create cache key based on data hash and quality
        let cacheKey = "\(imageData.hashValue)-\(Int(quality * 100))" as NSString

        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        // Downsample the image based on quality setting
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return nil
        }

        // Get original image dimensions
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        // Calculate max pixel size based on quality setting
        // quality: 0.1 (10%) to 1.0 (100%)
        let maxDimension = max(width, height)
        let maxPixelSize = maxDimension * quality

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

    /// Downsample from a file URL based on quality preference
    func downsampledImage(from url: URL) -> CGImage? {
        // Get quality setting from preferences
        let quality = ApplicationSettings.shared.imagePreviewQuality

        // Create cache key based on path and quality
        let cacheKey = "\(url.path)-\(Int(quality * 100))" as NSString

        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        // Downsample directly from file (more efficient than loading full image)
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        // Get original image dimensions
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }

        // Calculate max pixel size based on quality setting
        let maxDimension = max(width, height)
        let maxPixelSize = maxDimension * quality

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
