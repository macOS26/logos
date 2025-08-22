//
//  ContinuityIssue.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation

struct ContinuityIssue: Identifiable {
    var id: UUID = UUID()
    var pointIndex: Int
    var expected: ProfessionalBezierMathematics.ContinuityType
    var actual: ProfessionalBezierMathematics.ContinuityType
}
