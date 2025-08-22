//
//  PathAnalysis.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//


// MARK: - Analysis Structures
struct PathAnalysis {
    var continuityIssues: [ContinuityIssue] = []
    var optimizationSuggestions: [OptimizationSuggestion] = []
    var qualityScore: Double {
        let maxScore = 100.0
        let issueDeduction = Double(continuityIssues.count) * 10.0
        let suggestionDeduction = Double(optimizationSuggestions.count) * 5.0
        return max(0, maxScore - issueDeduction - suggestionDeduction)
    }
}