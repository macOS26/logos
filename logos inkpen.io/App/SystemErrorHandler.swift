//
//  SystemErrorHandler.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import SwiftUI

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
            
            return true // Error handled
        }
        
        // Check for RenderBox framework errors
        if errorDescription.contains("renderbox") ||
            errorDescription.contains("metallib") ||
            errorDescription.contains("mach-o") {
            return true // Error handled
        }
        
        // Check for persona attributes errors
        if errorDescription.contains("personaattributes") ||
            errorDescription.contains("persona type") ||
            errorDescription.contains("operation not permitted") {
            return true // Error handled
        }
        
        // Check for other common system-level errors that shouldn't block the app
        if errorDomain == "NSCocoaErrorDomain" &&
            (errorDescription.contains("file system") || errorDescription.contains("permission")) {
            return true // Error handled
        }
        
        // Check for NSPOSIXErrorDomain errors with specific codes
        if errorDomain == "NSPOSIXErrorDomain" &&
            (errorCode == 1 || errorCode == 2) { // Operation not permitted, No such file or directory
            return true // Error handled
        }
        
        return false // Error not handled, let it propagate
    }
}
