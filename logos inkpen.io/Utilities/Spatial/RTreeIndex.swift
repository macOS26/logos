import Foundation
import CoreGraphics

/// R-Tree spatial index for O(log n) viewport queries
/// Provides fast lookup of objects intersecting a given rectangle
final class RTreeIndex {

    // MARK: - Node Structure

    private class Node {
        var bounds: CGRect
        var children: [Node] = []
        var objectIDs: [UUID] = []  // Only leaf nodes have objects
        var isLeaf: Bool { !objectIDs.isEmpty || children.isEmpty }

        init(bounds: CGRect = .zero) {
            self.bounds = bounds
        }
    }

    // MARK: - Properties

    private var root: Node
    private let maxEntries: Int = 9  // Max children per node (M)
    private let minEntries: Int = 4  // Min children per node (m = M/2 rounded down)

    // O(1) lookup for object bounds
    private var objectBounds: [UUID: CGRect] = [:]

    // MARK: - Initialization

    init() {
        self.root = Node()
    }

    // MARK: - Public API

    /// Query objects intersecting the viewport rectangle - O(log n)
    func query(viewport: CGRect) -> [UUID] {
        var results: [UUID] = []
        queryNode(root, viewport: viewport, results: &results)
        return results
    }

    /// Insert an object with its bounding box - O(log n)
    func insert(objectID: UUID, bounds: CGRect) {
        // Remove old entry if exists
        if objectBounds[objectID] != nil {
            remove(objectID: objectID)
        }

        objectBounds[objectID] = bounds
        insertIntoNode(root, objectID: objectID, bounds: bounds)
    }

    /// Remove an object - O(log n)
    func remove(objectID: UUID) {
        guard let bounds = objectBounds[objectID] else { return }
        objectBounds.removeValue(forKey: objectID)
        removeFromNode(root, objectID: objectID, bounds: bounds)
    }

    /// Update object bounds (remove + insert)
    func update(objectID: UUID, bounds: CGRect) {
        insert(objectID: objectID, bounds: bounds)
    }

    /// Clear all entries - O(1)
    func clear() {
        root = Node()
        objectBounds.removeAll()
    }

    /// Rebuild index from scratch with array of (UUID, CGRect)
    func rebuild(objects: [(UUID, CGRect)]) {
        clear()
        for (id, bounds) in objects {
            insert(objectID: id, bounds: bounds)
        }
    }

    // MARK: - Private Query

    private func queryNode(_ node: Node, viewport: CGRect, results: inout [UUID]) {
        // Early exit if node doesn't intersect viewport
        guard node.bounds.intersects(viewport) else { return }

        if node.isLeaf {
            // Leaf node: add all object IDs that intersect viewport
            for objectID in node.objectIDs {
                if let bounds = objectBounds[objectID], bounds.intersects(viewport) {
                    results.append(objectID)
                }
            }
        } else {
            // Internal node: recurse into children
            for child in node.children {
                queryNode(child, viewport: viewport, results: &results)
            }
        }
    }

    // MARK: - Private Insert

    private func insertIntoNode(_ node: Node, objectID: UUID, bounds: CGRect) {
        // Expand node bounds to contain new object
        if node.bounds.isEmpty {
            node.bounds = bounds
        } else {
            node.bounds = node.bounds.union(bounds)
        }

        if node.isLeaf {
            // Add to leaf node
            node.objectIDs.append(objectID)

            // Split if overflow
            if node.objectIDs.count > maxEntries {
                splitLeaf(node)
            }
        } else {
            // Choose best child to insert into
            let bestChild = chooseSubtree(node, bounds: bounds)
            insertIntoNode(bestChild, objectID: objectID, bounds: bounds)

            // Update bounds after insertion
            updateBounds(node)

            // Split if overflow
            if node.children.count > maxEntries {
                splitInternal(node)
            }
        }
    }

    // Choose child with minimum area enlargement
    private func chooseSubtree(_ node: Node, bounds: CGRect) -> Node {
        var bestChild = node.children[0]
        var minEnlargement = CGFloat.infinity

        for child in node.children {
            let enlargement = child.bounds.union(bounds).area - child.bounds.area
            if enlargement < minEnlargement {
                minEnlargement = enlargement
                bestChild = child
            }
        }

        return bestChild
    }

    // MARK: - Private Remove

    private func removeFromNode(_ node: Node, objectID: UUID, bounds: CGRect) {
        // Early exit if node doesn't contain the object
        guard node.bounds.intersects(bounds) else { return }

        if node.isLeaf {
            node.objectIDs.removeAll { $0 == objectID }
            // Recalculate bounds
            recalculateBounds(node)
        } else {
            for child in node.children {
                removeFromNode(child, objectID: objectID, bounds: bounds)
            }
            // Update bounds after removal
            updateBounds(node)
        }
    }

    // MARK: - Node Splitting

    private func splitLeaf(_ node: Node) {
        // Convert to internal node with two children
        let (group1, group2) = partitionObjects(node.objectIDs)

        let child1 = Node()
        child1.objectIDs = group1
        recalculateBounds(child1)

        let child2 = Node()
        child2.objectIDs = group2
        recalculateBounds(child2)

        node.objectIDs = []
        node.children = [child1, child2]
        updateBounds(node)
    }

    private func splitInternal(_ node: Node) {
        // Split children into two groups
        let (group1, group2) = partitionNodes(node.children)

        let child1 = Node()
        child1.children = group1
        updateBounds(child1)

        let child2 = Node()
        child2.children = group2
        updateBounds(child2)

        node.children = [child1, child2]
        updateBounds(node)
    }

    // Simple quadratic split - partition objects into two groups
    private func partitionObjects(_ objectIDs: [UUID]) -> ([UUID], [UUID]) {
        guard objectIDs.count >= 2 else { return (objectIDs, []) }

        // Find two most distant objects
        let (seed1, seed2) = findSeeds(objectIDs)

        var group1 = [seed1]
        var group2 = [seed2]
        var bounds1 = objectBounds[seed1] ?? .zero
        var bounds2 = objectBounds[seed2] ?? .zero

        // Assign remaining objects to group with least area increase
        for objectID in objectIDs where objectID != seed1 && objectID != seed2 {
            guard let bounds = objectBounds[objectID] else { continue }

            let enlargement1 = bounds1.union(bounds).area - bounds1.area
            let enlargement2 = bounds2.union(bounds).area - bounds2.area

            if enlargement1 < enlargement2 {
                group1.append(objectID)
                bounds1 = bounds1.union(bounds)
            } else {
                group2.append(objectID)
                bounds2 = bounds2.union(bounds)
            }
        }

        return (group1, group2)
    }

    // Similar partition for nodes
    private func partitionNodes(_ nodes: [Node]) -> ([Node], [Node]) {
        guard nodes.count >= 2 else { return (nodes, []) }

        // Find two most distant nodes
        var maxDist: CGFloat = 0
        var seed1 = nodes[0]
        var seed2 = nodes[1]

        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let dist = distance(nodes[i].bounds, nodes[j].bounds)
                if dist > maxDist {
                    maxDist = dist
                    seed1 = nodes[i]
                    seed2 = nodes[j]
                }
            }
        }

        var group1 = [seed1]
        var group2 = [seed2]
        var bounds1 = seed1.bounds
        var bounds2 = seed2.bounds

        for node in nodes where node !== seed1 && node !== seed2 {
            let enlargement1 = bounds1.union(node.bounds).area - bounds1.area
            let enlargement2 = bounds2.union(node.bounds).area - bounds2.area

            if enlargement1 < enlargement2 {
                group1.append(node)
                bounds1 = bounds1.union(node.bounds)
            } else {
                group2.append(node)
                bounds2 = bounds2.union(node.bounds)
            }
        }

        return (group1, group2)
    }

    // Find two most distant objects for splitting
    private func findSeeds(_ objectIDs: [UUID]) -> (UUID, UUID) {
        guard objectIDs.count >= 2 else { return (objectIDs[0], objectIDs[0]) }

        var maxDist: CGFloat = 0
        var seed1 = objectIDs[0]
        var seed2 = objectIDs[1]

        for i in 0..<objectIDs.count {
            for j in (i+1)..<objectIDs.count {
                guard let bounds1 = objectBounds[objectIDs[i]],
                      let bounds2 = objectBounds[objectIDs[j]] else { continue }

                let dist = distance(bounds1, bounds2)
                if dist > maxDist {
                    maxDist = dist
                    seed1 = objectIDs[i]
                    seed2 = objectIDs[j]
                }
            }
        }

        return (seed1, seed2)
    }

    // MARK: - Bounds Management

    private func updateBounds(_ node: Node) {
        if node.isLeaf {
            recalculateBounds(node)
        } else {
            node.bounds = .zero
            for child in node.children {
                node.bounds = node.bounds.isEmpty ? child.bounds : node.bounds.union(child.bounds)
            }
        }
    }

    private func recalculateBounds(_ node: Node) {
        node.bounds = .zero
        for objectID in node.objectIDs {
            if let bounds = objectBounds[objectID] {
                node.bounds = node.bounds.isEmpty ? bounds : node.bounds.union(bounds)
            }
        }
    }

    // MARK: - Utilities

    private func distance(_ rect1: CGRect, _ rect2: CGRect) -> CGFloat {
        let dx = rect1.midX - rect2.midX
        let dy = rect1.midY - rect2.midY
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - CGRect Extensions

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}
