//
//  PDFProcessing.metal
//  logos inkpen.io
//
//  GPU-accelerated PDF processing kernels
//  Created by Claude on 1/13/25.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Image Processing Kernels

/// Convert RGB image data to RGBA by adding alpha channel
/// Optimized for large PDF images - runs in parallel on GPU
kernel void rgbToRGBA(
    const device uchar* rgbData [[buffer(0)]],      // Input RGB data (3 bytes per pixel)
    const device uchar* maskData [[buffer(1)]],     // Optional mask data (1 byte per pixel alpha)
    device uchar* rgbaData [[buffer(2)]],           // Output RGBA data (4 bytes per pixel)
    constant uint& hasMask [[buffer(3)]],           // 1 if mask exists, 0 otherwise
    uint gid [[thread_position_in_grid]])           // Global thread ID = pixel index
{
    // Each thread processes one pixel
    uint srcOffset = gid * 3;  // RGB = 3 bytes per pixel
    uint dstOffset = gid * 4;  // RGBA = 4 bytes per pixel

    // Copy RGB components
    rgbaData[dstOffset + 0] = rgbData[srcOffset + 0];  // R
    rgbaData[dstOffset + 1] = rgbData[srcOffset + 1];  // G
    rgbaData[dstOffset + 2] = rgbData[srcOffset + 2];  // B

    // Add alpha component from mask or default to 255 (opaque)
    if (hasMask == 1) {
        rgbaData[dstOffset + 3] = maskData[gid];
    } else {
        rgbaData[dstOffset + 3] = 255;
    }
}

/// Convert indexed color (palette-based) to RGBA
/// Each pixel is an index into a color palette
kernel void indexedToRGBA(
    const device uchar* indexData [[buffer(0)]],    // Input index data (1 byte per pixel)
    const device uchar* paletteData [[buffer(1)]],  // Color palette (3 bytes per entry - RGB)
    const device uchar* maskData [[buffer(2)]],     // Optional mask data (1 byte per pixel alpha)
    device uchar* rgbaData [[buffer(3)]],           // Output RGBA data (4 bytes per pixel)
    constant uint& paletteEntries [[buffer(4)]],    // Number of palette entries
    constant uint& hasMask [[buffer(5)]],           // 1 if mask exists, 0 otherwise
    uint gid [[thread_position_in_grid]])           // Global thread ID = pixel index
{
    // Get palette index for this pixel
    uint paletteIndex = indexData[gid];

    // Bounds check - use black if out of range
    if (paletteIndex < paletteEntries) {
        uint paletteOffset = paletteIndex * 3;
        rgbaData[gid * 4 + 0] = paletteData[paletteOffset + 0];  // R
        rgbaData[gid * 4 + 1] = paletteData[paletteOffset + 1];  // G
        rgbaData[gid * 4 + 2] = paletteData[paletteOffset + 2];  // B
    } else {
        rgbaData[gid * 4 + 0] = 0;  // R = black
        rgbaData[gid * 4 + 1] = 0;  // G = black
        rgbaData[gid * 4 + 2] = 0;  // B = black
    }

    // Add alpha component
    if (hasMask == 1) {
        rgbaData[gid * 4 + 3] = maskData[gid];
    } else {
        rgbaData[gid * 4 + 3] = 255;
    }
}

// MARK: - Gradient Processing Kernels

/// Extract RGB colors from sampled function stream (8-bit samples)
/// Used for PDF gradient extraction
kernel void extractGradientColors8Bit(
    const device uchar* sampleData [[buffer(0)]],       // Input sample data
    device float* colorOutput [[buffer(1)]],            // Output colors (RGB float triplets)
    constant uint& outputComponents [[buffer(2)]],      // Number of output components (typically 3 for RGB)
    constant float* rangeMin [[buffer(3)]],             // Range minimum values [rMin, gMin, bMin]
    constant float* rangeMax [[buffer(4)]],             // Range maximum values [rMax, gMax, bMax]
    uint gid [[thread_position_in_grid]])               // Global thread ID = sample index
{
    // Each thread processes one color sample
    uint baseOffset = gid * outputComponents;

    // Read RGB values (8-bit, normalize to 0-1)
    float r = float(sampleData[baseOffset + 0]) / 255.0;
    float g = float(sampleData[baseOffset + 1]) / 255.0;
    float b = float(sampleData[baseOffset + 2]) / 255.0;

    // Apply range scaling
    r = rangeMin[0] + r * (rangeMax[0] - rangeMin[0]);
    g = rangeMin[1] + g * (rangeMax[1] - rangeMin[1]);
    b = rangeMin[2] + b * (rangeMax[2] - rangeMin[2]);

    // Write output colors
    colorOutput[gid * 3 + 0] = r;
    colorOutput[gid * 3 + 1] = g;
    colorOutput[gid * 3 + 2] = b;
}

// MARK: - Path Processing Kernels (Future Enhancement)

/// Rasterize PDF path segments for faster hit testing
/// This can be used for complex PDFs with thousands of paths
kernel void rasterizePathSegments(
    const device float2* pathPoints [[buffer(0)]],     // Path point coordinates
    device uchar* rasterBuffer [[buffer(1)]],          // Output raster buffer
    constant uint& width [[buffer(2)]],                // Raster width
    constant uint& height [[buffer(3)]],               // Raster height
    uint2 gid [[thread_position_in_grid]])             // 2D thread position
{
    // Future: Implement path rasterization for faster rendering preview
    // This would allow real-time preview of large PDFs during import
}
