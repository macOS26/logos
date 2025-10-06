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

// MARK: - Point Selection Kernels (Direct Select Tool Acceleration)

/// Find nearest point to tap location - ULTRA FAST parallel distance calculation
/// Used by direct select tool for instant point/handle selection on objects with thousands of points
kernel void find_nearest_point(
    const device float2* points [[buffer(0)]],              // All point positions in canvas space
    const device float2* tapLocation [[buffer(1)]],         // Tap location in canvas space
    const device float* selectionRadius [[buffer(2)]],      // Selection radius (tolerance)
    device float* distances [[buffer(3)]],                  // Output: distances from tap to each point
    device uint* validIndices [[buffer(4)]],                // Output: indices of points within radius
    uint gid [[thread_position_in_grid]])                   // Global thread ID = point index
{
    // Each thread processes one point in parallel
    float2 point = points[gid];
    float2 tap = *tapLocation;

    // Calculate distance from tap to this point
    float dx = point.x - tap.x;
    float dy = point.y - tap.y;
    float dist = sqrt(dx * dx + dy * dy);

    // Store distance and mark if within selection radius
    distances[gid] = dist;
    validIndices[gid] = (dist <= *selectionRadius) ? gid : UINT_MAX;
}

/// Find minimum distance index from parallel distance results
/// Two-stage reduction for finding closest point
kernel void find_min_distance_index(
    const device float* distances [[buffer(0)]],            // Distances computed by find_nearest_point
    const device uint* validIndices [[buffer(1)]],          // Valid indices from find_nearest_point
    device atomic_uint* minIndex [[buffer(2)]],             // Output: index of closest point
    device atomic_float* minDistance [[buffer(3)]],         // Output: minimum distance found
    constant uint& numPoints [[buffer(4)]],                 // Total number of points
    uint gid [[thread_position_in_grid]])                   // Global thread ID
{
    // Each thread checks one point
    if (gid < numPoints && validIndices[gid] != UINT_MAX) {
        float dist = distances[gid];

        // Atomic compare-and-swap to find minimum
        // Read current minimum
        float currentMin = atomic_load_explicit((device atomic_float*)minDistance, memory_order_relaxed);

        // If this distance is smaller, try to update
        while (dist < currentMin) {
            float expected = currentMin;
            if (atomic_compare_exchange_weak_explicit(
                (device atomic_float*)minDistance,
                &expected,
                dist,
                memory_order_relaxed,
                memory_order_relaxed)) {
                // Successfully updated minimum distance, also update index
                atomic_store_explicit(minIndex, gid, memory_order_relaxed);
                break;
            }
            currentMin = expected;
        }
    }
}

/// Find all points within selection radius (for multi-select scenarios)
/// Returns count and indices of all points within tolerance
kernel void find_points_in_radius(
    const device float2* points [[buffer(0)]],              // All point positions
    const device float2* tapLocation [[buffer(1)]],         // Tap location
    const device float* selectionRadius [[buffer(2)]],      // Selection radius
    device uint* matchingIndices [[buffer(3)]],             // Output: indices of points within radius
    device atomic_uint* matchCount [[buffer(4)]],           // Output: count of matching points
    constant uint& maxMatches [[buffer(5)]],                // Maximum matches to return
    uint gid [[thread_position_in_grid]])                   // Global thread ID = point index
{
    // Calculate distance
    float2 point = points[gid];
    float2 tap = *tapLocation;
    float dx = point.x - tap.x;
    float dy = point.y - tap.y;
    float dist = sqrt(dx * dx + dy * dy);

    // If within radius, add to results atomically
    if (dist <= *selectionRadius) {
        uint index = atomic_fetch_add_explicit(matchCount, 1, memory_order_relaxed);
        if (index < maxMatches) {
            matchingIndices[index] = gid;
        }
    }
}

// MARK: - Handle Selection Kernels

/// Find nearest handle to tap location with handle-specific parameters
/// Handles use different selection radius than anchor points
kernel void find_nearest_handle(
    const device float2* handlePoints [[buffer(0)]],        // Handle positions
    const device float2* anchorPoints [[buffer(1)]],        // Corresponding anchor positions
    const device float2* tapLocation [[buffer(2)]],         // Tap location
    const device float* handleRadius [[buffer(3)]],         // Handle selection radius (typically smaller)
    device float* distances [[buffer(4)]],                  // Output: distances
    device uint* validIndices [[buffer(5)]],                // Output: valid indices
    uint gid [[thread_position_in_grid]])                   // Global thread ID = handle index
{
    float2 handle = handlePoints[gid];
    float2 anchor = anchorPoints[gid];
    float2 tap = *tapLocation;

    // Check if handle is collapsed (too close to anchor point)
    float2 handleToAnchor = handle - anchor;
    float handleLength = sqrt(handleToAnchor.x * handleToAnchor.x + handleToAnchor.y * handleToAnchor.y);

    // Skip collapsed handles (threshold: 0.1 canvas units)
    if (handleLength < 0.1) {
        distances[gid] = INFINITY;
        validIndices[gid] = UINT_MAX;
        return;
    }

    // Calculate distance from tap to handle
    float dx = handle.x - tap.x;
    float dy = handle.y - tap.y;
    float dist = sqrt(dx * dx + dy * dy);

    // Store distance and mark if within selection radius
    distances[gid] = dist;
    validIndices[gid] = (dist <= *handleRadius) ? gid : UINT_MAX;
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
