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

    // Per-layer spatial indices
    private var layerIndices: [UUID: LayerSpatialIndex] = [:]

    // Per-layer index structure
    fileprivate struct LayerSpatialIndex {
        var objectBoundsBuffer: MTLBuffer?
        var gridCellCountsBuffer: MTLBuffer?
        var gridCellObjectsBuffer: MTLBuffer?
        var paramsBuffer: MTLBuffer?
        var gridMinX: Int32 = 0
        var gridMinY: Int32 = 0
        var gridMaxX: Int32 = 0
        var gridMaxY: Int32 = 0
        var totalCells: Int = 0
        var objectIDs: [UUID] = []
        var objectIDToIndex: [UUID: UInt32] = [:]
    }

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

    /// Rebuild spatial index for specific layers only
    func rebuildLayers(_ layerIDs: Set<UUID>, from snapshot: DocumentSnapshot) {
        let includeStrokesInBounds = ApplicationSettings.shared.boundingBoxIncludesStrokes

        // Build set of child IDs that are inside groups (needed for all layers)
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

        var totalObjectsRebuilt = 0

        // Rebuild only the specified layers
        for layer in snapshot.layers {
            guard layerIDs.contains(layer.id) else { continue }

            // Collect bounds data for this layer only
            var boundsData: [(UUID, CGRect)] = []
            var minX: CGFloat = .infinity
            var minY: CGFloat = .infinity
            var maxX: CGFloat = -.infinity
            var maxY: CGFloat = -.infinity

            guard layer.isVisible else {
                // Layer is hidden, clear its index
                layerIndices[layer.id] = LayerSpatialIndex()
                continue
            }

            for objectID in layer.objectIDs {
                if groupedChildIDs.contains(objectID) { continue }
                guard let object = snapshot.objects[objectID], object.isVisible else { continue }

                if object.shape.isGroupContainer {
                    let groupBounds = object.shape.groupBounds
                    boundsData.append((objectID, groupBounds))
                    minX = min(minX, groupBounds.minX)
                    minY = min(minY, groupBounds.minY)
                    maxX = max(maxX, groupBounds.maxX)
                    maxY = max(maxY, groupBounds.maxY)

                    switch object.objectType {
                    case .group(let groupShape), .clipGroup(let groupShape):
                        for childShape in groupShape.groupedShapes {
                            guard childShape.isVisible else { continue }
                            var childBounds = childShape.bounds.applying(childShape.transform)
                            if includeStrokesInBounds, let strokeStyle = childShape.strokeStyle {
                                let strokeExpansion = strokeStyle.width / 2.0
                                childBounds = childBounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
                            }
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
                    var bounds: CGRect
                    switch object.objectType {
                    case .text(let shape):
                        bounds = CGRect(x: shape.transform.tx, y: shape.transform.ty,
                                       width: shape.bounds.width, height: shape.bounds.height)
                    case .shape(let shape), .image(let shape), .warp(let shape), .clipMask(let shape), .guide(let shape):
                        bounds = shape.bounds.applying(shape.transform)
                        if includeStrokesInBounds, let strokeStyle = shape.strokeStyle {
                            let strokeExpansion = strokeStyle.width / 2.0
                            bounds = bounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
                        }
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

            totalObjectsRebuilt += boundsData.count

            // Build per-layer index
            if boundsData.isEmpty {
                layerIndices[layer.id] = LayerSpatialIndex()
                continue
            }

            var layerIndex = LayerSpatialIndex()
            layerIndex.gridMinX = Int32(floor(minX / CGFloat(gridSize)))
            layerIndex.gridMinY = Int32(floor(minY / CGFloat(gridSize)))
            layerIndex.gridMaxX = Int32(floor(maxX / CGFloat(gridSize)))
            layerIndex.gridMaxY = Int32(floor(maxY / CGFloat(gridSize)))

            let gridWidth = Int(layerIndex.gridMaxX - layerIndex.gridMinX + 1)
            let gridHeight = Int(layerIndex.gridMaxY - layerIndex.gridMinY + 1)
            layerIndex.totalCells = gridWidth * gridHeight

            layerIndex.objectIDs = boundsData.map { $0.0 }
            for (index, id) in layerIndex.objectIDs.enumerated() {
                layerIndex.objectIDToIndex[id] = UInt32(index)
            }

            // Create GPU buffers for this layer
            let objectCount = boundsData.count
            var objectBoundsArray: [ObjectBounds] = boundsData.enumerated().map { index, data in
                ObjectBounds(
                    bounds: SIMD4<Float>(Float(data.1.minX), Float(data.1.minY),
                                        Float(data.1.maxX), Float(data.1.maxY)),
                    objectIndex: UInt32(index)
                )
            }

            layerIndex.objectBoundsBuffer = device.makeBuffer(
                bytes: &objectBoundsArray,
                length: MemoryLayout<ObjectBounds>.stride * objectCount,
                options: .storageModeShared
            )

            layerIndex.gridCellCountsBuffer = device.makeBuffer(
                length: MemoryLayout<UInt32>.stride * layerIndex.totalCells,
                options: .storageModeShared
            )

            let maxTotalSlots = layerIndex.totalCells * Int(maxObjectsPerCell)
            layerIndex.gridCellObjectsBuffer = device.makeBuffer(
                length: MemoryLayout<UInt32>.stride * maxTotalSlots,
                options: .storageModeShared
            )

            var params = SpatialGridParams(
                gridSize: gridSize,
                maxObjectsPerCell: maxObjectsPerCell,
                gridMinX: layerIndex.gridMinX,
                gridMinY: layerIndex.gridMinY,
                gridMaxX: layerIndex.gridMaxX,
                gridMaxY: layerIndex.gridMaxY,
                totalObjects: UInt32(objectCount)
            )

            layerIndex.paramsBuffer = device.makeBuffer(
                bytes: &params,
                length: MemoryLayout<SpatialGridParams>.stride,
                options: .storageModeShared
            )

            // Execute GPU build for this layer
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
                continue
            }

            // Clear grid counts
            computeEncoder.setComputePipelineState(clearGridPipeline)
            computeEncoder.setBuffer(layerIndex.gridCellCountsBuffer, offset: 0, index: 0)
            let clearThreads = MTLSize(width: layerIndex.totalCells, height: 1, depth: 1)
            let clearThreadsPerGroup = MTLSize(
                width: min(clearGridPipeline.threadExecutionWidth, layerIndex.totalCells),
                height: 1, depth: 1
            )
            computeEncoder.dispatchThreads(clearThreads, threadsPerThreadgroup: clearThreadsPerGroup)

            // Build spatial index
            computeEncoder.setComputePipelineState(pipelineState)
            computeEncoder.setBuffer(layerIndex.objectBoundsBuffer, offset: 0, index: 0)
            computeEncoder.setBuffer(layerIndex.gridCellCountsBuffer, offset: 0, index: 1)
            computeEncoder.setBuffer(layerIndex.gridCellObjectsBuffer, offset: 0, index: 2)
            computeEncoder.setBuffer(layerIndex.paramsBuffer, offset: 0, index: 3)

            let buildThreads = MTLSize(width: objectCount, height: 1, depth: 1)
            let buildThreadsPerGroup = MTLSize(
                width: min(pipelineState.threadExecutionWidth, objectCount),
                height: 1, depth: 1
            )
            computeEncoder.dispatchThreads(buildThreads, threadsPerThreadgroup: buildThreadsPerGroup)

            computeEncoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()

            layerIndices[layer.id] = layerIndex
        }

        print("🔷 Rebuilt \(layerIDs.count) layer(s), \(totalObjectsRebuilt) objects")
    }

    /// Get candidate objects at a specific point (GPU query)
    func candidateObjectIDs(at point: CGPoint) -> Set<UUID> {
        var result = Set<UUID>()

        // Query each layer's spatial index
        for (_, layerIndex) in layerIndices {
            guard let gridCellCountsBuffer = layerIndex.gridCellCountsBuffer,
                  let gridCellObjectsBuffer = layerIndex.gridCellObjectsBuffer,
                  let paramsBuffer = layerIndex.paramsBuffer,
                  layerIndex.totalCells > 0 else {
                continue
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
                continue
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
                continue
            }
            let count = Int(countPtr.pointee)

            guard count > 0, let candidatesPtr = candidatesBuffer?.contents().bindMemory(to: UInt32.self, capacity: maxCandidates) else {
                continue
            }

            for i in 0..<min(count, maxCandidates) {
                let objectIndex = Int(candidatesPtr[i])
                if objectIndex < layerIndex.objectIDs.count {
                    result.insert(layerIndex.objectIDs[objectIndex])
                }
            }
        }

        return result
    }

    /// Get candidate objects in a rectangle (GPU query)
    func candidateObjectIDs(in rect: CGRect) -> Set<UUID> {
        var result = Set<UUID>()

        // Query each layer's spatial index
        for (_, layerIndex) in layerIndices {
            guard let gridCellCountsBuffer = layerIndex.gridCellCountsBuffer,
                  let gridCellObjectsBuffer = layerIndex.gridCellObjectsBuffer,
                  let paramsBuffer = layerIndex.paramsBuffer,
                  layerIndex.totalCells > 0 else {
                continue
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
                continue
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
                continue
            }
            let count = Int(countPtr.pointee)

            guard count > 0, let candidatesPtr = candidatesBuffer?.contents().bindMemory(to: UInt32.self, capacity: maxCandidates) else {
                continue
            }

            for i in 0..<min(count, maxCandidates) {
                let objectIndex = Int(candidatesPtr[i])
                if objectIndex < layerIndex.objectIDs.count {
                    result.insert(layerIndex.objectIDs[objectIndex])
                }
            }
        }

        return result
    }
}

// MARK: - Metal Structures (match shader definitions)

// SIMD optimized: matches Metal shader ObjectBounds struct
private struct ObjectBounds {
    let bounds: SIMD4<Float>  // (minX, minY, maxX, maxY)
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
