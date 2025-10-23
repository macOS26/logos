import Foundation
import CoreGraphics

/// Cache for pre-filtered render objects to avoid recalculation in view body
final class RenderCache {
    static let shared = RenderCache()

    private var cache: [String: [(shape: VectorShape, isSelected: Bool)]] = [:]
    private let lock = NSLock()

    private init() {}

    func getFilteredObjects(
        key: String,
        objects: [VectorObject],
        viewport: CGRect,
        selectedObjectIDs: Set<UUID>
    ) -> [(shape: VectorShape, isSelected: Bool)] {
        lock.lock()
        defer { lock.unlock() }

        // Return cached if available
        if let cached = cache[key] {
            return cached
        }

        // Compute and cache
        let filtered = filterVisibleObjects(
            objects: objects,
            viewport: viewport,
            selectedObjectIDs: selectedObjectIDs
        )
        cache[key] = filtered
        return filtered
    }

    func invalidate(key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    // MARK: - Filtering Logic

    private func filterVisibleObjects(
        objects: [VectorObject],
        viewport: CGRect,
        selectedObjectIDs: Set<UUID>
    ) -> [(shape: VectorShape, isSelected: Bool)] {
        var result: [(shape: VectorShape, isSelected: Bool)] = []
        result.reserveCapacity(objects.count)

        for object in objects {
            guard object.isVisible else { continue }

            switch object.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                guard shape.typography == nil else { continue }
                guard isObjectInViewportSIMD(shape.bounds, viewport: viewport) else { continue }
                result.append((shape, selectedObjectIDs.contains(object.id)))

            case .text(let shape):
                guard shape.isEditing != true else { continue }
                guard isObjectInViewportSIMD(shape.bounds, viewport: viewport) else { continue }
                result.append((shape, selectedObjectIDs.contains(object.id)))
            }
        }

        return result
    }

    private func isObjectInViewportSIMD(_ bounds: CGRect, viewport: CGRect) -> Bool {
        let objMin = SIMD2<Double>(bounds.minX, bounds.minY)
        let objMax = SIMD2<Double>(bounds.maxX, bounds.maxY)
        let vpMin = SIMD2<Double>(viewport.minX, viewport.minY)
        let vpMax = SIMD2<Double>(viewport.maxX, viewport.maxY)

        let overlapMin = objMax .>= vpMin
        let overlapMax = objMin .<= vpMax

        return all(overlapMin) && all(overlapMax)
    }
}

/// Helper to calculate viewport bounds
struct ViewportCalculator {
    static func calculateViewportBounds(
        size: CGSize,
        canvasOffset: CGPoint,
        zoomLevel: Double
    ) -> CGRect {
        let padding: CGFloat = 200.0
        let minX = (-canvasOffset.x - padding) / zoomLevel
        let minY = (-canvasOffset.y - padding) / zoomLevel
        let maxX = (size.width - canvasOffset.x + padding) / zoomLevel
        let maxY = (size.height - canvasOffset.y + padding) / zoomLevel

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
