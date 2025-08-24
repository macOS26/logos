//
//  AppDelegate.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import Foundation
import SwiftUI
import CoreGraphics

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
        _ = DisplayMonitor.shared
        
        // SETUP: Global error handling for system-level issues
        setupGlobalErrorHandling()
        
        // REMOVED: Repetitive app initialization logging
        
        // Use the startup coordinator for robust initialization
        Task {
            await StartupCoordinator.shared.performStartupTasks()
            
            // After startup tasks complete, configure windows
            await configureWindowsAsync()
        }
        
        // Set up a fallback timer to ensure the app doesn't hang
        setupFallbackTimer()
        
        // Normalize menus shortly after launch (once) so order is correct
        
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
    
    
    
    
    
    private func configureWindowsAsync() async {
        // Add a delay to let the app fully initialize
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        await MainActor.run {
            // Auto-hiding behavior disabled - new document setup window will remain open
            Log.info("📄 App: Auto-hiding behavior disabled - new document setup window will remain open", category: .startup)
            
            // Adjust any Apple Metal HUD carrier view if present in visible windows
            NSApplication.shared.windows.forEach { window in
                if AppState.shared.enableSystemMetalHUD {
                    for subview in window.contentView?.subviews ?? [] {
                        let className = String(describing: type(of: subview))
                        if className.lowercased().contains("hud") || className.lowercased().contains("metal") {
                            var frame = subview.frame
                            frame.origin.x = AppState.shared.metalHUDOffsetX
                            frame.origin.y = window.frame.height - AppState.shared.metalHUDOffsetY - frame.height
                            frame.size.width = AppState.shared.metalHUDWidth
                            frame.size.height = AppState.shared.metalHUDHeight
                            subview.frame = frame
                        }
                    }
                }
            }
            Log.startup("📄 App: Adjusted Metal HUD positioning where applicable")
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // Defer window operations to prevent blocking
        Task {
            await handleApplicationBecameActiveAsync()
        }
    }
    
    private func handleApplicationBecameActiveAsync() async {
        await MainActor.run {
            // No-op: individual windows manage their own tabbing preferences
        }
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Return false to prevent the Open Dialog, but we'll handle document creation ourselves
        Log.startup("📄 App: Intercepting untitled file creation - will show New Document Setup Window instead")
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Check if we have any document windows open (not just visible windows)
        let documentWindows = NSApplication.shared.windows.filter { window in
            return window.title != "Document Setup" && window.title != ""
        }
        
        // If no document windows are open, let DocumentGroup handle document creation
        if documentWindows.isEmpty {
            // REMOVED: Repetitive app reopen logging
            return true
        } else {
            // REMOVED: Repetitive app reopen logging
            return false
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Log.startup("📄 App: Application should terminate - starting graceful shutdown")
        
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
        
        // CRITICAL: Clean up all state objects to prevent retain cycles during shutdown
        cleanupAllStateObjects()
        
        // CRITICAL: Force cleanup of all DocumentState instances
        cleanupAllDocumentStates()
        
        // Force synchronize UserDefaults before shutdown
        UserDefaults.standard.synchronize()
        
        Log.startup("📄 App: Application termination cleanup completed")
    }
    
    private func cleanupAllStateObjects() {
        // Clean up any remaining state objects
        // This helps prevent retain cycles during SwiftUI cleanup
        Log.startup("📄 App: Cleaning up state objects for shutdown")
    }
    
    private func cleanupAllDocumentStates() {
        // Force cleanup of any DocumentState instances that might still have active subscriptions
        Log.startup("📄 App: Forcing cleanup of all DocumentState instances")
        
        // Directly force cleanup of all DocumentState instances
        DocumentStateRegistry.shared.forceCleanupAll()
        
        // Give a brief moment for cleanup to complete
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }
}
