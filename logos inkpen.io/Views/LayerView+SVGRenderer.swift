//
//  LayerView+SVGRenderer.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import CoreGraphics

// MARK: - SVG Shape Renderer
/// Custom view that renders SVG content using CoreSVG
struct SVGShapeRenderer: NSViewRepresentable {
    let svgDocument: SVGToInkPenImporter.SVGDocument
    let bounds: CGRect
    let transform: CGAffineTransform
    let opacity: Double
    
    func makeNSView(context: Context) -> SVGRenderingView {
        SVGRenderingView(svgDocument: svgDocument)
    }
    
    func updateNSView(_ nsView: SVGRenderingView, context: Context) {
        nsView.svgDocument = svgDocument
        nsView.svgBounds = bounds
        nsView.svgTransform = transform
        nsView.svgOpacity = opacity
        nsView.needsDisplay = true
    }
}

class SVGRenderingView: NSView {
    var svgDocument: SVGToInkPenImporter.SVGDocument
    var svgBounds: CGRect = .zero
    var svgTransform: CGAffineTransform = .identity
    var svgOpacity: Double = 1.0
    
    init(svgDocument: SVGToInkPenImporter.SVGDocument) {
        self.svgDocument = svgDocument
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Configure context for high-quality vector rendering
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.saveGState()
        
        // Apply transform and opacity
        context.concatenate(svgTransform)
        context.setAlpha(svgOpacity)
        
        // Render the SVG using CoreSVG
        svgDocument.renderToVectorContext(context, targetSize: svgBounds.size)
        
        context.restoreGState()
    }
}
