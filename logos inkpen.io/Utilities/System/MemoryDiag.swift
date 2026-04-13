import Foundation
import CoreGraphics

enum MemoryDiag {
    private static var lastReport = Date.distantPast
    private static var baselineMB = 0

    /// Call once at app launch to set the zero point.
    static func setBaseline() {
        baselineMB = processMemoryMB()
        print("📊 [MemDiag] BASELINE: \(baselineMB)MB")
    }

    /// Lightweight — prints only when memory grew ≥ 10 MB since last report.
    static func checkpoint(_ label: String) {
        let mb = processMemoryMB()
        let delta = mb - baselineMB
        print("📊 [Mem] \(label): \(mb)MB (Δ\(delta)MB from baseline)")
    }

    /// Full document breakdown. Throttled to 1/sec.
    static func report(_ label: String, document: VectorDocument? = nil) {
        let now = Date()
        guard now.timeIntervalSince(lastReport) >= 1.0 else { return }
        lastReport = now

        let mb = processMemoryMB()
        var parts = ["📊 [Mem] \(label): \(mb)MB"]

        if let doc = document {
            var embeddedBytes = 0
            var imageShapeCount = 0
            var pathElementCount = 0
            for obj in doc.snapshot.objects.values {
                switch obj.objectType {
                case .image(let s):
                    embeddedBytes += s.embeddedImageData?.count ?? 0
                    imageShapeCount += 1
                    pathElementCount += s.path.elements.count
                case .shape(let s), .text(let s), .warp(let s), .clipMask(let s), .guide(let s):
                    pathElementCount += s.path.elements.count
                case .group(let s), .clipGroup(let s):
                    pathElementCount += s.path.elements.count
                    for child in s.groupedShapes {
                        pathElementCount += child.path.elements.count
                    }
                }
            }
            var cachedPixels = 0
            for img in doc.imageStorage.values {
                cachedPixels += img.width * img.height
            }
            parts.append("obj=\(doc.snapshot.objects.count)")
            parts.append("layers=\(doc.snapshot.layers.count)")
            parts.append("imgShapes=\(imageShapeCount)")
            parts.append("embedded=\(embeddedBytes/1024)KB")
            parts.append("cgCache=\(doc.imageStorage.count)(\(cachedPixels*4/(1024*1024))MB)")
            parts.append("pathEls=\(pathElementCount)")
            parts.append("undo=\(doc.commandManager.undoCount)")
        }
        print(parts.joined(separator: " | "))
    }

    /// Dump every object's memory footprint.
    static func dumpObjects(_ doc: VectorDocument) {
        let mb = processMemoryMB()
        print("📊 [Mem] === OBJECT DUMP: \(doc.snapshot.objects.count) objects, process=\(mb)MB ===")
        for (id, obj) in doc.snapshot.objects {
            let shape = obj.shape
            let embedded = shape.embeddedImageData?.count ?? 0
            let pathEls = shape.path.elements.count
            let groupKids = shape.groupedShapes.count
            let memberCount = shape.memberIDs.count
            let typeName: String
            switch obj.objectType {
            case .shape: typeName = "shape"
            case .text: typeName = "text"
            case .image: typeName = "image"
            case .warp: typeName = "warp"
            case .group: typeName = "group"
            case .clipGroup: typeName = "clipGroup"
            case .clipMask: typeName = "clipMask"
            case .guide: typeName = "guide"
            }
            if embedded > 0 || pathEls > 100 || groupKids > 0 {
                print("  \(typeName) \(id): pathEls=\(pathEls) embedded=\(embedded/1024)KB groupKids=\(groupKids) members=\(memberCount)")
            }
        }
        // CGImage cache
        for (id, img) in doc.imageStorage {
            let px = img.width * img.height
            print("  cgCache \(id): \(img.width)x\(img.height) = \(px*4/(1024*1024))MB")
        }
    }

    /// Print heap size of key objects to find what's bloated.
    static func measureObjectSizes(_ doc: VectorDocument) {
        let mb = processMemoryMB()
        print("📊 [MemSize] process=\(mb)MB")
        print("  VectorDocument: \(malloc_size(Unmanaged.passUnretained(doc).toOpaque()))B")
        print("  snapshot.objects: \(doc.snapshot.objects.count) entries")
        print("  viewState: \(malloc_size(Unmanaged.passUnretained(doc.viewState).toOpaque()))B")
        print("  commandManager: \(malloc_size(Unmanaged.passUnretained(doc.commandManager).toOpaque()))B")
        print("  changeNotifier: \(malloc_size(Unmanaged.passUnretained(doc.changeNotifier).toOpaque()))B")
        print("  fontManager: \(malloc_size(Unmanaged.passUnretained(doc.fontManager).toOpaque()))B")
        // Metal singletons (shared, releasable)
        if let tileRenderer = MetalImageTileRenderer.shared {
            print("  MetalImageTileRenderer.shared: \(malloc_size(Unmanaged.passUnretained(tileRenderer).toOpaque()))B")
        } else {
            print("  MetalImageTileRenderer.shared: released")
        }
        print("  MetalComputeEngine.shared: \(malloc_size(Unmanaged.passUnretained(MetalComputeEngine.shared).toOpaque()))B")
        print("  GPUCoordinateTransform.shared: \(malloc_size(Unmanaged.passUnretained(GPUCoordinateTransform.shared).toOpaque()))B")
        print("  GPUMathAcceleratorSimple.shared: \(malloc_size(Unmanaged.passUnretained(GPUMathAcceleratorSimple.shared).toOpaque()))B")
        print("  MetalDrawingOptimizer.shared: \(malloc_size(Unmanaged.passUnretained(MetalDrawingOptimizer.shared).toOpaque()))B")
        print("  PDFMetalProcessor.shared: \(malloc_size(Unmanaged.passUnretained(PDFMetalProcessor.shared).toOpaque()))B")
        print("  PDFMetalAccelerator.shared: \(malloc_size(Unmanaged.passUnretained(PDFMetalAccelerator.shared).toOpaque()))B")
        print("  PDFHybridProcessor.shared: \(malloc_size(Unmanaged.passUnretained(PDFHybridProcessor.shared).toOpaque()))B")
        print("  process AFTER singleton access: \(processMemoryMB())MB")
    }

    /// Returns phys_footprint — same metric Xcode's memory gauge shows.
    static func processMemoryMB() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.phys_footprint) / (1024 * 1024)
    }
}
