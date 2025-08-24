//
//  StartupCoordinator.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Startup Coordinator for Graceful Initialization
class StartupCoordinator {
    static let shared = StartupCoordinator()
    
    private init() {}
    
    func performStartupTasks() async {
        Log.startup("📄 StartupCoordinator: Beginning startup sequence")
        
        // Set up system call monitoring
        SystemCallInterceptor.shared.setupSystemCallMonitoring()
        
        // Add timeout to prevent hanging
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds timeout
            Log.warning("📄 StartupCoordinator: Warning - startup sequence taking longer than expected", category: .startup)
        }
        
        // Perform startup tasks with error handling
        await withTaskGroup(of: Void.self) { group in
            // Task 1: Configure window tabbing
            group.addTask {
                await self.configureWindowTabbing()
            }
            
            // Task 2: Check file system access
            group.addTask {
                await self.checkFileSystemAccessAsync()
            }
            
            // Task 3: Initialize document controller
            group.addTask {
                await self.initializeDocumentController()
            }
        }
        
        // Cancel timeout task since we completed successfully
        timeoutTask.cancel()
        
        // Test error handling in development
#if DEBUG
        testErrorHandling()
#endif
        
        Log.startup("📄 StartupCoordinator: Startup sequence completed")
    }
    
    private func configureWindowTabbing() async {
        await MainActor.run {
            // Enable automatic tabbing for document windows; utility windows opt-out individually
            NSWindow.allowsAutomaticWindowTabbing = true
            UserDefaults.standard.set("always", forKey: "AppleWindowTabbingMode")
            Log.startup("📄 StartupCoordinator: Window tabbing set to always; document windows will tab, utilities opt-out")
        }
    }
    
    private func checkFileSystemAccessAsync() async {
        // Run file system checks in background
        await Task.detached(priority: .background) {
            let fileManager = FileManager.default
            
            let directoriesToCheck = [
                fileManager.temporaryDirectory,
                fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ].compactMap { $0 }
            
            for directory in directoriesToCheck {
                do {
                    _ = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                    Log.startup("📄 StartupCoordinator: File system access verified for \(directory.lastPathComponent)")
                } catch {
                                          Log.warning("📄 StartupCoordinator: File system warning for \(directory.lastPathComponent): \(error.localizedDescription)", category: .startup)
                }
            }
        }.value
    }
    
    private func initializeDocumentController() async {
        await MainActor.run {
            let documentController = NSDocumentController.shared
            documentController.autosavingDelay = 30.0
            UserDefaults.standard.set(true, forKey: "NSQuitAlwaysKeepsWindows")
            Log.startup("📄 StartupCoordinator: Document controller initialized")
        }
    }
    
    // Test method to verify error handling
    func testErrorHandling() {
        Log.startup("📄 StartupCoordinator: Testing error handling...")
        
        // Simulate the DetachedSignatures error
        let testError = NSError(domain: "TestDomain", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "cannot open file at line 49448 of [1b37c146ee] os_unix.c:49448: (2) open(/private/var/db/DetachedSignatures) - No such file or directory"
        ])
        
        let wasHandled = SystemErrorHandler.shared.handleSystemError(testError)
        Log.startup("📄 StartupCoordinator: Test error was handled: \(wasHandled)")
    }
}
