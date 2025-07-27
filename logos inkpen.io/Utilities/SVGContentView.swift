import SwiftUI
import UniformTypeIdentifiers
import Darwin
import Foundation
import AppKit
import CoreGraphics

// CoreSVG Framework Bridge
@objc
class CGSVGDocument: NSObject { }

var CGSVGDocumentRetain: (@convention(c) (CGSVGDocument?) -> Unmanaged<CGSVGDocument>?) = load("CGSVGDocumentRetain")
var CGSVGDocumentRelease: (@convention(c) (CGSVGDocument?) -> Void) = load("CGSVGDocumentRelease")
var CGSVGDocumentCreateFromData: (@convention(c) (CFData?, CFDictionary?) -> Unmanaged<CGSVGDocument>?) = load("CGSVGDocumentCreateFromData")
var CGContextDrawSVGDocument: (@convention(c) (CGContext?, CGSVGDocument?) -> Void) = load("CGContextDrawSVGDocument")
var CGSVGDocumentGetCanvasSize: (@convention(c) (CGSVGDocument?) -> CGSize) = load("CGSVGDocumentGetCanvasSize")

let CoreSVG = dlopen("/System/Library/PrivateFrameworks/CoreSVG.framework/CoreSVG", RTLD_NOW)

func load<T>(_ name: String) -> T {
    unsafeBitCast(dlsym(CoreSVG, name), to: T.self)
}

// SVG Class for Core Graphics Vector Rendering
public class SVG: ObservableObject {
    
    deinit { CGSVGDocumentRelease(document) }
    
    let document: CGSVGDocument
    
    public convenience init?(_ value: String) {
        guard let data = value.data(using: .utf8) else { return nil }
        self.init(data)
    }
    
    public init?(_ data: Data) {
        guard let document = CGSVGDocumentCreateFromData(data as CFData, nil)?.takeUnretainedValue() else { return nil }
        guard CGSVGDocumentGetCanvasSize(document) != .zero else { return nil }
        self.document = document
    }
    
    public var size: CGSize {
        CGSVGDocumentGetCanvasSize(document)
    }
    
    // Create Core Graphics PDF context (vector output)
    public func createCGPDFContext(url: URL, mediaBox: CGRect) -> CGContext? {
        var mutableMediaBox = mediaBox
        return CGContext(url as CFURL, mediaBox: &mutableMediaBox, nil)
    }
    
    // Create Core Graphics EPS context (vector output)
    public func createCGEPSContext(url: URL, mediaBox: CGRect) -> CGContext? {
        var mutableMediaBox = mediaBox
        return CGContext(url as CFURL, mediaBox: &mutableMediaBox, nil)
    }
    
    // Render to Core Graphics vector context
    public func renderToVectorContext(_ context: CGContext, targetSize: CGSize) {
        let originalSize = self.size
        
        // Save graphics state
        context.saveGState()
        
        // Calculate scaling to fit target size while maintaining aspect ratio
        let scaleX = targetSize.width / originalSize.width
        let scaleY = targetSize.height / originalSize.height
        let scale = min(scaleX, scaleY)
        
        // Center the drawing
        let scaledWidth = originalSize.width * scale
        let scaledHeight = originalSize.height * scale
        let offsetX = (targetSize.width - scaledWidth) / 2
        let offsetY = (targetSize.height - scaledHeight) / 2
        
        // Apply transformations for proper vector scaling
        context.translateBy(x: offsetX, y: offsetY + scaledHeight)
        context.scaleBy(x: scale, y: -scale)
        
        // Draw SVG to vector context (this preserves vector data)
        CGContextDrawSVGDocument(context, document)
        
        context.restoreGState()
    }
    
    // Export as PDF (vector format)
    public func exportAsPDF(to url: URL, pageSize: CGSize) -> Bool {
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            return false
        }
        
        context.beginPDFPage(nil)
        renderToVectorContext(context, targetSize: pageSize)
        context.endPDFPage()
        context.closePDF()
        
        return true
    }
    
    // Export as EPS (vector format)
    public func exportAsEPS(to url: URL, boundingBox: CGRect) -> Bool {
        var bbox = boundingBox
        
        // Note: CGContext EPS creation might not be available on all systems
        // This is a conceptual implementation
        guard let context = CGContext(url as CFURL, mediaBox: &bbox, [
            kCGPDFContextCreator: "CoreSVG Vector Exporter" as CFString
        ] as CFDictionary) else {
            return false
        }
        
        context.beginPDFPage(nil)
        renderToVectorContext(context, targetSize: boundingBox.size)
        context.endPDFPage()
        context.closePDF()
        
        return true
    }
}

// Core Graphics Vector NSView
struct CGVectorNSView: NSViewRepresentable {
    let svg: SVG
    
    func makeNSView(context: Context) -> VectorNSView {
        VectorNSView(svg: svg)
    }
    
    func updateNSView(_ nsView: VectorNSView, context: Context) {
        nsView.svg = svg
        nsView.needsDisplay = true
    }
}

class VectorNSView: NSView {
    var svg: SVG
    
    init(svg: SVG) {
        self.svg = svg
        super.init(frame: .zero)
        self.wantsLayer = true
        
        // Configure for vector rendering
        self.layer?.contentsScale = 1.0 // Prevent automatic scaling
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Configure context for vector rendering
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        // Clear background
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        context.fill(bounds)
        
        // Render as vector
        svg.renderToVectorContext(context, targetSize: bounds.size)
    }
}

// Add file type support
extension UTType {
    static var svg: UTType {
        UTType(filenameExtension: "svg") ?? UTType.xml
    }
}
