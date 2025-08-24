//
//  SystemCallInterceptor.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - System Call Interceptor
class SystemCallInterceptor {
    static let shared = SystemCallInterceptor()
    
    private init() {}
    
    // Method to set up system call monitoring
    func setupSystemCallMonitoring() {
        // Set up a background task to monitor for system call issues
        Task.detached(priority: .background) {
            await self.monitorSystemCalls()
        }
    }
    
    private func monitorSystemCalls() async {
        // Monitor for common system call patterns that might cause blocking
        while true {
            // Check if the main thread is blocked
            let isMainThreadBlocked = await checkMainThreadStatus()
            
            if isMainThreadBlocked {
                Log.warning("📄 SystemCallInterceptor: Detected potential main thread blocking - attempting recovery", category: .startup)
                await attemptRecovery()
            }
            
            // Wait before next check
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
    }
    
    private func checkMainThreadStatus() async -> Bool {
        // Simple check to see if main thread is responsive
        let startTime = Date()
        
        await MainActor.run {
            // Just a simple operation to check responsiveness
            _ = NSApplication.shared.windows.count
        }
        
        let responseTime = Date().timeIntervalSince(startTime)
        return responseTime > 1.0 // If it takes more than 1 second, consider it blocked
    }
    
    private func attemptRecovery() async {
        await MainActor.run {
            // Force any pending operations to complete
            NSApplication.shared.windows.forEach { window in
                window.contentView?.needsDisplay = true
            }
            
            // Force a display update
            NSApplication.shared.mainWindow?.display()
        }
    }
}
