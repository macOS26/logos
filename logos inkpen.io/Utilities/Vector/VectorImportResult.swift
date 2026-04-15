import SwiftUI

struct VectorImportResult: Identifiable {
    let id = UUID()
    let success: Bool
    let shapes: [VectorShape]
    let metadata: VectorImportMetadata
    let errors: [VectorImportError]
    let warnings: [String]
    /// Native InkPen layers parsed from the source file. `objectIDs` references
    /// shape UUIDs from `shapes`. Empty when the source has no layer info.
    var layers: [Layer] = []
    /// Native group VectorShape IDs within `shapes`. Already included in `shapes`.
    var groupShapeIDs: [UUID] = []
}

extension VectorImportResult {
    /// Shape predicate for the standard import path. Returning false drops the
    /// shape before it lands in the document — keeps the undo payload clean
    /// (e.g. empty image placeholders shouldn't enter snapshot.objects).
    typealias ShapeFilter = (VectorShape) -> Bool

    /// Build an `ImportCommand` for this result and dispatch it through
    /// `document.commandManager`. Single source of truth for File → Import,
    /// the in-window `.fileImporter` callback, and the SF Symbols picker.
    ///
    /// - Parameter document: the target doc.
    /// - Parameter fallbackLayer: which layer index to use when the result
    ///   carries no parsed layer info (defaults to `selectedLayerIndex`,
    ///   then the first user layer).
    /// - Parameter filter: optional per-shape predicate. Shapes returning
    ///   false are dropped.
    /// - Returns: the dispatched command (already executed and on the undo
    ///   stack), or nil if the result was unsuccessful or no fallback
    ///   layer was available.
    @MainActor
    @discardableResult
    func dispatchAsImportCommand(into document: VectorDocument,
                                 fallbackLayer: Int? = nil,
                                 filter: ShapeFilter? = nil) -> ImportCommand? {
        guard success else { return nil }
        guard let target = fallbackLayer
                            ?? document.selectedLayerIndex
                            ?? document.snapshot.layers.indices.first else { return nil }

        let usable: [VectorShape]
        if let filter = filter { usable = shapes.filter(filter) } else { usable = shapes }

        // Pre-compute where parsed layers will land once the command appends them.
        // Each imported layer gets a FRESH UUID (so the spatial index can key it
        // separately from any existing layer) and a NAME that doesn't collide
        // with existing doc layer names (so the user sees them apart in the
        // layer panel).
        let existingNames = Set(document.snapshot.layers.map { $0.name })
        let layersToAppend: [Layer] = layers.map { parsed in
            Layer(
                id: UUID(),                                       // fresh UUID
                name: Self.uniqueName(parsed.name, against: existingNames),
                objectIDs: parsed.objectIDs,
                isVisible: parsed.isVisible,
                isLocked: parsed.isLocked,
                opacity: parsed.opacity,
                blendMode: parsed.blendMode,
                color: parsed.color
            )
        }

        let baseCount = document.snapshot.layers.count
        var parsedToDocLayer: [Int: Int] = [:]
        if layersToAppend.isEmpty {
            parsedToDocLayer[0] = target
        } else {
            for (idx, _) in layersToAppend.enumerated() {
                parsedToDocLayer[idx] = baseCount + idx
            }
        }
        let defaultTarget = parsedToDocLayer[0] ?? target

        var shapeIDToParsedLayer: [UUID: Int] = [:]
        for (idx, parsedLayer) in layers.enumerated() {
            for id in parsedLayer.objectIDs { shapeIDToParsedLayer[id] = idx }
        }

        var topLevel: [VectorObject] = []
        var members: [VectorObject] = []

        @MainActor
        func collectMembers(of shape: VectorShape, layer: Int, into ids: inout [UUID]) {
            for child in shape.groupedShapes {
                var childMemberIDs = child.memberIDs
                if (child.isGroup || child.isClippingGroup) && !child.groupedShapes.isEmpty {
                    collectMembers(of: child, layer: layer, into: &childMemberIDs)
                }
                var resolved = child
                resolved.memberIDs = childMemberIDs
                resolved.groupedShapes = []
                let type = VectorObject.determineType(for: resolved)
                members.append(VectorObject(id: resolved.id, layerIndex: layer, objectType: type))
                ids.append(resolved.id)
            }
        }

        for shape in usable {
            let dest = shapeIDToParsedLayer[shape.id]
                .flatMap { parsedToDocLayer[$0] } ?? defaultTarget

            if (shape.isGroup || shape.isClippingGroup) && !shape.groupedShapes.isEmpty {
                var container = shape
                var memberIDs = container.memberIDs
                collectMembers(of: container, layer: dest, into: &memberIDs)
                container.memberIDs = memberIDs
                container.groupedShapes = []
                let type = VectorObject.determineType(for: container)
                topLevel.append(VectorObject(id: container.id, layerIndex: dest, objectType: type))
            } else {
                let type = VectorObject.determineType(for: shape)
                topLevel.append(VectorObject(id: shape.id, layerIndex: dest, objectType: type))
            }
        }

        let command = ImportCommand(newLayers: layersToAppend, topLevel: topLevel, members: members)
        document.commandManager.execute(command)
        return command
    }

    /// Pick a layer name that doesn't collide with `existing`. If `proposed`
    /// is free, return it. Otherwise append " 2", " 3", ... until unique.
    private static func uniqueName(_ proposed: String, against existing: Set<String>) -> String {
        if !existing.contains(proposed) { return proposed }
        var n = 2
        while existing.contains("\(proposed) \(n)") { n += 1 }
        return "\(proposed) \(n)"
    }
}

struct VectorImportMetadata {
    let originalFormat: VectorFileFormat
    let documentSize: CGSize
    let viewBoxSize: CGSize?
    let colorSpace: String
    let units: VectorUnit
    let dpi: Double
    let layerCount: Int
    let shapeCount: Int
    let textObjectCount: Int
    let importDate: Date
    let sourceApplication: String?
    let documentVersion: String?
    let inkpenMetadata: String?
}

enum VectorUnit: String, CaseIterable {
    case points = "pt"
    case inches = "in"
    case millimeters = "mm"
    case pixels = "px"
    case picas = "pc"

    var pointsPerUnit: Double {
        switch self {
        case .points: return 1.0
        case .inches: return 72.0
        case .millimeters: return 72.0 / 25.4
        case .pixels: return 1.0
        case .picas: return 12.0
        }
    }
}

enum VectorImportError: Error, LocalizedError {
    case fileNotFound
    case unsupportedFormat(VectorFileFormat)
    case corruptedFile
    case invalidStructure(String)
    case missingFonts([String])
    case colorSpaceNotSupported(String)
    case scalingError(String)
    case parsingError(String, line: Int?)
    case commercialLicenseRequired(VectorFileFormat)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "File not found or inaccessible"
        case .unsupportedFormat(let format):
            return "Unsupported file format: \(format.displayName)"
        case .corruptedFile:
            return "File appears to be corrupted or incomplete"
        case .invalidStructure(let detail):
            return "Invalid file structure: \(detail)"
        case .missingFonts(let fonts):
            return "Missing fonts: \(fonts.joined(separator: ", "))"
        case .colorSpaceNotSupported(let colorSpace):
            return "Color space not supported: \(colorSpace)"
        case .scalingError(let detail):
            return "Scaling conversion error: \(detail)"
        case .parsingError(let detail, let line):
            if let line = line {
                return "Parsing error at line \(line): \(detail)"
            } else {
                return "Parsing error: \(detail)"
            }
        case .commercialLicenseRequired(let format):
            return "\(format.displayName) requires commercial license (Open Design Alliance)"
        }
    }
}
