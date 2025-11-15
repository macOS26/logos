#include <metal_stdlib>
using namespace metal;

// Structure matching Swift PathSegment
struct PathSegment {
    float2 start;
    float2 end;
    int type;  // 0 = line, 1 = curve
    float2 control1;
    float2 control2;
    float2 padding;
};

// Structure matching Swift Intersection
struct Intersection {
    float2 point;
    int segment1Index;
    int segment2Index;
    float t1;
    float t2;
    int valid;
};

// Test if two line segments intersect
bool lineLineIntersection(
    float2 p1, float2 p2,  // First line segment
    float2 p3, float2 p4,  // Second line segment
    thread float2 *intersection,
    thread float *t1,
    thread float *t2
) {
    float2 d1 = p2 - p1;
    float2 d2 = p4 - p3;
    float2 d3 = p3 - p1;

    float cross = d1.x * d2.y - d1.y * d2.x;

    // Parallel lines
    if (abs(cross) < 0.00001) {
        return false;
    }

    *t1 = (d3.x * d2.y - d3.y * d2.x) / cross;
    *t2 = (d3.x * d1.y - d3.y * d1.x) / cross;

    // Check if intersection is within both segments
    if (*t1 >= 0.0 && *t1 <= 1.0 && *t2 >= 0.0 && *t2 <= 1.0) {
        *intersection = p1 + *t1 * d1;
        return true;
    }

    return false;
}

// Main kernel: Find all intersections between two sets of segments
// This runs in O(1) on GPU instead of O(n²) on CPU!
kernel void find_segment_intersections(
    device const PathSegment *segmentsA [[buffer(0)]],
    device const PathSegment *segmentsB [[buffer(1)]],
    device Intersection *results [[buffer(2)]],
    constant int &countA [[buffer(3)]],
    constant int &countB [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Each thread tests one pair of segments
    int indexA = gid.x;
    int indexB = gid.y;

    // Bounds check
    if (indexA >= countA || indexB >= countB) {
        return;
    }

    // Calculate result index
    int resultIndex = indexA * countB + indexB;

    // Get the two segments to test
    PathSegment segA = segmentsA[indexA];
    PathSegment segB = segmentsB[indexB];

    // Initialize result
    results[resultIndex].valid = 0;
    results[resultIndex].segment1Index = indexA;
    results[resultIndex].segment2Index = indexB;

    // For now, handle line-line intersections
    // (Curve intersections would use iterative methods)
    if (segA.type == 0 && segB.type == 0) {
        float2 intersection;
        float t1, t2;

        if (lineLineIntersection(
            segA.start, segA.end,
            segB.start, segB.end,
            &intersection, &t1, &t2
        )) {
            results[resultIndex].point = intersection;
            results[resultIndex].t1 = t1;
            results[resultIndex].t2 = t2;
            results[resultIndex].valid = 1;
        }
    }
    // TODO: Handle curve-line and curve-curve intersections
}

// Compute union of paths based on intersections
kernel void compute_union(
    device const PathSegment *segmentsA [[buffer(0)]],
    device const PathSegment *segmentsB [[buffer(1)]],
    device const Intersection *intersections [[buffer(2)]],
    device int *insideFlags [[buffer(3)]],  // Which segments are inside/outside
    constant int &countA [[buffer(4)]],
    constant int &countB [[buffer(5)]],
    uint id [[thread_position_in_grid]]
) {
    // Each thread processes one segment to determine if it's inside or outside
    // the other path for union construction

    if (id >= uint(countA + countB)) {
        return;
    }

    // Simplified inside/outside test
    // Full implementation would use winding number or ray casting
    insideFlags[id] = 1;  // Default to outside

    // TODO: Implement proper inside/outside testing
}

// Helper kernel: Calculate winding number for point in polygon
kernel void calculate_winding_number(
    device const PathSegment *segments [[buffer(0)]],
    device const float2 *testPoints [[buffer(1)]],
    device int *windingNumbers [[buffer(2)]],
    constant int &segmentCount [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    // Each thread tests one point against all segments
    float2 point = testPoints[id];
    int winding = 0;

    for (int i = 0; i < segmentCount; i++) {
        PathSegment seg = segments[i];

        // Ray casting algorithm
        if (seg.start.y <= point.y) {
            if (seg.end.y > point.y) {
                // Upward crossing
                float2 edge = seg.end - seg.start;
                float2 toPoint = point - seg.start;
                float cross = edge.x * toPoint.y - edge.y * toPoint.x;
                if (cross > 0) {
                    winding++;
                }
            }
        } else {
            if (seg.end.y <= point.y) {
                // Downward crossing
                float2 edge = seg.end - seg.start;
                float2 toPoint = point - seg.start;
                float cross = edge.x * toPoint.y - edge.y * toPoint.x;
                if (cross < 0) {
                    winding--;
                }
            }
        }
    }

    windingNumbers[id] = winding;
}