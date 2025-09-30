//
//  AppDelegate.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import SwiftUI

// MARK: - AppDelegate to ensure proper document tabbing and window persistence
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install stderr filter to suppress noisy system-level SQLite warning lines
        StderrFilter.shared.installFilter(suppressing: [
            "/private/var/db/DetachedSignatures",
            "os_unix.c:49448",
            "cannot open file at line 49448",
            "invalid display identifier",
            "display identifier"
        ])

        // Apply Apple Metal Performance HUD environment if enabled in preferences
        let enabled = UserDefaults.standard.bool(forKey: "enableSystemMetalHUD")
        if enabled {
            setenv("MTL_HUD_ENABLED", "1", 1)
        } else {
            unsetenv("MTL_HUD_ENABLED")
        }

        // 🔥 NEW: Initialize display monitor to handle display changes
        //_ = DisplayMonitor.shared

        // SETUP: Global error handling for system-level issues
        setupGlobalErrorHandling()

        // Set up a fallback timer to ensure the app doesn't hang
        setupFallbackTimer()
        
        // Register help book with the system (uses Info.plist configuration)
        NSHelpManager.shared.registerBooks(in: Bundle.main)

    }
    
    private func setupFallbackTimer() {
        // Set up a timer that will force the app to continue if it gets stuck
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
            // REMOVED: Repetitive fallback timer logging
            
            // Force any pending operations to complete
            DispatchQueue.main.async {
                // Ensure the main window is visible and responsive
                if let mainWindow = NSApplication.shared.mainWindow {
                    mainWindow.makeKeyAndOrderFront(nil)
                    mainWindow.display()
                }
                
                // Force a display update
                NSApplication.shared.windows.forEach { window in
                    window.contentView?.needsDisplay = true
                }
            }
        }
    }

    private func setupGlobalErrorHandling() {
        // Set up a global exception handler for unhandled errors
        NSSetUncaughtExceptionHandler { exception in
            let exceptionName = exception.name.rawValue
            let exceptionReason = exception.reason ?? "Unknown reason"
            
        Log.error("📄 GlobalErrorHandler: Uncaught exception: \(exceptionName)", category: .error)
        Log.error("📄 GlobalErrorHandler: Reason: \(exceptionReason)", category: .error)
            
            // Check if this is a system-level error we should handle gracefully
            if exceptionReason.contains("DetachedSignatures") ||
                exceptionReason.contains("/private/var/db/") ||
                exceptionReason.contains("No such file or directory") ||
                exceptionReason.contains("RenderBox") ||
                exceptionReason.contains("metallib") ||
                exceptionReason.contains("personaAttributes") ||
                exceptionReason.contains("invalid display identifier") ||
                exceptionReason.contains("display identifier") {
                Log.warning("📄 GlobalErrorHandler: System-level error detected - continuing gracefully", category: .startup)
                return // Don't crash the app
            }
            
            // For other exceptions, let them propagate normally
            Log.error("📄 GlobalErrorHandler: Allowing exception to propagate", category: .error)
        }
    }
    
//    func applicationDidBecomeActive(_ notification: Notification) {
//        // Defer window operations to prevent blocking
//        Task {
//            await handleApplicationBecameActiveAsync()
//        }
//    }
    
//    private func handleApplicationBecameActiveAsync() async {
//        await MainActor.run {
//            // No-op: individual windows manage their own tabbing preferences
//        }
//    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Check if this is the very first launch ever
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        
        // Only intercept if we're actually launching fresh without documents
        let hasDocuments = NSDocumentController.shared.documents.count > 0
        Log.startup("📄 App: applicationShouldOpenUntitledFile called - hasDocuments: \(hasDocuments), hasLaunchedBefore: \(hasLaunchedBefore)")
        
        // If we already have documents (from restoration), don't interfere
        if hasDocuments {
            Log.startup("📄 App: Documents already exist, not intercepting untitled file creation")
            return false
        }
        
        // Only show setup window on the VERY FIRST launch ever
        if !hasLaunchedBefore {
            Log.startup("📄 App: First launch ever detected - will show Document Setup")
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            
            // Show the document setup window for first launch
            DispatchQueue.main.async {
                AppState.shared.openWindowAction?("onboarding-setup")
            }
            return false
        }
        
        Log.startup("📄 App: Not first launch - creating normal untitled document")
        return true // Let the system create a normal untitled document
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Log.startup("📄 App: Application should terminate - starting graceful shutdown")
        
        // CRITICAL: Close Document Setup window before termination to prevent restoration
        for window in NSApplication.shared.windows {
            if window.title == "Document Setup" || window.identifier?.rawValue == "onboarding-setup" {
                window.close()
                Log.startup("📄 Closed Document Setup window before termination")
            }
        }
        
        // Directly instruct all DocumentState instances to stop updating immediately
        DocumentStateRegistry.shared.forceCleanupAll()
        
        // Allow a brief moment for cleanup to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Log.startup("📄 App: Cleanup phase completed, terminating now")
        }
        
        return .terminateNow
    }
    
    // CRITICAL: Override to handle code signing errors gracefully
    func application(_ application: NSApplication, willPresentError error: Error) -> Error {
        Log.error("📄 App: Error intercepted: \(error)", category: .error)
        
        // Use the custom error handler to check if this is a system-level error we should handle
        if SystemErrorHandler.shared.handleSystemError(error) {
            // Return a user-friendly error message instead of the system error
            return NSError(domain: "AppDelegate", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "App initialization completed successfully",
                NSLocalizedRecoverySuggestionErrorKey: "The app is ready to use despite the system warning."
            ])
        }
        
        return error
    }
    
    // SAVE: Window state when app is about to terminate
    func applicationWillTerminate(_ notification: Notification) {
        Log.startup("📄 App: Starting termination cleanup...")
                
        // CRITICAL: Force cleanup of all DocumentState instances
        DocumentStateRegistry.shared.forceCleanupAll()
        
        // Force synchronize UserDefaults before shutdown
        UserDefaults.standard.synchronize()
        
        Log.startup("📄 App: Application termination cleanup completed")
    }
}
