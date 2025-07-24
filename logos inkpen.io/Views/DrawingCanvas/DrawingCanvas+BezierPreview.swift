//
//  DrawingCanvas+BezierPreview.swift
//  logos inkpen.io
//
//  Bezier preview functionality
//

import SwiftUI

extension DrawingCanvas {
    @ViewBuilder
    internal func fillClosePreview(geometry: GeometryProxy) -> some View {
        // Show fill preview when close to closing path - this shows what the final filled shape will look like
        if showClosePathHint && bezierPoints.count >= 3,
           let currentBezierPath = bezierPath {
            
            let lastPointIndex = bezierPoints.count - 1
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            
            // Get handle information for proper closing curve
            let lastPointHandles = bezierHandles[lastPointIndex]
            let firstPointHandles = bezierHandles[0]
            
            // Create complete preview path (existing path + closing segment)
            Path { path in
                // Start with the existing path elements (converted to SwiftUI Path)
                addPathElements(currentBezierPath.elements, to: &path)
                
                // Add the closing segment with proper curve handling
                let lastPoint = bezierPoints[lastPointIndex]
                let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
                
                if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
                    // Both points have handles - create smooth closing curve
                    let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                    let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                    path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstControl1Location)
                } else if let lastControl2 = lastPointHandles?.control2 {
                    // Only last point has handle - asymmetric curve
                    let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                    path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstPointLocation)
                } else if let firstControl1 = firstPointHandles?.control1 {
                    // Only first point has handle - asymmetric curve
                    let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                    path.addCurve(to: firstPointLocation, control1: lastPointLocation, control2: firstControl1Location)
                } else {
                    // Straight line close
                    path.addLine(to: firstPointLocation)
                }
                
                // Close the path for fill preview
                path.closeSubpath()
            }
            .fill(document.defaultFillColor.color.opacity(0.3)) // Semi-transparent fill preview
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
    }
    
    @ViewBuilder
    internal func rubberBandFillPreview(geometry: GeometryProxy) -> some View {
        // Show fill preview during normal drawing - BETTER THAN ADOBE!
        if let mouseLocation = currentMouseLocation,
           let currentBezierPath = bezierPath,
           bezierPoints.count >= 2 {
            
            let canvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
            let lastPointIndex = bezierPoints.count - 1
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            
            // Create preview path (existing path + rubber band to cursor + back to first point)
            Path { path in
                // Start with the existing path elements (converted to SwiftUI Path)
                addPathElements(currentBezierPath.elements, to: &path)
                
                // Add rubber band segment to cursor
                if let lastPointHandles = bezierHandles[lastPointIndex],
                   let lastControl2 = lastPointHandles.control2 {
                    // Curve rubber band
                    let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                    path.addCurve(
                        to: canvasMouseLocation,
                        control1: lastControl2Location,
                        control2: canvasMouseLocation
                    )
                } else {
                    // Straight rubber band
                    path.addLine(to: canvasMouseLocation)
                }
                
                // Add line back to first point to complete the preview shape
                path.addLine(to: firstPointLocation)
                
                // Close the path for fill preview
                path.closeSubpath()
            }
            .fill(document.defaultFillColor.color.opacity(0.15)) // Very subtle fill preview (lighter than close preview)
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
    }
    
    // MARK: - Professional Preview Functions (Adobe Illustrator Standards)
    
    // REMOVED: bezierPathPreview() - Now using real VectorShapes with actual document colors
    // Professional vector apps (Illustrator, FreeHand, CorelDraw) show the actual path being built, not a preview
    
    @ViewBuilder
    internal func rubberBandPreview(geometry: GeometryProxy) -> some View {
        if isBezierDrawing && document.currentTool == .bezierPen,
           let mouseLocation = currentMouseLocation,
           bezierPoints.count > 0 {
            let canvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
            let lastPointIndex = bezierPoints.count - 1
            let lastPoint = bezierPoints[lastPointIndex]
            let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
            
            // PROFESSIONAL SCALE-INDEPENDENT RUBBER BAND (Adobe Illustrator Standards)
            let strokeWidth = 2.0 / document.zoomLevel    // Scale-independent close preview
            let rubberBandWidth = 1.0 / document.zoomLevel  // Scale-independent rubber band
            
            // RUBBER BAND FILL PREVIEW - Show what next point would look like (only when NOT closing)
            if bezierPoints.count >= 2 && !showClosePathHint {
                rubberBandFillPreview(geometry: geometry)
            }
            
            // PROFESSIONAL FILL PREVIEW - Show what the closed shape will look like
            if showClosePathHint && bezierPoints.count >= 3 {
                fillClosePreview(geometry: geometry)
            }
            
            // PROFESSIONAL CLOSING STROKE PREVIEW
            if showClosePathHint && bezierPoints.count >= 3 {
                // Show the closing stroke back to first point (GREEN) with curve preview
                let firstPoint = bezierPoints[0]
                let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                
                // Check if we have handles for closing curve preview
                let lastPointHandles = bezierHandles[lastPointIndex]
                let firstPointHandles = bezierHandles[0]
                
                Path { path in
                    path.move(to: lastPointLocation)
                    
                    // Create preview of closing curve
                    if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
                        // Both points have handles - show smooth closing curve preview
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                        path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstControl1Location)
                    } else if let lastControl2 = lastPointHandles?.control2 {
                        // Only last point has handle - asymmetric curve preview
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstPointLocation)
                    } else if let firstControl1 = firstPointHandles?.control1 {
                        // Only first point has handle - asymmetric curve preview
                        let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                        path.addCurve(to: firstPointLocation, control1: lastPointLocation, control2: firstControl1Location)
                    } else {
                        // Straight line close
                        path.addLine(to: firstPointLocation)
                    }
                }
                .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            } else {
                // PROFESSIONAL ADOBE ILLUSTRATOR RUBBER BAND WITH CURVE PREVIEW
                Path { path in
                    path.move(to: lastPointLocation)
                    
                    // PROFESSIONAL RUBBER BAND LOGIC (Adobe Illustrator/FreeHand/CorelDraw Style)
                    // Key insight: Rubber band depends ONLY on the previous point's handles
                    if let lastPointHandles = bezierHandles[lastPointIndex],
                       let lastControl2 = lastPointHandles.control2 {
                        // CURVE RUBBER BAND: Previous point has outgoing handle
                        // Show curve tangent to the existing outgoing handle (like Adobe Illustrator)
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        
                        print("🔧 DEBUG STEP 1: Rubber band preview - CURVE")
                        print("   Last point \(lastPointIndex) has outgoing handle at: (\(lastControl2.x), \(lastControl2.y))")
                        
                        // FIXED: Use EXACT same math as step 3 - no complex handle calculation!
                        // Step 3 uses: control1: lastControl2, control2: targetPoint
                        // This creates natural curves without hooks
                        path.addCurve(
                            to: canvasMouseLocation,
                            control1: lastControl2Location,
                            control2: canvasMouseLocation
                        )
                        print("   ✅ Rubber band curve uses SAME math as step 2")
                        
                    } else {
                        // STRAIGHT RUBBER BAND: Previous point is corner point (no outgoing handle)
                        // Show straight line preview (like Adobe Illustrator for corner points)
                        path.addLine(to: canvasMouseLocation)
                    }
                }
                .stroke(Color.blue.opacity(0.8), style: SwiftUI.StrokeStyle(lineWidth: rubberBandWidth, lineCap: .round, dash: [4, 2]))
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                
                // NOTE: Professional pen tools (Illustrator, FreeHand, CorelDraw) do NOT show handles at cursor
                // They only show the curve preview. Handles are only visible on actual anchor points.
            }
        }
    }
    
    @ViewBuilder
    internal func bezierClosePathHint() -> some View {
        // PROFESSIONAL CLOSE PATH VISUAL HINT - USE SAME COORDINATE SYSTEM AS ARROW TOOL
        if showClosePathHint {
            ZStack {
                // Green circle indicating close path area - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                Circle()
                    .stroke(Color.green, lineWidth: 2.0)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 16, height: 16) // Fixed UI size - does not scale with artwork
                    .position(CGPoint(
                        x: closePathHintLocation.x * document.zoomLevel + document.canvasOffset.x,
                        y: closePathHintLocation.y * document.zoomLevel + document.canvasOffset.y
                    ))
                
                // Small "close" icon - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                Image(systemName: "multiply.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12)) // Fixed UI size - does not scale with artwork
                    .position(CGPoint(
                        x: closePathHintLocation.x * document.zoomLevel + document.canvasOffset.x,
                        y: closePathHintLocation.y * document.zoomLevel + document.canvasOffset.y
                    ))
            }
            .animation(.easeInOut(duration: 0.2), value: showClosePathHint)
        }
    }
    
    @ViewBuilder
    internal func bezierControlHandles() -> some View {
        // Render bezier handles if they exist
        if isBezierDrawing {
            ForEach(bezierPoints.indices, id: \.self) { index in
                if let handleInfo = bezierHandles[index], handleInfo.hasHandles {
                    let pointLocation = CGPoint(x: bezierPoints[index].x, y: bezierPoints[index].y)
                    
                    // Draw control handle lines - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    if let control1 = handleInfo.control1 {
                        let control1Location = CGPoint(x: control1.x, y: control1.y)
                        Path { path in
                            path.move(to: pointLocation)
                            path.addLine(to: control1Location)
                        }
                        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel) // Scale-independent
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                        
                        // Control handle circle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4) // Fixed UI size - does not scale with artwork
                            .position(CGPoint(
                                x: control1Location.x * document.zoomLevel + document.canvasOffset.x,
                                y: control1Location.y * document.zoomLevel + document.canvasOffset.y
                            ))
                    }
                    
                    if let control2 = handleInfo.control2 {
                        let control2Location = CGPoint(x: control2.x, y: control2.y)
                        Path { path in
                            path.move(to: pointLocation)
                            path.addLine(to: control2Location)
                        }
                        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel) // Scale-independent
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                        
                        // Control handle circle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4) // Fixed UI size - does not scale with artwork
                            .position(CGPoint(
                                x: control2Location.x * document.zoomLevel + document.canvasOffset.x,
                                y: control2Location.y * document.zoomLevel + document.canvasOffset.y
                            ))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    internal func bezierAnchorPoints() -> some View {
        // PROFESSIONAL BEZIER ANCHOR POINTS - USE SAME COORDINATE SYSTEM AS ARROW TOOL
        if isBezierDrawing {
            ForEach(bezierPoints.indices, id: \.self) { index in
                let point = bezierPoints[index]
                let pointLocation = CGPoint(x: point.x, y: point.y)
                let isActive = activeBezierPointIndex == index
                
                // PROFESSIONAL ANCHOR POINT RENDERING - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                // Active point: solid black square with white stroke
                // Inactive point: hollow white square with black stroke
                // Note: Removed green square highlighting - close hint circle and preview line are sufficient
                Rectangle()
                    .fill(isActive ? Color.black : Color.white)
                    .overlay(
                        Rectangle()
                            .stroke(isActive ? Color.white : Color.black, lineWidth: 1.0)
                    )
                    .frame(width: 6, height: 6) // Fixed UI size - does not scale with artwork
                    .position(CGPoint(
                        x: pointLocation.x * document.zoomLevel + document.canvasOffset.x,
                        y: pointLocation.y * document.zoomLevel + document.canvasOffset.y
                    ))
            }
        }
    }
} 