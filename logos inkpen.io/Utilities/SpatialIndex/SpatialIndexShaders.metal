#include <metal_stdlib>
using namespace metal;

// Match Swift's GridCell structure
struct GridCell {
    int x;
    int y;
};

// Represents an object's bounds for spatial indexing
struct ObjectBounds {
    float minX;
    float minY;
    float maxX;
    float maxY;
    uint objectIndex;  // Index into objectIDs array
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

    ObjectBounds bounds = objectBounds[objectIdx];

    // Calculate grid cells this object overlaps
    int minCellX = int(floor(bounds.minX / params.gridSize));
    int maxCellX = int(floor(bounds.maxX / params.gridSize));
    int minCellY = int(floor(bounds.minY / params.gridSize));
    int maxCellY = int(floor(bounds.maxY / params.gridSize));

    // Clamp to grid bounds
    minCellX = max(minCellX, params.gridMinX);
    maxCellX = min(maxCellX, params.gridMaxX);
    minCellY = max(minCellY, params.gridMinY);
    maxCellY = min(maxCellY, params.gridMaxY);

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
                gridCellObjects[flatIndex] = bounds.objectIndex;
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

    // Calculate which cell contains the query point
    int cellX = int(floor(queryPoint.x / params.gridSize));
    int cellY = int(floor(queryPoint.y / params.gridSize));

    // Check if cell is within grid bounds
    if (cellX < params.gridMinX || cellX > params.gridMaxX ||
        cellY < params.gridMinY || cellY > params.gridMaxY) {
        return;
    }

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
    // Calculate grid cells the query rect overlaps
    int minCellX = int(floor(queryRect.x / params.gridSize));
    int maxCellX = int(floor(queryRect.z / params.gridSize));
    int minCellY = int(floor(queryRect.y / params.gridSize));
    int maxCellY = int(floor(queryRect.w / params.gridSize));

    // Clamp to grid bounds
    minCellX = max(minCellX, params.gridMinX);
    maxCellX = min(maxCellX, params.gridMaxX);
    minCellY = max(minCellY, params.gridMinY);
    maxCellY = min(maxCellY, params.gridMaxY);

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
