//
//  NotificationExtensions.swift
//  logos inkpen.io
//
//  Notification utilities and extensions for app lifecycle management
//

import Foundation

// Additional notification names can be added here as needed
extension Notification.Name {
    // App lifecycle notifications
    static let appDidFinishTerminationCleanup = Notification.Name("appDidFinishTerminationCleanup")
    
    // Document lifecycle notifications  
    static let documentWillClose = Notification.Name("documentWillClose")
    static let documentDidClose = Notification.Name("documentDidClose")
    
    // StallDetector notifications
    static let stallDetectorStallDetected = Notification.Name("stallDetectorStallDetected")
    static let stallDetectorRecoveryCompleted = Notification.Name("stallDetectorRecoveryCompleted")
}