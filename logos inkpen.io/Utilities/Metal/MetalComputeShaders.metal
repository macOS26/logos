#include <metal_stdlib>
using namespace metal;


struct Point2D {
    float x, y;
};

struct PolygonParams {
    float radius;
    uint sides;
    float startAngle;
};

kernel void calculate_distances(
    device const Point2D* points [[buffer(0)]],
    device const Point2D* lineStart [[buffer(1)]],
    device const Point2D* lineEnd [[buffer(2)]],
    device float* distances [[buffer(3)]],
    device uint* maxIndex [[buffer(4)]],
    constant uint& pointCount [[buffer(5)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= pointCount) return;
    
    Point2D point = points[index];
    Point2D start = lineStart[0];
    Point2D end = lineEnd[0];
    
    float lineLength = sqrt((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y));
    
    if (lineLength < 0.0001) {
        float dx = point.x - start.x;
        float dy = point.y - start.y;
        distances[index] = sqrt(dx * dx + dy * dy);
    } else {
        float area = abs((end.x - start.x) * (point.y - start.y) - (end.y - start.y) * (point.x - start.x));
        distances[index] = area / lineLength;
    }
    
    atomic_fetch_max_explicit((device atomic_uint*)maxIndex, index, memory_order_relaxed);
}

kernel void calculate_bezier_curves(
    device const Point2D* controlPoints [[buffer(0)]],
    device Point2D* curvePoints [[buffer(1)]],
    constant uint& curveCount [[buffer(2)]],
    constant uint& pointsPerCurve [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    uint curveIndex = index / pointsPerCurve;
    uint pointIndex = index % pointsPerCurve;
    
    if (curveIndex >= curveCount) return;
    
    uint baseIndex = curveIndex * 3;
    Point2D p0 = controlPoints[baseIndex];
    Point2D p1 = controlPoints[baseIndex + 1];
    Point2D p2 = controlPoints[baseIndex + 2];
    
    float t = float(pointIndex) / float(pointsPerCurve - 1);
    
    float oneMinusT = 1.0 - t;
    float oneMinusTSquared = oneMinusT * oneMinusT;
    float tSquared = t * t;
    
    Point2D result;
    result.x = oneMinusTSquared * p0.x + 2.0 * oneMinusT * t * p1.x + tSquared * p2.x;
    result.y = oneMinusTSquared * p0.y + 2.0 * oneMinusT * t * p1.y + tSquared * p2.y;
    
    curvePoints[index] = result;
}

kernel void transform_points(
    device const Point2D* inputPoints [[buffer(0)]],
    device Point2D* outputPoints [[buffer(1)]],
    constant float* transformMatrix [[buffer(2)]],
    constant uint& pointCount [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= pointCount) return;
    
    Point2D point = inputPoints[index];
    
    float a = transformMatrix[0], b = transformMatrix[1], tx = transformMatrix[2];
    float c = transformMatrix[3], d = transformMatrix[4], ty = transformMatrix[5];
    
    Point2D result;
    result.x = a * point.x + b * point.y + tx;
    result.y = c * point.x + d * point.y + ty;
    
    outputPoints[index] = result;
}

kernel void point_in_polygon(
    device const Point2D* points [[buffer(0)]],
    device const Point2D* polygonVertices [[buffer(1)]],
    device int* results [[buffer(2)]],
    constant uint& pointCount [[buffer(3)]],
    constant uint& vertexCount [[buffer(4)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= pointCount) return;
    
    Point2D point = points[index];
    bool inside = false;
    
    for (uint i = 0, j = vertexCount - 1; i < vertexCount; j = i++) {
        Point2D vi = polygonVertices[i];
        Point2D vj = polygonVertices[j];
        
        if (((vi.y > point.y) != (vj.y > point.y)) &&
            (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x)) {
            inside = !inside;
        }
    }
    
    results[index] = inside ? 1 : 0;
}

kernel void render_path_points(
    device const Point2D* pathPoints [[buffer(0)]],
    device Point2D* interpolatedPoints [[buffer(1)]],
    constant uint& pathPointCount [[buffer(2)]],
    constant uint& interpolationFactor [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    uint segmentIndex = index / interpolationFactor;
    uint interpolationIndex = index % interpolationFactor;
    
    if (segmentIndex >= pathPointCount - 1) return;
    
    Point2D start = pathPoints[segmentIndex];
    Point2D end = pathPoints[segmentIndex + 1];
    
    float t = float(interpolationIndex) / float(interpolationFactor - 1);
    Point2D result;
    result.x = start.x + t * (end.x - start.x);
    result.y = start.y + t * (end.y - start.y);
    
    interpolatedPoints[index] = result;
}

kernel void calculate_vector_distances(
    device const Point2D* points1 [[buffer(0)]],
    device const Point2D* points2 [[buffer(1)]],
    device float* distances [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    Point2D p1 = points1[index];
    Point2D p2 = points2[index];
    
    float dx = p1.x - p2.x;
    float dy = p1.y - p2.y;
    
    distances[index] = sqrt(dx * dx + dy * dy);
}

kernel void normalize_vectors(
    device const Point2D* inputVectors [[buffer(0)]],
    device Point2D* normalizedVectors [[buffer(1)]],
    uint index [[thread_position_in_grid]]
) {
    Point2D vector = inputVectors[index];
    
    float length = sqrt(vector.x * vector.x + vector.y * vector.y);
    
    if (length > 0.0001) {
        normalizedVectors[index].x = vector.x / length;
        normalizedVectors[index].y = vector.y / length;
    } else {
        normalizedVectors[index].x = 0.0;
        normalizedVectors[index].y = 0.0;
    }
}

kernel void lerp_vectors(
    device const Point2D* startPoints [[buffer(0)]],
    device const Point2D* endPoints [[buffer(1)]],
    device Point2D* interpolatedPoints [[buffer(2)]],
    constant float& t [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    Point2D start = startPoints[index];
    Point2D end = endPoints[index];
    
    interpolatedPoints[index].x = start.x + t * (end.x - start.x);
    interpolatedPoints[index].y = start.y + t * (end.y - start.y);
}

kernel void calculate_linked_handles(
    device const Point2D* anchorPoints [[buffer(0)]],
    device const Point2D* draggedHandles [[buffer(1)]],
    device const Point2D* originalOppositeHandles [[buffer(2)]],
    device Point2D* linkedHandles [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    Point2D anchor = anchorPoints[index];
    Point2D draggedHandle = draggedHandles[index];
    Point2D originalOppositeHandle = originalOppositeHandles[index];
    
    float draggedVectorX = draggedHandle.x - anchor.x;
    float draggedVectorY = draggedHandle.y - anchor.y;
    
    float originalVectorX = originalOppositeHandle.x - anchor.x;
    float originalVectorY = originalOppositeHandle.y - anchor.y;
    float originalLength = sqrt(originalVectorX * originalVectorX + originalVectorY * originalVectorY);
    
    float draggedLength = sqrt(draggedVectorX * draggedVectorX + draggedVectorY * draggedVectorY);
    
    if (draggedLength > 0.1) {
        float normalizedDraggedX = draggedVectorX / draggedLength;
        float normalizedDraggedY = draggedVectorY / draggedLength;
        
        linkedHandles[index].x = anchor.x - normalizedDraggedX * originalLength;
        linkedHandles[index].y = anchor.y - normalizedDraggedY * originalLength;
    } else {
        linkedHandles[index] = originalOppositeHandle;
    }
}

kernel void calculate_curvature(
    device const Point2D* points [[buffer(0)]],
    device float* curvatures [[buffer(1)]],
    constant uint& pointCount [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    if (index == 0 || index >= pointCount - 1) {
        curvatures[index] = 0.0;
        return;
    }
    
    Point2D prev = points[index - 1];
    Point2D current = points[index];
    Point2D next = points[index + 1];
    
    float dx1 = current.x - prev.x;
    float dy1 = current.y - prev.y;
    float dx2 = next.x - current.x;
    float dy2 = next.y - current.y;
    
    float crossProduct = dx1 * dy2 - dy1 * dx2;
    float length1 = sqrt(dx1 * dx1 + dy1 * dy1);
    float length2 = sqrt(dx2 * dx2 + dy2 * dy2);
    
    if (length1 > 0.0001 && length2 > 0.0001) {
        curvatures[index] = crossProduct / (length1 * length2);
    } else {
        curvatures[index] = 0.0;
    }
}

kernel void chaikin_smoothing(
    device const Point2D* inputPoints [[buffer(0)]],
    device Point2D* outputPoints [[buffer(1)]],
    constant uint& inputCount [[buffer(2)]],
    constant float& ratio [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= inputCount - 1) return;
    
    Point2D p1 = inputPoints[index];
    Point2D p2 = inputPoints[index + 1];
    
    Point2D q1, q2;
    q1.x = p1.x + ratio * (p2.x - p1.x);
    q1.y = p1.y + ratio * (p2.y - p1.y);
    
    q2.x = p1.x + (1.0 - ratio) * (p2.x - p1.x);
    q2.y = p1.y + (1.0 - ratio) * (p2.y - p1.y);
    
    uint outputBase = index * 2 + 1;
    if (outputBase < (inputCount - 1) * 2 + 1) {
        outputPoints[outputBase] = q1;
        if (outputBase + 1 < (inputCount - 1) * 2 + 1) {
            outputPoints[outputBase + 1] = q2;
        }
    }
    
    if (index == 0) {
        outputPoints[0] = inputPoints[0];
    }
    if (index == inputCount - 2) {
        outputPoints[(inputCount - 1) * 2] = inputPoints[inputCount - 1];
    }
}

kernel void calculate_point_distance(
    device const Point2D* point1 [[buffer(0)]],
    device const Point2D* point2 [[buffer(1)]],
    device float* distances [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    Point2D p1 = point1[index];
    Point2D p2 = point2[index];
    
    float dx = p1.x - p2.x;
    float dy = p1.y - p2.y;
    
    distances[index] = sqrt(dx * dx + dy * dy);
}

kernel void calculate_square_roots(
    device const float* inputValues [[buffer(0)]],
    device float* outputValues [[buffer(1)]],
    uint index [[thread_position_in_grid]]
) {
    float value = inputValues[index];
    outputValues[index] = sqrt(max(0.0, value));
}

kernel void calculate_trigonometric(
    device const float* angles [[buffer(0)]],
    device float* results [[buffer(1)]],
    constant uint& function [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    float angle = angles[index];
    
    switch (function) {
        case 0:
            results[index] = sin(angle);
            break;
        case 1:
            results[index] = cos(angle);
            break;
        case 2:
            results[index] = tan(angle);
            break;
        case 3:
            results[index] = atan2(angle, 1.0);
            break;
        default:
            results[index] = 0.0;
            break;
    }
}

kernel void calculate_polygon_points(
    device Point2D* outputPoints [[buffer(0)]],
    constant Point2D& center [[buffer(1)]],
    constant PolygonParams& params [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= params.sides) return;
    
    float angleStep = 2.0 * M_PI_F / float(params.sides);
    float angle = float(index) * angleStep + params.startAngle;
    
    Point2D point;
    point.x = center.x + cos(angle) * params.radius;
    point.y = center.y + sin(angle) * params.radius;
    
    outputPoints[index] = point;
}

kernel void boolean_geometry_union(
    device const Point2D* path1Points [[buffer(0)]],
    device const Point2D* path2Points [[buffer(1)]],
    device Point2D* resultPoints [[buffer(2)]],
    constant uint& path1Count [[buffer(3)]],
    constant uint& path2Count [[buffer(4)]],
    uint index [[thread_position_in_grid]]
) {
    if (index < path1Count) {
        resultPoints[index] = path1Points[index];
    } else if (index < path1Count + path2Count) {
        resultPoints[index - path1Count] = path2Points[index - path1Count];
    }
}

kernel void path_intersection_calculation(
    device const Point2D* path1Points [[buffer(0)]],
    device const Point2D* path2Points [[buffer(1)]],
    device Point2D* intersectionPoints [[buffer(2)]],
    device uint* intersectionCount [[buffer(3)]],
    constant uint& path1Count [[buffer(4)]],
    constant uint& path2Count [[buffer(5)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= path1Count * path2Count) return;
    
    uint path1Index = index / path2Count;
    uint path2Index = index % path2Count;
    
    Point2D p1 = path1Points[path1Index];
    Point2D p2 = path2Points[path2Index];
    
    float distance = sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y));
    
    if (distance < 0.001) {
        atomic_fetch_add_explicit((device atomic_uint*)intersectionCount, 1, memory_order_relaxed);
        uint currentCount = atomic_fetch_add_explicit((device atomic_uint*)intersectionCount, 0, memory_order_relaxed);
        if (currentCount < 1000) {
            intersectionPoints[currentCount] = p1;
        }
    }
}