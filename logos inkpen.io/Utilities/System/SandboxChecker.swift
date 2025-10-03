//
//  SandboxChecker.swift
//  logos inkpen.io
//
//  Common utility for checking if the app is running in a sandbox
//

import Foundation

enum SandboxChecker {
    /// Check if the app is running in a sandbox environment
    static var isSandboxed: Bool {
        // Check for the sandbox container ID environment variable
        // This is the most reliable way to detect sandbox on macOS
        return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    /// Computed property for convenience
    static var isNotSandboxed: Bool {
        return !isSandboxed
    }
}