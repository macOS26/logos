//
//  File.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import CoreGraphics
import Foundation

/// Safe wrapper for Core Image operations to prevent crashes
func safeCoreImageOperation<T>(_ operation: () throws -> T) throws -> T {
    // Add timeout protection for Core Image operations
    let timeout: TimeInterval = 30.0 // 30 second timeout
    let startTime = Date()
    
    while Date().timeIntervalSince(startTime) < timeout {
        do {
            return try operation()
        } catch {
            // If it's a Core Image specific error, retry once
            if error.localizedDescription.contains("CI_") || 
               error.localizedDescription.contains("Core Image") {
                Log.fileOperation("⚠️ Core Image operation failed, retrying...", level: .info)
                Thread.sleep(forTimeInterval: 0.1) // Brief pause before retry
                continue
            }
            throw error
        }
    }
    
    throw VectorImportError.parsingError("Core Image operation timed out after \(timeout) seconds", line: nil)
}
