#include <metal_stdlib>
using namespace metal;

// Match Swift's GridCell structure
struct GridCell {
    int x;
    int y;
};

// Represents an object's bounds for spatial indexing
// SIMD optimized: float4 for better memory alignment and vectorization
struct ObjectBounds {
    float4 bounds;         // (minX, minY, maxX, maxY)
    uint objectIndex;      // Index into objectIDs array
};

// Spatial grid parameters
struct SpatialGridParams {
    float gridSize;        // Cell size (e.g., 50.0)
    uint maxObjectsPerCell; // Max objects that can be stored per cell
    int gridMinX;          // Minimum grid coordinate
    int gridMinY;
    int gridMaxX;          // Maximum grid coordinate
    int gridMaxY;
    uint totalObjects;
};

// Build spatial index: assign objects to grid cells
kernel void build_spatial_index(
    device const ObjectBounds* objectBounds [[buffer(0)]],     // Input: object bounds
    device atomic_uint* gridCellCounts [[buffer(1)]],          // Output: count of objects per cell
    device uint* gridCellObjects [[buffer(2)]],                // Output: flat array of objectIDs per cell
    constant SpatialGridParams& params [[buffer(3)]],
    uint objectIdx [[thread_position_in_grid]]
) {
    if (objectIdx >= params.totalObjects) return;

    ObjectBounds obj = objectBounds[objectIdx];

    // SIMD optimized: Calculate grid cells this object overlaps using vectorized operations
    // obj.bounds.xy = (minX, minY), obj.bounds.zw = (maxX, maxY)
    float2 minCell = floor(obj.bounds.xy / params.gridSize);
    float2 maxCell = floor(obj.bounds.zw / params.gridSize);
    int2 minCellXY = int2(minCell);
    int2 maxCellXY = int2(maxCell);

    // SIMD clamp to grid bounds
    int2 gridMin = int2(params.gridMinX, params.gridMinY);
    int2 gridMax = int2(params.gridMaxX, params.gridMaxY);
    minCellXY = max(minCellXY, gridMin);
    maxCellXY = min(maxCellXY, gridMax);

    int minCellX = minCellXY.x;
    int maxCellX = maxCellXY.x;
    int minCellY = minCellXY.y;
    int maxCellY = maxCellXY.y;

    int gridWidth = params.gridMaxX - params.gridMinX + 1;

    // Add this object to all overlapping cells
    for (int cellX = minCellX; cellX <= maxCellX; cellX++) {
        for (int cellY = minCellY; cellY <= maxCellY; cellY++) {
            // Calculate linear cell index
            int relX = cellX - params.gridMinX;
            int relY = cellY - params.gridMinY;
            uint cellIndex = relY * gridWidth + relX;

            // Atomically increment the count for this cell
            uint slotIndex = atomic_fetch_add_explicit(
                &gridCellCounts[cellIndex],
                1,
                memory_order_relaxed
            );

            // Store object index if there's room
            if (slotIndex < params.maxObjectsPerCell) {
                uint flatIndex = cellIndex * params.maxObjectsPerCell + slotIndex;
                gridCellObjects[flatIndex] = obj.objectIndex;
            }
        }
    }
}

// Query spatial index: find candidate objects at a point
kernel void query_point(
    device const atomic_uint* gridCellCounts [[buffer(0)]],    // Input: counts per cell
    device const uint* gridCellObjects [[buffer(1)]],          // Input: object IDs per cell
    device uint* candidateObjects [[buffer(2)]],               // Output: candidate object indices
    device atomic_uint* candidateCount [[buffer(3)]],          // Output: total candidates found
    constant float2& queryPoint [[buffer(4)]],                 // Input: query point
    constant SpatialGridParams& params [[buffer(5)]],
    uint threadIdx [[thread_position_in_grid]]
) {
    if (threadIdx > 0) return;  // Single thread for point query

    // SIMD optimized: Calculate which cell contains the query point
    float2 cellFloat = floor(queryPoint / params.gridSize);
    int2 cell = int2(cellFloat);

    // Check if cell is within grid bounds
    int2 gridMin = int2(params.gridMinX, params.gridMinY);
    int2 gridMax = int2(params.gridMaxX, params.gridMaxY);
    if (any(cell < gridMin) || any(cell > gridMax)) {
        return;
    }

    // Calculate linear cell index
    int gridWidth = params.gridMaxX - params.gridMinX + 1;
    int2 relCell = cell - gridMin;
    uint cellIndex = relCell.y * gridWidth + relCell.x;

    // Read how many objects are in this cell
    uint objectCount = atomic_load_explicit(
        &gridCellCounts[cellIndex],
        memory_order_relaxed
    );
    objectCount = min(objectCount, params.maxObjectsPerCell);

    // Copy all objects from this cell to output
    uint baseIndex = cellIndex * params.maxObjectsPerCell;
    for (uint i = 0; i < objectCount; i++) {
        uint objectIdx = gridCellObjects[baseIndex + i];

        uint outputIndex = atomic_fetch_add_explicit(
            candidateCount,
            1,
            memory_order_relaxed
        );

        candidateObjects[outputIndex] = objectIdx;
    }
}

// Query spatial index: find candidate objects in a rectangle
kernel void query_rect(
    device const atomic_uint* gridCellCounts [[buffer(0)]],    // Input: counts per cell
    device const uint* gridCellObjects [[buffer(1)]],          // Input: object IDs per cell
    device uint* candidateObjects [[buffer(2)]],               // Output: candidate object indices
    device atomic_uint* candidateCount [[buffer(3)]],          // Output: total candidates found
    constant float4& queryRect [[buffer(4)]],                  // Input: (minX, minY, maxX, maxY)
    constant SpatialGridParams& params [[buffer(5)]],
    uint2 cellCoord [[thread_position_in_grid]]
) {
    // SIMD optimized: Calculate grid cells the query rect overlaps
    // queryRect: (minX, minY, maxX, maxY)
    float2 minCell = floor(queryRect.xy / params.gridSize);
    float2 maxCell = floor(queryRect.zw / params.gridSize);
    int2 minCellXY = int2(minCell);
    int2 maxCellXY = int2(maxCell);

    // SIMD clamp to grid bounds
    int2 gridMin = int2(params.gridMinX, params.gridMinY);
    int2 gridMax = int2(params.gridMaxX, params.gridMaxY);
    minCellXY = max(minCellXY, gridMin);
    maxCellXY = min(maxCellXY, gridMax);

    int minCellX = minCellXY.x;
    int maxCellX = maxCellXY.x;
    int minCellY = minCellXY.y;
    int maxCellY = maxCellXY.y;

    // Each thread handles one cell in the query region
    int cellX = minCellX + int(cellCoord.x);
    int cellY = minCellY + int(cellCoord.y);

    if (cellX > maxCellX || cellY > maxCellY) return;

    // Calculate linear cell index
    int gridWidth = params.gridMaxX - params.gridMinX + 1;
    int relX = cellX - params.gridMinX;
    int relY = cellY - params.gridMinY;
    uint cellIndex = relY * gridWidth + relX;

    // Read how many objects are in this cell
    uint objectCount = atomic_load_explicit(
        &gridCellCounts[cellIndex],
        memory_order_relaxed
    );
    objectCount = min(objectCount, params.maxObjectsPerCell);

    // Copy objects from this cell (using atomic to avoid duplicates across threads)
    uint baseIndex = cellIndex * params.maxObjectsPerCell;
    for (uint i = 0; i < objectCount; i++) {
        uint objectIdx = gridCellObjects[baseIndex + i];

        uint outputIndex = atomic_fetch_add_explicit(
            candidateCount,
            1,
            memory_order_relaxed
        );

        // Store in output buffer
        candidateObjects[outputIndex] = objectIdx;
    }
}

// Clear grid cell counts (parallel reset)
kernel void clear_grid(
    device atomic_uint* gridCellCounts [[buffer(0)]],
    uint index [[thread_position_in_grid]]
) {
    atomic_store_explicit(&gridCellCounts[index], 0, memory_order_relaxed);
}
