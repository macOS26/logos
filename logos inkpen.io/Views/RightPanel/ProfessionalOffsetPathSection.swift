//
//  ProfessionalOffsetPathSection.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import Combine

// MARK: - Professional Offset Path Section (Professional Standards)

struct ProfessionalOffsetPathSection: View {
    @ObservedObject var document: VectorDocument
    @State private var offsetDistance: Int = 10
    @State private var selectedJoinType: JoinType = .round
    @State private var miterLimit: Double = 4.0
    @State private var showAdvanced: Bool = true
    @State private var keepOriginalPath: Bool = true


    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with disclosure triangle
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showAdvanced ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("Offset Path")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()
                
                // Professional icon
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            
            if showAdvanced {
                VStack(alignment: .leading, spacing: 10) {
                    // Offset Distance Control
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Offset:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(offsetDistance)pt")
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: Binding(
                            get: { Double(offsetDistance) },
                            set: { offsetDistance = Int($0) }
                        ), in: -30...30) {
                            Text("Offset Distance")
                        }
                        .controlSize(.regular)
                        .tint(.blue)
                    }
                    
                    // Keep Original Path Toggle (Professional Standard)
                    HStack {
                        Toggle("Keep Original Path", isOn: $keepOriginalPath)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .font(.caption)
                            .help("Keep the original path when creating offset (Professional default)")

                        Spacer()
                    }
                    

                    
                    // Join Type Selection (Professional style)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Joins:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 6) {
                            ForEach([JoinType.round, .square, .bevel, .miter], id: \.self) { joinType in
                                Button {
                                    selectedJoinType = joinType
                                } label: {
                                    VStack(spacing: 2) {
                                        Image(systemName: joinType.iconName)
                                            .font(.system(size: 12))
                                        
                                        Text(joinType.displayName)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(selectedJoinType == joinType ? .accentColor : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedJoinType == joinType ? Color.accentColor.opacity(0.1) : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(selectedJoinType == joinType ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                            )
                                    )
                                    .contentShape(Rectangle()) // Extend hit area to match entire button background
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .help(joinType.description)
                            }
                        }
                    }
                    
                    // Miter Limit (only show for miter joins)
                    if selectedJoinType == .miter {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Miter Limit:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(miterLimit, specifier: "%.1f")")
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                    .monospacedDigit()
                            }
                            
                            Slider(value: $miterLimit, in: 1.0...20.0) {
                                Text("Miter Limit")
                            }
                            .controlSize(.regular)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    

                    
                    // Offset Path button - Full Width
                    Button {
                        performOffsetPath()
                    } label: {
                        Text("Offset Path")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .onTapGesture { // Luna Display compatibility
                        performOffsetPath()
                    }
                    .help("Create offset path with current settings (⌘⌥O)")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func canPerformOffset() -> Bool {
        return !document.selectedShapeIDs.isEmpty
    }
    

    
    private func performOffsetPath() {
        guard !document.selectedShapeIDs.isEmpty else { return }
        
        Log.fileOperation("🎨 PROFESSIONAL OFFSET PATH: \(offsetDistance)pt, join: \(selectedJoinType)", level: .info)
        
        // Save to undo stack
        document.saveToUndoStack()
        
        // Get selected shapes and their indices for proper stacking order
        let selectedShapes = document.getSelectedShapes()
        var newOffsetShapeIDs: Set<UUID> = []
        
        // Store original shape indices for proper insertion
        var originalShapeIndices: [UUID: Int] = [:]
        if let layerIndex = document.selectedLayerIndex {
            let shapes = document.getShapesForLayer(layerIndex)
            for (index, shape) in shapes.enumerated() {
                if document.selectedShapeIDs.contains(shape.id) {
                    originalShapeIndices[shape.id] = index
                }
            }
        }
        
        for shape in selectedShapes {
            
            // PROPER OFFSET PATH: Create an offset path using CoreGraphics stroking
            let offsetValue = CGFloat(offsetDistance)
            
            // Create offset path by stroking with the offset distance
            let offsetPath = shape.path.cgPath.copy(strokingWithWidth: abs(offsetValue) * 2.0,
                                                    lineCap: .round,
                                                    lineJoin: mapJoinTypeToCoreGraphics(selectedJoinType),
                                                    miterLimit: CGFloat(miterLimit))
            
            var finalPath: CGPath
            
            if offsetDistance >= 0 {
                // POSITIVE OFFSET: Union with original
                if let unionResult = CoreGraphicsPathOperations.union(shape.path.cgPath, offsetPath, using: .winding) {
                    finalPath = unionResult
                    Log.fileOperation("🔧 POSITIVE OFFSET: Created expanded offset path", level: .info)
                } else {
                    finalPath = offsetPath
                    Log.fileOperation("⚠️ POSITIVE OFFSET: Union failed, using stroke result", level: .info)
                }
            } else {
                // NEGATIVE OFFSET: Subtract stroke from original
                if let subtractResult = CoreGraphicsPathOperations.subtract(offsetPath, from: shape.path.cgPath, using: .winding) {
                    finalPath = subtractResult
                    Log.fileOperation("🔧 NEGATIVE OFFSET: Created contracted offset path", level: .info)
                } else {
                    finalPath = shape.path.cgPath
                    Log.fileOperation("⚠️ NEGATIVE OFFSET: Subtraction failed, keeping original", level: .info)
                }
            }
                
                // Create the final offset shape
                let offsetVectorPath = VectorPath(cgPath: finalPath)
                let offsetShape = VectorShape(
                    name: "\(shape.name) Offset \(offsetDistance > 0 ? "+" : "")\(offsetDistance)pt",
                    path: offsetVectorPath,
                    strokeStyle: shape.strokeStyle,
                    fillStyle: shape.fillStyle,
                    transform: shape.transform,
                    opacity: shape.opacity
                )
                
                // Insert offset shape with proper ordering based on offset direction
                if offsetDistance >= 0 {
                    // POSITIVE OFFSET: Goes BEHIND original shape (lower orderID)
                    if let layerIndex = document.selectedLayerIndex {
                        document.layers[layerIndex].addShape(offsetShape)
                        // Use new behind insertion method to ensure proper orderID
                        document.addShapeBehindInUnifiedSystem(offsetShape, layerIndex: layerIndex, behindShapeIDs: [shape.id])
                    }
                    Log.fileOperation("🔧 POSITIVE OFFSET: Added behind original with lower orderID", level: .info)
                } else {
                    // NEGATIVE OFFSET: Goes in FRONT of original shape (higher orderID)  
                    document.addShape(offsetShape)
                    Log.fileOperation("🔧 NEGATIVE OFFSET: Added in front of original with higher orderID", level: .info)
                }
                
                newOffsetShapeIDs.insert(offsetShape.id)
            
        }
        
        // Handle stacking order based on offset direction
        if keepOriginalPath {
            if offsetDistance >= 0 {
                // POSITIVE OFFSET: Offset shapes are already inserted behind originals
                Log.fileOperation("🔧 POSITIVE OFFSET: Offset shapes already positioned behind originals", level: .info)
            } else {
                // NEGATIVE OFFSET: Offset shapes are already positioned after originals
                Log.fileOperation("🔧 NEGATIVE OFFSET: Offset shapes already positioned after originals", level: .info)
            }
        } else {
            // Remove original shapes if not keeping them
            document.removeSelectedShapes()
        }
        
        // Always select the result of the offset path operation
        document.selectedShapeIDs = newOffsetShapeIDs
        
        // CRITICAL FIX: Sync unified objects after creating offset shapes
        document.updateUnifiedObjectsOptimized()
        
        // Force document refresh so arrow tool can see newly created shapes
        document.objectWillChange.send()
         
         Log.info("✅ OFFSET PATH: Created offset shapes \(keepOriginalPath ? "behind" : "replacing") originals", category: .general)
    }
    

    
    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.2)) {
            offsetDistance = 10
            selectedJoinType = .miter
            miterLimit = 4.0
            keepOriginalPath = true
        }
    }
    
    private func mapJoinTypeToCoreGraphics(_ joinType: JoinType) -> CGLineJoin {
        switch joinType {
        case .round: return .round
        case .miter: return .miter
        case .bevel: return .bevel
        case .square: return .miter  // Square corners with minimal miter limit
        }
    }
    
    /// Helper function to find the outside path from trim results
    private func findOutsidePath(from trimmedPaths: [CGPath], original: CGPath, offset: CGPath) -> CGPath? {
        guard !trimmedPaths.isEmpty else { return nil }
        
        // Get bounds of offset for comparison  
        let offsetBounds = offset.boundingBoxOfPath
        
        // The outside path is typically:
        // 1. The largest path by area
        // 2. The path that contains or is closest to the offset bounds
        var bestPath: CGPath?
        var bestScore: CGFloat = 0
        
        for path in trimmedPaths {
            let pathBounds = path.boundingBoxOfPath
            let pathArea = pathBounds.width * pathBounds.height
            
            // Score based on area and proximity to offset bounds
            let areaScore = pathArea
            let proximityScore = pathBounds.intersection(offsetBounds).width * pathBounds.intersection(offsetBounds).height
            let totalScore = areaScore + proximityScore * 2.0 // Weight proximity higher
            
            if totalScore > bestScore {
                bestScore = totalScore
                bestPath = path
            }
        }
        
        return bestPath ?? trimmedPaths.first
    }
} 
