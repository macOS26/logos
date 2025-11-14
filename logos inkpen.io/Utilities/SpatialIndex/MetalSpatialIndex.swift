import Metal
import MetalKit
import SwiftUI

/// GPU-accelerated spatial index using Metal compute shaders
class MetalSpatialIndex {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    private let queryPointPipeline: MTLComputePipelineState
    private let queryRectPipeline: MTLComputePipelineState
    private let clearGridPipeline: MTLComputePipelineState

    // Grid parameters
    private let gridSize: Float = 50.0  // 50x50 pixel cells
    private let maxObjectsPerCell: UInt32 = 256  // Max objects per cell

    // GPU buffers
    private var objectBoundsBuffer: MTLBuffer?
    private var gridCellCountsBuffer: MTLBuffer?
    private var gridCellObjectsBuffer: MTLBuffer?
    private var paramsBuffer: MTLBuffer?

    // Grid dimensions (computed from document bounds)
    private var gridMinX: Int32 = 0
    private var gridMinY: Int32 = 0
    private var gridMaxX: Int32 = 0
    private var gridMaxY: Int32 = 0
    private var totalCells: Int = 0

    // Object ID mapping
    private var objectIDs: [UUID] = []
    private var objectIDToIndex: [UUID: UInt32] = [:]

    // Track pending rebuild command buffer
    private var pendingRebuildBuffer: MTLCommandBuffer?

    init?() {
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal device not available")
            return nil
        }

        guard let cmdQueue = metalDevice.makeCommandQueue() else {
            print("❌ Failed to create command queue")
            return nil
        }

        self.device = metalDevice
        self.commandQueue = cmdQueue

        // Load shader library
        guard let library = metalDevice.makeDefaultLibrary() else {
            print("❌ Failed to load Metal library")
            return nil
        }

        // Create compute pipelines
        guard let buildFunction = library.makeFunction(name: "build_spatial_index"),
              let buildPipeline = try? metalDevice.makeComputePipelineState(function: buildFunction) else {
            print("❌ Failed to create build_spatial_index pipeline")
            return nil
        }

        guard let queryPointFunction = library.makeFunction(name: "query_point"),
              let queryPointPipeline = try? metalDevice.makeComputePipelineState(function: queryPointFunction) else {
            print("❌ Failed to create query_point pipeline")
            return nil
        }

        guard let queryRectFunction = library.makeFunction(name: "query_rect"),
              let queryRectPipeline = try? metalDevice.makeComputePipelineState(function: queryRectFunction) else {
            print("❌ Failed to create query_rect pipeline")
            return nil
        }

        guard let clearGridFunction = library.makeFunction(name: "clear_grid"),
              let clearGridPipeline = try? metalDevice.makeComputePipelineState(function: clearGridFunction) else {
            print("❌ Failed to create clear_grid pipeline")
            return nil
        }

        self.pipelineState = buildPipeline
        self.queryPointPipeline = queryPointPipeline
        self.queryRectPipeline = queryRectPipeline
        self.clearGridPipeline = clearGridPipeline
    }

    /// Rebuild the entire spatial index from document snapshot
    func rebuild(from snapshot: DocumentSnapshot) {
        // Collect all visible objects and their bounds
        var boundsData: [(UUID, CGRect)] = []
        var minX: CGFloat = .infinity
        var minY: CGFloat = .infinity
        var maxX: CGFloat = -.infinity
        var maxY: CGFloat = -.infinity

        // Build set of child IDs that are inside groups
        var groupedChildIDs = Set<UUID>()
        for object in snapshot.objects.values {
            switch object.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                for childShape in groupShape.groupedShapes {
                    groupedChildIDs.insert(childShape.id)
                }
            default:
                break
            }
        }

        for layer in snapshot.layers {
            guard layer.isVisible else { continue }

            for objectID in layer.objectIDs {
                // Skip child IDs - they're stale in snapshot.objects
                if groupedChildIDs.contains(objectID) { continue }

                guard let object = snapshot.objects[objectID], object.isVisible else { continue }

                // For groups, index BOTH the group AND its children
                if object.shape.isGroupContainer {
                    let groupBounds = object.shape.groupBounds
                    boundsData.append((objectID, groupBounds))
                    minX = min(minX, groupBounds.minX)
                    minY = min(minY, groupBounds.minY)
                    maxX = max(maxX, groupBounds.maxX)
                    maxY = max(maxY, groupBounds.maxY)

                    // Also index each child from groupedShapes
                    switch object.objectType {
                    case .group(let groupShape), .clipGroup(let groupShape):
                        for childShape in groupShape.groupedShapes {
                            guard childShape.isVisible else { continue }
                            let childBounds = childShape.bounds.applying(childShape.transform)
                            boundsData.append((childShape.id, childBounds))
                            minX = min(minX, childBounds.minX)
                            minY = min(minY, childBounds.minY)
                            maxX = max(maxX, childBounds.maxX)
                            maxY = max(maxY, childBounds.maxY)
                        }
                    default:
                        break
                    }
                } else {
                    // Regular objects
                    let bounds: CGRect
                    switch object.objectType {
                    case .text(let shape):
                        bounds = CGRect(
                            x: shape.transform.tx,
                            y: shape.transform.ty,
                            width: shape.bounds.width,
                            height: shape.bounds.height
                        )
                    case .shape(let shape), .image(let shape), .warp(let shape), .clipMask(let shape):
                        bounds = shape.bounds.applying(shape.transform)
                    case .group, .clipGroup:
                        continue
                    }

                    boundsData.append((objectID, bounds))
                    minX = min(minX, bounds.minX)
                    minY = min(minY, bounds.minY)
                    maxX = max(maxX, bounds.maxX)
                    maxY = max(maxY, bounds.maxY)
                }
            }
        }

        guard !boundsData.isEmpty else {
            objectIDs = []
            objectIDToIndex = [:]
            return
        }

        // Calculate grid dimensions
        gridMinX = Int32(floor(minX / CGFloat(gridSize)))
        gridMinY = Int32(floor(minY / CGFloat(gridSize)))
        gridMaxX = Int32(floor(maxX / CGFloat(gridSize)))
        gridMaxY = Int32(floor(maxY / CGFloat(gridSize)))

        let gridWidth = Int(gridMaxX - gridMinX + 1)
        let gridHeight = Int(gridMaxY - gridMinY + 1)
        totalCells = gridWidth * gridHeight

        // Build object ID mapping
        objectIDs = boundsData.map { $0.0 }
        objectIDToIndex = Dictionary(uniqueKeysWithValues: objectIDs.enumerated().map { ($1, UInt32($0)) })

        // Create GPU buffers
        let objectCount = boundsData.count

        // ObjectBounds buffer
        var objectBoundsArray: [ObjectBounds] = boundsData.enumerated().map { index, data in
            ObjectBounds(
                minX: Float(data.1.minX),
                minY: Float(data.1.minY),
                maxX: Float(data.1.maxX),
                maxY: Float(data.1.maxY),
                objectIndex: UInt32(index)
            )
        }

        objectBoundsBuffer = device.makeBuffer(
            bytes: &objectBoundsArray,
            length: MemoryLayout<ObjectBounds>.stride * objectCount,
            options: .storageModeShared
        )

        // Grid cell counts (atomic)
        gridCellCountsBuffer = device.makeBuffer(
            length: MemoryLayout<UInt32>.stride * totalCells,
            options: .storageModeShared
        )

        // Grid cell objects (flat array)
        let maxTotalSlots = totalCells * Int(maxObjectsPerCell)
        gridCellObjectsBuffer = device.makeBuffer(
            length: MemoryLayout<UInt32>.stride * maxTotalSlots,
            options: .storageModeShared
        )

        // Parameters
        var params = SpatialGridParams(
            gridSize: gridSize,
            maxObjectsPerCell: maxObjectsPerCell,
            gridMinX: gridMinX,
            gridMinY: gridMinY,
            gridMaxX: gridMaxX,
            gridMaxY: gridMaxY,
            totalObjects: UInt32(objectCount)
        )

        paramsBuffer = device.makeBuffer(
            bytes: &params,
            length: MemoryLayout<SpatialGridParams>.stride,
            options: .storageModeShared
        )

        // Execute GPU build
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            print("❌ Failed to create command buffer/encoder")
            return
        }

        // Step 1: Clear grid counts
        computeEncoder.setComputePipelineState(clearGridPipeline)
        computeEncoder.setBuffer(gridCellCountsBuffer, offset: 0, index: 0)

        let clearThreads = MTLSize(width: totalCells, height: 1, depth: 1)
        let clearThreadsPerGroup = MTLSize(
            width: min(clearGridPipeline.threadExecutionWidth, totalCells),
            height: 1,
            depth: 1
        )
        computeEncoder.dispatchThreads(clearThreads, threadsPerThreadgroup: clearThreadsPerGroup)

        // Step 2: Build spatial index
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setBuffer(objectBoundsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(gridCellCountsBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(gridCellObjectsBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 3)

        let buildThreads = MTLSize(width: objectCount, height: 1, depth: 1)
        let buildThreadsPerGroup = MTLSize(
            width: min(pipelineState.threadExecutionWidth, objectCount),
            height: 1,
            depth: 1
        )
        computeEncoder.dispatchThreads(buildThreads, threadsPerThreadgroup: buildThreadsPerGroup)

        computeEncoder.endEncoding()
        commandBuffer.commit()

        // Store reference to pending buffer for queries to wait on
        pendingRebuildBuffer = commandBuffer

        // Don't waitUntilCompleted() here - allows main thread to continue
        // Queries will wait for this buffer before reading results
    }

    /// Get candidate objects at a specific point (GPU query)
    func candidateObjectIDs(at point: CGPoint) -> Set<UUID> {
        // Wait for any pending rebuild to complete before querying
        if let pendingBuffer = pendingRebuildBuffer {
            pendingBuffer.waitUntilCompleted()
            pendingRebuildBuffer = nil
        }

        guard let gridCellCountsBuffer = gridCellCountsBuffer,
              let gridCellObjectsBuffer = gridCellObjectsBuffer,
              let paramsBuffer = paramsBuffer else {
            return []
        }

        // Output buffers
        let maxCandidates = Int(maxObjectsPerCell)
        let candidatesBuffer = device.makeBuffer(
            length: MemoryLayout<UInt32>.stride * maxCandidates,
            options: .storageModeShared
        )

        var candidateCount: UInt32 = 0
        let candidateCountBuffer = device.makeBuffer(
            bytes: &candidateCount,
            length: MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )

        var queryPoint = simd_float2(Float(point.x), Float(point.y))
        let queryPointBuffer = device.makeBuffer(
            bytes: &queryPoint,
            length: MemoryLayout<simd_float2>.stride,
            options: .storageModeShared
        )

        // Execute GPU query
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return []
        }

        computeEncoder.setComputePipelineState(queryPointPipeline)
        computeEncoder.setBuffer(gridCellCountsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(gridCellObjectsBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(candidatesBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(candidateCountBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(queryPointBuffer, offset: 0, index: 4)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 5)

        let threads = MTLSize(width: 1, height: 1, depth: 1)
        let threadsPerGroup = MTLSize(width: 1, height: 1, depth: 1)
        computeEncoder.dispatchThreads(threads, threadsPerThreadgroup: threadsPerGroup)

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results
        guard let countPtr = candidateCountBuffer?.contents().bindMemory(to: UInt32.self, capacity: 1) else {
            return []
        }
        let count = Int(countPtr.pointee)

        guard count > 0, let candidatesPtr = candidatesBuffer?.contents().bindMemory(to: UInt32.self, capacity: maxCandidates) else {
            return []
        }

        var result = Set<UUID>()
        for i in 0..<min(count, maxCandidates) {
            let objectIndex = Int(candidatesPtr[i])
            if objectIndex < objectIDs.count {
                result.insert(objectIDs[objectIndex])
            }
        }

        return result
    }

    /// Get candidate objects in a rectangle (GPU query)
    func candidateObjectIDs(in rect: CGRect) -> Set<UUID> {
        // Wait for any pending rebuild to complete before querying
        if let pendingBuffer = pendingRebuildBuffer {
            pendingBuffer.waitUntilCompleted()
            pendingRebuildBuffer = nil
        }

        guard let gridCellCountsBuffer = gridCellCountsBuffer,
              let gridCellObjectsBuffer = gridCellObjectsBuffer,
              let paramsBuffer = paramsBuffer else {
            return []
        }

        // Calculate query region dimensions
        let minCellX = Int32(floor(rect.minX / CGFloat(gridSize)))
        let maxCellX = Int32(floor(rect.maxX / CGFloat(gridSize)))
        let minCellY = Int32(floor(rect.minY / CGFloat(gridSize)))
        let maxCellY = Int32(floor(rect.maxY / CGFloat(gridSize)))

        let cellWidth = max(1, maxCellX - minCellX + 1)
        let cellHeight = max(1, maxCellY - minCellY + 1)

        // Output buffers
        let maxCandidates = Int(maxObjectsPerCell) * Int(cellWidth) * Int(cellHeight)
        let candidatesBuffer = device.makeBuffer(
            length: MemoryLayout<UInt32>.stride * maxCandidates,
            options: .storageModeShared
        )

        var candidateCount: UInt32 = 0
        let candidateCountBuffer = device.makeBuffer(
            bytes: &candidateCount,
            length: MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )

        var queryRect = simd_float4(Float(rect.minX), Float(rect.minY), Float(rect.maxX), Float(rect.maxY))
        let queryRectBuffer = device.makeBuffer(
            bytes: &queryRect,
            length: MemoryLayout<simd_float4>.stride,
            options: .storageModeShared
        )

        // Execute GPU query
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return []
        }

        computeEncoder.setComputePipelineState(queryRectPipeline)
        computeEncoder.setBuffer(gridCellCountsBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(gridCellObjectsBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(candidatesBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(candidateCountBuffer, offset: 0, index: 3)
        computeEncoder.setBuffer(queryRectBuffer, offset: 0, index: 4)
        computeEncoder.setBuffer(paramsBuffer, offset: 0, index: 5)

        let threads = MTLSize(width: Int(cellWidth), height: Int(cellHeight), depth: 1)
        let threadsPerGroup = MTLSize(
            width: min(queryRectPipeline.threadExecutionWidth, Int(cellWidth)),
            height: min(queryRectPipeline.maxTotalThreadsPerThreadgroup / queryRectPipeline.threadExecutionWidth, Int(cellHeight)),
            depth: 1
        )
        computeEncoder.dispatchThreads(threads, threadsPerThreadgroup: threadsPerGroup)

        computeEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results
        guard let countPtr = candidateCountBuffer?.contents().bindMemory(to: UInt32.self, capacity: 1) else {
            return []
        }
        let count = Int(countPtr.pointee)

        guard count > 0, let candidatesPtr = candidatesBuffer?.contents().bindMemory(to: UInt32.self, capacity: maxCandidates) else {
            return []
        }

        var result = Set<UUID>()
        for i in 0..<min(count, maxCandidates) {
            let objectIndex = Int(candidatesPtr[i])
            if objectIndex < objectIDs.count {
                result.insert(objectIDs[objectIndex])
            }
        }

        return result
    }
}

// MARK: - Metal Structures (match shader definitions)

private struct ObjectBounds {
    let minX: Float
    let minY: Float
    let maxX: Float
    let maxY: Float
    let objectIndex: UInt32
}

private struct SpatialGridParams {
    let gridSize: Float
    let maxObjectsPerCell: UInt32
    let gridMinX: Int32
    let gridMinY: Int32
    let gridMaxX: Int32
    let gridMaxY: Int32
    let totalObjects: UInt32
}
