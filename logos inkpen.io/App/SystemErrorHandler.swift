//
//  SystemErrorHandler.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Custom Error Handler for System-Level Issues
class SystemErrorHandler {
    static let shared = SystemErrorHandler()
    
    private init() {}
    
    func handleSystemError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        let errorDomain = (error as NSError).domain
        let errorCode = (error as NSError).code
        
        // Check for DetachedSignatures and other system directory access errors
        if errorDescription.contains("detachedsignatures") ||
            errorDescription.contains("/private/var/db/") ||
            errorDescription.contains("no such file or directory") {
            
                    Log.warning("📄 SystemErrorHandler: Detected system directory access error - \(errorDescription)", category: .startup)
        Log.warning("📄 SystemErrorHandler: This is likely a code signing verification issue in development", category: .startup)
        Log.warning("📄 SystemErrorHandler: Continuing app initialization gracefully", category: .startup)
            return true // Error handled
        }
        
        // Check for RenderBox framework errors
        if errorDescription.contains("renderbox") ||
            errorDescription.contains("metallib") ||
            errorDescription.contains("mach-o") {
                    Log.warning("📄 SystemErrorHandler: Detected RenderBox/Metal framework error - \(errorDescription)", category: .startup)
        Log.warning("📄 SystemErrorHandler: This is a system framework loading issue - continuing gracefully", category: .startup)
            return true // Error handled
        }
        
        // Check for persona attributes errors
        if errorDescription.contains("personaattributes") ||
            errorDescription.contains("persona type") ||
            errorDescription.contains("operation not permitted") {
                    Log.warning("📄 SystemErrorHandler: Detected persona attributes error - \(errorDescription)", category: .startup)
        Log.warning("📄 SystemErrorHandler: This is a system permission issue - continuing gracefully", category: .startup)
            return true // Error handled
        }
        
        // Check for other common system-level errors that shouldn't block the app
        if errorDomain == "NSCocoaErrorDomain" &&
            (errorDescription.contains("file system") || errorDescription.contains("permission")) {
            Log.warning("📄 SystemErrorHandler: Detected file system permission error - continuing gracefully", category: .startup)
            return true // Error handled
        }
        
        // Check for NSPOSIXErrorDomain errors with specific codes
        if errorDomain == "NSPOSIXErrorDomain" &&
            (errorCode == 1 || errorCode == 2) { // Operation not permitted, No such file or directory
            Log.warning("📄 SystemErrorHandler: Detected POSIX error (code \(errorCode)) - continuing gracefully", category: .startup)
            return true // Error handled
        }
        
        return false // Error not handled, let it propagate
    }
    
    // Method to suppress specific error types globally
    func shouldSuppressError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        
        // List of error patterns that should be suppressed
        let suppressPatterns = [
            "detachedsignatures",
            "/private/var/db/",
            "no such file or directory",
            "renderbox",
            "metallib",
            "mach-o",
            "personaattributes",
            "persona type",
            "operation not permitted"
        ]
        
        return suppressPatterns.contains { pattern in
            errorDescription.contains(pattern)
        }
    }
}
