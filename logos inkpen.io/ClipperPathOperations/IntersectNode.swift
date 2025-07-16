//
//  IntersectNode.swift
//  logos inkpen.io
//
//  Created by Refactoring on 2025
//

import CoreGraphics

class IntersectNode {
    var edge1: TEdge
    var edge2: TEdge
    var pt: CGPoint = .zero
    
    init(edge1: TEdge, edge2: TEdge) {
        self.edge1 = edge1
        self.edge2 = edge2
    }
} 