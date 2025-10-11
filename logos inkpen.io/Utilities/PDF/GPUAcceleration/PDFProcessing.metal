#include <metal_stdlib>
using namespace metal;

kernel void rgbToRGBA(
    const device uchar* rgbData [[buffer(0)]],
    const device uchar* maskData [[buffer(1)]],
    device uchar* rgbaData [[buffer(2)]],
    constant uint& hasMask [[buffer(3)]],
    uint gid [[thread_position_in_grid]])
{
    uint srcOffset = gid * 3;
    uint dstOffset = gid * 4;

    rgbaData[dstOffset + 0] = rgbData[srcOffset + 0];
    rgbaData[dstOffset + 1] = rgbData[srcOffset + 1];
    rgbaData[dstOffset + 2] = rgbData[srcOffset + 2];

    if (hasMask == 1) {
        rgbaData[dstOffset + 3] = maskData[gid];
    } else {
        rgbaData[dstOffset + 3] = 255;
    }
}

kernel void indexedToRGBA(
    const device uchar* indexData [[buffer(0)]],
    const device uchar* paletteData [[buffer(1)]],
    const device uchar* maskData [[buffer(2)]],
    device uchar* rgbaData [[buffer(3)]],
    constant uint& paletteEntries [[buffer(4)]],
    constant uint& hasMask [[buffer(5)]],
    uint gid [[thread_position_in_grid]])
{
    uint paletteIndex = indexData[gid];

    if (paletteIndex < paletteEntries) {
        uint paletteOffset = paletteIndex * 3;
        rgbaData[gid * 4 + 0] = paletteData[paletteOffset + 0];
        rgbaData[gid * 4 + 1] = paletteData[paletteOffset + 1];
        rgbaData[gid * 4 + 2] = paletteData[paletteOffset + 2];
    } else {
        rgbaData[gid * 4 + 0] = 0;
        rgbaData[gid * 4 + 1] = 0;
        rgbaData[gid * 4 + 2] = 0;
    }

    if (hasMask == 1) {
        rgbaData[gid * 4 + 3] = maskData[gid];
    } else {
        rgbaData[gid * 4 + 3] = 255;
    }
}


kernel void extractGradientColors8Bit(
    const device uchar* sampleData [[buffer(0)]],
    device float* colorOutput [[buffer(1)]],
    constant uint& outputComponents [[buffer(2)]],
    constant float* rangeMin [[buffer(3)]],
    constant float* rangeMax [[buffer(4)]],
    uint gid [[thread_position_in_grid]])
{
    uint baseOffset = gid * outputComponents;

    float r = float(sampleData[baseOffset + 0]) / 255.0;
    float g = float(sampleData[baseOffset + 1]) / 255.0;
    float b = float(sampleData[baseOffset + 2]) / 255.0;

    r = rangeMin[0] + r * (rangeMax[0] - rangeMin[0]);
    g = rangeMin[1] + g * (rangeMax[1] - rangeMin[1]);
    b = rangeMin[2] + b * (rangeMax[2] - rangeMin[2]);

    colorOutput[gid * 3 + 0] = r;
    colorOutput[gid * 3 + 1] = g;
    colorOutput[gid * 3 + 2] = b;
}


kernel void find_nearest_point(
    const device float2* points [[buffer(0)]],
    const device float2* tapLocation [[buffer(1)]],
    const device float* selectionRadius [[buffer(2)]],
    device float* distances [[buffer(3)]],
    device uint* validIndices [[buffer(4)]],
    uint gid [[thread_position_in_grid]])
{
    float2 point = points[gid];
    float2 tap = *tapLocation;

    float dx = point.x - tap.x;
    float dy = point.y - tap.y;
    float dist = sqrt(dx * dx + dy * dy);

    distances[gid] = dist;
    validIndices[gid] = (dist <= *selectionRadius) ? gid : UINT_MAX;
}

kernel void find_min_distance_index(
    const device float* distances [[buffer(0)]],
    const device uint* validIndices [[buffer(1)]],
    device atomic_uint* minIndex [[buffer(2)]],
    device atomic_float* minDistance [[buffer(3)]],
    constant uint& numPoints [[buffer(4)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid < numPoints && validIndices[gid] != UINT_MAX) {
        float dist = distances[gid];

        float currentMin = atomic_load_explicit((device atomic_float*)minDistance, memory_order_relaxed);

        while (dist < currentMin) {
            float expected = currentMin;
            if (atomic_compare_exchange_weak_explicit(
                (device atomic_float*)minDistance,
                &expected,
                dist,
                memory_order_relaxed,
                memory_order_relaxed)) {
                atomic_store_explicit(minIndex, gid, memory_order_relaxed);
                break;
            }
            currentMin = expected;
        }
    }
}

kernel void find_points_in_radius(
    const device float2* points [[buffer(0)]],
    const device float2* tapLocation [[buffer(1)]],
    const device float* selectionRadius [[buffer(2)]],
    device uint* matchingIndices [[buffer(3)]],
    device atomic_uint* matchCount [[buffer(4)]],
    constant uint& maxMatches [[buffer(5)]],
    uint gid [[thread_position_in_grid]])
{
    float2 point = points[gid];
    float2 tap = *tapLocation;
    float dx = point.x - tap.x;
    float dy = point.y - tap.y;
    float dist = sqrt(dx * dx + dy * dy);

    if (dist <= *selectionRadius) {
        uint index = atomic_fetch_add_explicit(matchCount, 1, memory_order_relaxed);
        if (index < maxMatches) {
            matchingIndices[index] = gid;
        }
    }
}


kernel void find_nearest_handle(
    const device float2* handlePoints [[buffer(0)]],
    const device float2* anchorPoints [[buffer(1)]],
    const device float2* tapLocation [[buffer(2)]],
    const device float* handleRadius [[buffer(3)]],
    device float* distances [[buffer(4)]],
    device uint* validIndices [[buffer(5)]],
    uint gid [[thread_position_in_grid]])
{
    float2 handle = handlePoints[gid];
    float2 anchor = anchorPoints[gid];
    float2 tap = *tapLocation;

    float2 handleToAnchor = handle - anchor;
    float handleLength = sqrt(handleToAnchor.x * handleToAnchor.x + handleToAnchor.y * handleToAnchor.y);

    if (handleLength < 0.1) {
        distances[gid] = INFINITY;
        validIndices[gid] = UINT_MAX;
        return;
    }

    float dx = handle.x - tap.x;
    float dy = handle.y - tap.y;
    float dist = sqrt(dx * dx + dy * dy);

    distances[gid] = dist;
    validIndices[gid] = (dist <= *handleRadius) ? gid : UINT_MAX;
}


kernel void rasterizePathSegments(
    const device float2* pathPoints [[buffer(0)]],
    device uchar* rasterBuffer [[buffer(1)]],
    constant uint& width [[buffer(2)]],
    constant uint& height [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]])
{
}
