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

// Path segment types
#define PATH_MOVE 0
#define PATH_LINE 1
#define PATH_CURVE 2
#define PATH_QUAD 3
#define PATH_CLOSE 4

struct PathSegment {
    uint type;           // Path element type
    float2 point;        // End point (for all except close)
    float2 control1;     // First control point (for curves)
    float2 control2;     // Second control point (for cubic curves)
};

// Distance from point to line segment
float distanceToLineSegment(float2 p, float2 a, float2 b) {
    float2 ab = b - a;
    float2 ap = p - a;

    float abLenSq = dot(ab, ab);
    if (abLenSq < 0.0001) {
        return length(ap);
    }

    float t = clamp(dot(ap, ab) / abLenSq, 0.0f, 1.0f);
    float2 closest = a + t * ab;
    return length(p - closest);
}

// Distance from point to cubic bezier curve (approximate via sampling)
float distanceToCubicBezier(float2 p, float2 p0, float2 p1, float2 p2, float2 p3) {
    float minDist = INFINITY;

    // Sample the curve at 20 points
    for (int i = 0; i <= 20; i++) {
        float t = float(i) / 20.0;
        float mt = 1.0 - t;
        float mt2 = mt * mt;
        float mt3 = mt2 * mt;
        float t2 = t * t;
        float t3 = t2 * t;

        float2 curvePoint = mt3 * p0 + 3.0 * mt2 * t * p1 + 3.0 * mt * t2 * p2 + t3 * p3;
        float dist = length(p - curvePoint);
        minDist = min(minDist, dist);
    }

    return minDist;
}

// Distance from point to quadratic bezier curve
float distanceToQuadraticBezier(float2 p, float2 p0, float2 p1, float2 p2) {
    float minDist = INFINITY;

    for (int i = 0; i <= 20; i++) {
        float t = float(i) / 20.0;
        float mt = 1.0 - t;
        float mt2 = mt * mt;
        float t2 = t * t;

        float2 curvePoint = mt2 * p0 + 2.0 * mt * t * p1 + t2 * p2;
        float dist = length(p - curvePoint);
        minDist = min(minDist, dist);
    }

    return minDist;
}

// GPU-accelerated path hit test
// Tests if a point is within tolerance of a path's stroke
kernel void path_hit_test(
    const device PathSegment* segments [[buffer(0)]],
    constant uint& segmentCount [[buffer(1)]],
    constant float2& tapPoint [[buffer(2)]],
    constant float& tolerance [[buffer(3)]],
    device uint* hitResult [[buffer(4)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= segmentCount) return;

    PathSegment segment = segments[gid];
    float2 prevPoint = gid > 0 ? segments[gid - 1].point : segment.point;

    float minDist = INFINITY;

    switch (segment.type) {
        case PATH_MOVE:
            // Just a position marker, check distance to point
            minDist = length(tapPoint - segment.point);
            break;

        case PATH_LINE:
            // Distance to line segment
            minDist = distanceToLineSegment(tapPoint, prevPoint, segment.point);
            break;

        case PATH_CURVE:
            // Distance to cubic bezier
            minDist = distanceToCubicBezier(tapPoint, prevPoint, segment.control1, segment.control2, segment.point);
            break;

        case PATH_QUAD:
            // Distance to quadratic bezier
            minDist = distanceToQuadraticBezier(tapPoint, prevPoint, segment.control1, segment.point);
            break;

        case PATH_CLOSE:
            // Line back to first point (handled separately)
            break;
    }

    // If any segment is within tolerance, mark as hit
    if (minDist <= tolerance) {
        atomic_store_explicit((device atomic_uint*)hitResult, 1, memory_order_relaxed);
    }
}

// GPU-accelerated snap-to-point
// Finds the nearest snap point within threshold distance
// Each thread writes its distance, then CPU finds minimum
kernel void find_nearest_snap_point(
    const device float2* snapPoints [[buffer(0)]],
    constant uint& snapCount [[buffer(1)]],
    constant float2& mousePoint [[buffer(2)]],
    constant float& threshold [[buffer(3)]],
    device float* distances [[buffer(4)]],
    uint gid [[thread_position_in_grid]])
{
    if (gid >= snapCount) return;

    float2 snap = snapPoints[gid];
    float dist = length(mousePoint - snap);

    // Write distance for this snap point
    distances[gid] = dist;
}
