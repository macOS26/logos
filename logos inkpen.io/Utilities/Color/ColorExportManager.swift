//
//  ColorExportManager.swift
//  logos inkpen.io
//
//  Centralized color management for image export with proper P3 support
//

import SwiftUI
import UniformTypeIdentifiers

/// Manages color space conversion and profile embedding for image exports
final class ColorExportManager {

    static let shared = ColorExportManager()

    private init() {}

    // MARK: - Export Types

    enum ExportFormat {
        case png
    }

    enum ColorSpaceOption {
        case displayP3
        case sRGB
        case adobeRGB
    }

    // MARK: - Main Export Function

    /// Exports a CGImage with proper color space conversion and profile embedding
    /// - Parameters:
    ///   - cgImage: The source CGImage to export
    ///   - format: The export format (PNG or JPEG with quality)
    ///   - colorSpace: The target color space (default: Display P3)
    ///   - outputURL: The destination URL for the exported file
    /// - Returns: Success status
    @discardableResult
    func exportImage(
        _ cgImage: CGImage,
        format: ExportFormat,
        colorSpace: ColorSpaceOption = .displayP3,
        to outputURL: URL
    ) throws -> Bool {

        // Create CIImage from CGImage for color space conversion
        let ciImage = CIImage(cgImage: cgImage)

        // Get the target color space
        let targetColorSpace = getColorSpace(for: colorSpace)

        // Apply color space conversion - matchedFromWorkingSpace is the CIImage API equivalent
        // to the concept shown in the user's example
        let convertedCIImage = ciImage.matchedFromWorkingSpace(to: targetColorSpace) ?? ciImage

        // Create a CIContext to render the CIImage to a CGImage
        // This ensures proper color management during the conversion
        let context = CIContext(options: [
            .workingColorSpace: targetColorSpace,
            .outputColorSpace: targetColorSpace
        ])

        // Render the CIImage to a new CGImage in the target color space
        guard let finalCGImage = context.createCGImage(
            convertedCIImage,
            from: convertedCIImage.extent,
            format: .RGBA8,
            colorSpace: targetColorSpace
        ) else {
            throw ExportError.imageConversionFailed
        }

        // Export based on format
        switch format {
        case .png:
            return try exportAsPNG(finalCGImage, colorSpace: colorSpace, to: outputURL)
        }
    }

    // MARK: - PNG Export

    private func exportAsPNG(
        _ cgImage: CGImage,
        colorSpace: ColorSpaceOption,
        to outputURL: URL
    ) throws -> Bool {

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.destinationCreationFailed
        }

        // Set properties for PNG with color profile
        let properties = getImageProperties(for: colorSpace)

        // Add the image with properties
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        // Set file-level properties to ensure profile is embedded
        let fileProperties = getFileProperties(for: colorSpace)
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)

        // Finalize the export
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.finalizationFailed
        }

        return true
    }

// MARK: - Helper Methods

    private func getColorSpace(for option: ColorSpaceOption) -> CGColorSpace {
        switch option {
        case .displayP3:
            return CGColorSpace(name: CGColorSpace.displayP3) ?? ColorManager.shared.displayP3CG
        case .sRGB:
            return CGColorSpace(name: CGColorSpace.sRGB) ?? ColorManager.shared.sRGBCG
        case .adobeRGB:
            return CGColorSpace(name: CGColorSpace.adobeRGB1998) ?? ColorManager.shared.sRGBCG
        }
    }

    private func getProfileName(for option: ColorSpaceOption) -> String {
        switch option {
        case .displayP3:
            return "Display P3"
        case .sRGB:
            return "sRGB IEC61966-2.1"
        case .adobeRGB:
            return "Adobe RGB (1998)"
        }
    }

    private func getImageProperties(for colorSpace: ColorSpaceOption) -> [CFString: Any] {
        return [
            kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
            kCGImagePropertyProfileName: getProfileName(for: colorSpace) as CFString,
            // Ensure proper color management
            kCGImagePropertyHasAlpha: true as CFBoolean
        ]
    }

    private func getFileProperties(for colorSpace: ColorSpaceOption) -> [CFString: Any] {
        return [
            kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
            kCGImagePropertyProfileName: getProfileName(for: colorSpace) as CFString
        ]
    }

    // MARK: - Error Types

    enum ExportError: LocalizedError {
        case imageConversionFailed
        case destinationCreationFailed
        case finalizationFailed

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed:
                return "Failed to convert image to target color space"
            case .destinationCreationFailed:
                return "Failed to create image destination"
            case .finalizationFailed:
                return "Failed to finalize image export"
            }
        }
    }
}

// MARK: - Convenience Extensions

extension ColorExportManager {

    /// Export from context (for direct rendering exports)
    @discardableResult
    func exportFromContext(
        _ context: CGContext,
        format: ExportFormat,
        colorSpace: ColorSpaceOption = .displayP3,
        to outputURL: URL
    ) throws -> Bool {

        guard let cgImage = context.makeImage() else {
            throw ExportError.imageConversionFailed
        }

        return try exportImage(cgImage, format: format, colorSpace: colorSpace, to: outputURL)
    }
}
