//
//  PDFShapeAssembler.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Shape Assembly for Rendering Pipeline

/// Assembles final VectorShape objects from path data and styling for the rendering pipeline
class PDFShapeAssembler {
    
    private let vectorShapeBuilder: PDFVectorShapeBuilder
    private var shapeCounter = 0
    
    init(pageSize: CGSize) {
        self.vectorShapeBuilder = PDFVectorShapeBuilder(pageSize: pageSize)
    }
    
    // MARK: - Single Shape Assembly
    
    /// Create a VectorShape from path and styling components
    func assembleSingleShape(
        from pathBuilder: PDFPathBuilder,
        styleResolver: PDFStyleResolver,
        graphicsState: PDFGraphicsState,
        filled: Bool,
        stroked: Bool
    ) -> VectorShape? {
        
        guard pathBuilder.hasCurrentPath else {
            print("PDF: Cannot create shape - no path data")
            return nil
        }
        
        let pathCommands = pathBuilder.getCurrentPath()
        let shapeName = generateShapeName()
        
        // Create fill and stroke styles
        let fillStyle = filled ? styleResolver.createFillStyle(opacity: graphicsState.fillOpacity) : nil
        let strokeStyle = stroked ? styleResolver.createStrokeStyle(opacity: graphicsState.strokeOpacity) : nil
        
        // Ensure at least one style exists
        guard fillStyle != nil || strokeStyle != nil else {
            print("PDF: No fill or stroke specified - skipping invisible shape")
            return nil
        }
        
        let shape = vectorShapeBuilder.createVectorShape(
            from: pathCommands,
            name: shapeName,
            fillColor: styleResolver.currentFillColor,
            fillOpacity: graphicsState.fillOpacity,
            fillGradient: styleResolver.currentFillGradient,
            strokeColor: styleResolver.currentStrokeColor,
            strokeOpacity: graphicsState.strokeOpacity,
            strokeGradient: styleResolver.currentStrokeGradient
        )
        
        // Handle gradient tracking for compound paths
        if styleResolver.activeGradient != nil, 
           styleResolver.isCurrentFillWhite,
           pathBuilder.hasCompoundPaths {
            // Track this shape for compound gradient application
            styleResolver.trackShapeForGradient(shapeIndex: shapeCounter)
            print("PDF: 📝 Shape tracked for compound gradient")
        }
        
        print("PDF: ✅ Assembled single shape: '\(shapeName)'")
        return shape
    }
    
    // MARK: - Compound Shape Assembly
    
    /// Create a compound VectorShape from multiple path parts
    func assembleCompoundShape(
        from pathBuilder: PDFPathBuilder,
        styleResolver: PDFStyleResolver,
        graphicsState: PDFGraphicsState,
        filled: Bool,
        stroked: Bool
    ) -> VectorShape? {
        
        guard pathBuilder.hasCompoundPaths else {
            print("PDF: Cannot create compound shape - no compound path data")
            return nil
        }
        
        let pathParts = pathBuilder.getAllCompoundParts()
        let shapeName = generateCompoundShapeName()
        
        print("PDF: 🔧 Assembling compound shape with \(pathParts.count) subpaths")
        
        let shape = vectorShapeBuilder.createCompoundVectorShape(
            from: pathParts,
            name: shapeName,
            fillColor: styleResolver.currentFillColor,
            fillOpacity: graphicsState.fillOpacity,
            fillGradient: styleResolver.activeGradient ?? styleResolver.currentFillGradient,
            strokeColor: styleResolver.currentStrokeColor,
            strokeOpacity: graphicsState.strokeOpacity,
            strokeGradient: styleResolver.currentStrokeGradient
        )
        
        print("PDF: ✅ Assembled compound shape: '\(shapeName)' with \(pathParts.count) parts")
        return shape
    }
    
    // MARK: - Gradient Compound Shape Assembly
    
    /// Create compound shape from tracked gradient shapes
    func assembleGradientCompoundShape(
        from existingShapes: [VectorShape],
        trackedIndices: [Int],
        gradient: VectorGradient
    ) -> VectorShape? {
        
        guard !trackedIndices.isEmpty else {
            print("PDF: No shapes tracked for gradient compound")
            return nil
        }
        
        print("PDF: 🌈 Assembling gradient compound from \(trackedIndices.count) tracked shapes")
        
        var combinedPaths: [VectorPath] = []
        
        // Extract paths from tracked shapes
        for index in trackedIndices {
            if index < existingShapes.count {
                let shape = existingShapes[index]
                combinedPaths.append(shape.path)
                print("PDF: 📝 Added path from '\(shape.name)' to gradient compound")
            }
        }
        
        // Combine all paths into one compound path
        var allElements: [PathElement] = []
        for path in combinedPaths {
            allElements.append(contentsOf: path.elements)
        }
        
        let compoundPath = VectorPath(elements: allElements, isClosed: false, fillRule: .evenOdd)
        let fillStyle = FillStyle(gradient: gradient)
        let shapeName = generateGradientCompoundShapeName()
        
        let compoundShape = VectorShape(
            name: shapeName,
            path: compoundPath,
            strokeStyle: nil,
            fillStyle: fillStyle
        )
        
        print("PDF: ✅ Assembled gradient compound shape: '\(shapeName)'")
        return compoundShape
    }
    
    // MARK: - Paint Operation Handling
    
    /// Handle fill paint operation from rendering pipeline
    func handleFillOperation(
        pathBuilder: PDFPathBuilder,
        styleResolver: PDFStyleResolver,
        graphicsState: PDFGraphicsState
    ) -> VectorShape? {
        
        print("PDF: Fill operation - assembling filled shape")
        
        if pathBuilder.isInCompoundPath && pathBuilder.hasCompoundPaths {
            print("PDF: 🔍 COMPOUND PATH FILL - Assembling compound shape")
            let shape = assembleCompoundShape(
                from: pathBuilder,
                styleResolver: styleResolver,
                graphicsState: graphicsState,
                filled: true,
                stroked: false
            )
            pathBuilder.clearAllPaths()
            return shape
        } else {
            let shape = assembleSingleShape(
                from: pathBuilder,
                styleResolver: styleResolver,
                graphicsState: graphicsState,
                filled: true,
                stroked: false
            )
            pathBuilder.clearCurrentPath()
            return shape
        }
    }
    
    /// Handle stroke paint operation from rendering pipeline
    func handleStrokeOperation(
        pathBuilder: PDFPathBuilder,
        styleResolver: PDFStyleResolver,
        graphicsState: PDFGraphicsState
    ) -> VectorShape? {
        
        print("PDF: Stroke operation - assembling stroked shape")
        
        let shape = assembleSingleShape(
            from: pathBuilder,
            styleResolver: styleResolver,
            graphicsState: graphicsState,
            filled: false,
            stroked: true
        )
        pathBuilder.clearCurrentPath()
        return shape
    }
    
    /// Handle fill and stroke paint operation from rendering pipeline
    func handleFillAndStrokeOperation(
        pathBuilder: PDFPathBuilder,
        styleResolver: PDFStyleResolver,
        graphicsState: PDFGraphicsState
    ) -> VectorShape? {
        
        print("PDF: Fill and stroke operation - assembling dual-styled shape")
        
        let shape = assembleSingleShape(
            from: pathBuilder,
            styleResolver: styleResolver,
            graphicsState: graphicsState,
            filled: true,
            stroked: true
        )
        pathBuilder.clearCurrentPath()
        return shape
    }
    
    // MARK: - Shape Naming
    
    private func generateShapeName() -> String {
        shapeCounter += 1
        return "PDF Shape \(shapeCounter)"
    }
    
    private func generateCompoundShapeName() -> String {
        shapeCounter += 1
        return "PDF Compound Shape \(shapeCounter)"
    }
    
    private func generateGradientCompoundShapeName() -> String {
        shapeCounter += 1
        return "PDF Gradient Compound Shape \(shapeCounter)"
    }
}

// MARK: - Paint Operations Handler

/// Handles paint-related PDF operations for the rendering pipeline
struct PDFPaintOperations {
    
    /// Handle fill operation (f, F, f* operators)
    static func handleFill(
        pathBuilder: PDFPathBuilder,
        styleResolver: PDFStyleResolver,
        graphicsState: PDFGraphicsState,
        shapeAssembler: PDFShapeAssembler
    ) -> VectorShape? {
        return shapeAssembler.handleFillOperation(
            pathBuilder: pathBuilder,
            styleResolver: styleResolver,
            graphicsState: graphicsState
        )
    }
    
    /// Handle stroke operation (S operator)
    static func handleStroke(
        pathBuilder: PDFPathBuilder,
        styleResolver: PDFStyleResolver,
        graphicsState: PDFGraphicsState,
        shapeAssembler: PDFShapeAssembler
    ) -> VectorShape? {
        return shapeAssembler.handleStrokeOperation(
            pathBuilder: pathBuilder,
            styleResolver: styleResolver,
            graphicsState: graphicsState
        )
    }
    
    /// Handle fill and stroke operation (B, B* operators)
    static func handleFillAndStroke(
        pathBuilder: PDFPathBuilder,
        styleResolver: PDFStyleResolver,
        graphicsState: PDFGraphicsState,
        shapeAssembler: PDFShapeAssembler
    ) -> VectorShape? {
        return shapeAssembler.handleFillAndStrokeOperation(
            pathBuilder: pathBuilder,
            styleResolver: styleResolver,
            graphicsState: graphicsState
        )
    }
}