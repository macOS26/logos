import SwiftUI

final class DrawingCanvasRegistry {
    static let shared = DrawingCanvasRegistry()
    private let lock = NSLock()
    private var _activeDocument: VectorDocument?

    var activeDocument: VectorDocument? {
        lock.lock()
        defer { lock.unlock() }
        if let doc = _activeDocument {
            print("📖 DrawingCanvasRegistry: Getting activeDocument \(ObjectIdentifier(doc))")
        } else {
            print("📖 DrawingCanvasRegistry: Getting activeDocument NIL")
        }
        return _activeDocument
    }

    private init() {}

    func setActiveDocument(_ document: VectorDocument) {
        lock.lock()
        defer { lock.unlock() }
        _activeDocument = document
        print("🎯 DrawingCanvasRegistry: activeDocument set to \(ObjectIdentifier(document))")
    }
}
