//
//  Join.swift
//  logos inkpen.io
//
//  Created by Refactoring on 2025
//

import CoreGraphics

class Join {
    var outPt1: OutPt
    var outPt2: OutPt
    var offPt: CGPoint = .zero
    
    init(op1: OutPt, op2: OutPt) {
        self.outPt1 = op1
        self.outPt2 = op2
    }
} 