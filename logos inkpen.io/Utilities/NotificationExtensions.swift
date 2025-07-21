//
//  NotificationExtensions.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/5/25.
//

import Foundation

extension Notification.Name {
    // MARK: - Tool Commands
    static let switchTool = Notification.Name("SwitchTool")
    
    // MARK: - Selection Commands (REMOVED - using DocumentState methods directly)
    
    // MARK: - Object Commands - Arrange (REMOVED - using DocumentState methods directly)
    
    // MARK: - Object Commands - Lock/Hide (REMOVED - using DocumentState methods directly)
    
    // MARK: - View Commands - Zoom (REMOVED - using DocumentState methods directly)
    
    // MARK: - View Commands - View Mode (REMOVED - using DocumentState methods directly)
    
    // MARK: - View Commands - Show/Hide (REMOVED - using DocumentState methods directly)
    
    // MARK: - Text Commands (REMOVED - using DocumentState methods directly)
    
    // MARK: - Path Cleanup Commands (REMOVED - using DocumentState methods directly)
    
    // MARK: - Panel Commands (REMOVED - using AppState with @Observable instead)
    
    // MARK: - Development Commands (REMOVED - using AppState methods directly)
} 