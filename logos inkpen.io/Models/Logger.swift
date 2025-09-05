import Foundation
import os.log

enum LogCategory: String, CaseIterable {
    case general = "general"
    case pressure = "pressure"
    case input = "input"
    case selection = "selection"
    case zoom = "zoom"
    case metal = "metal"
    case startup = "startup"
    case shapes = "shapes"
    case fileOperations = "fileOperations"
    case performance = "performance"
    case error = "error"
    case debug = "debug"
}

enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case fault = "fault"
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
}

struct Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.logos.inkpen"
    
    // Create loggers for each category
    private static var loggers: [LogCategory: Logger] = [:]
    private static let loggersQueue = DispatchQueue(label: "com.logos.logger.queue", attributes: .concurrent)
    
    // Simple spam suppression - count occurrences and block after 3 times
    private static var messageCounters: [String: Int] = [:]
    private static let maxRepeatedMessages = 3
    private static let counterQueue = DispatchQueue(label: "com.logos.logger.counters", qos: .utility)
    
    // Font-related patterns that should always be logged
    private static let fontRelatedPatterns = [
        "FONT",
        "TYPOGRAPHY", 
        "TEXT BOX",
        "🔤",
        "FONT PANEL",
        "FONT SETTINGS",
        "FONT FAMILY"
    ]
    
    private static func logger(for category: LogCategory) -> Logger {
        // Try to read with concurrent access
        var existingLogger: Logger?
        loggersQueue.sync {
            existingLogger = loggers[category]
        }
        
        if let existing = existingLogger {
            return existing
        }
        
        // Need to create new logger - use barrier for thread-safe write
        return loggersQueue.sync(flags: .barrier) {
            // Double-check in case another thread created it
            if let existing = loggers[category] {
                return existing
            }
            
            let logger = Logger(subsystem: subsystem, category: category.rawValue)
            loggers[category] = logger
            return logger
        }
    }
    
    // Check if message should be suppressed due to spam (more than 3 occurrences and not font-related)
    private static func shouldSuppressMessage(_ message: String) -> Bool {
        // Always allow font-related messages
        let isFontRelated = fontRelatedPatterns.contains { pattern in
            message.uppercased().contains(pattern)
        }
        
        if isFontRelated {
            return false
        }
        
        // Create a simplified key for the message (remove variable data like timestamps, coordinates, UUIDs)
        let messageKey = simplifyMessageForCounting(message)
        
        // Thread-safe counter update using serial queue
        return counterQueue.sync {
            // Update counter
            let currentCount = messageCounters[messageKey, default: 0] + 1
            messageCounters[messageKey] = currentCount
            
            // Suppress if we've seen this message more than maxRepeatedMessages times
            return currentCount > maxRepeatedMessages
        }
    }
    
    // Simplify message for counting by removing variable data
    private static func simplifyMessageForCounting(_ message: String) -> String {
        var simplified = message
        
        // Remove coordinates like (123.45, 678.90)
        simplified = simplified.replacingOccurrences(of: #"\([0-9.-]+,\s*[0-9.-]+\)"#, with: "(X,Y)", options: .regularExpression)
        
        // Remove UUIDs like 82593F46 or longer UUIDs
        simplified = simplified.replacingOccurrences(of: #"[A-F0-9]{8}(-[A-F0-9]{4}){3}-[A-F0-9]{12}"#, with: "UUID", options: .regularExpression)
        simplified = simplified.replacingOccurrences(of: #"[A-F0-9]{8}"#, with: "UUID", options: .regularExpression)
        
        // Remove numbers like textID=82593F46
        simplified = simplified.replacingOccurrences(of: #"textID=[A-F0-9]+"#, with: "textID=UUID", options: .regularExpression)
        
        // Remove frame coordinates like frame: (0.0, 0.0, 1920.0, 1080.0)
        simplified = simplified.replacingOccurrences(of: #"frame:\s*\([0-9.-]+,\s*[0-9.-]+,\s*[0-9.-]+,\s*[0-9.-]+\)"#, with: "frame: (X,Y,W,H)", options: .regularExpression)
        
        // Remove position= coordinates
        simplified = simplified.replacingOccurrences(of: #"position=[0-9]+"#, with: "position=N", options: .regularExpression)
        
        // Remove length= numbers
        simplified = simplified.replacingOccurrences(of: #"length=[0-9]+"#, with: "length=N", options: .regularExpression)
        
        return simplified
    }
    
    // Main logging methods
    static func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        // Check for spam suppression
        if shouldSuppressMessage(message) {
            return
        }
        
        let logger = logger(for: category)
        logger.debug("\(message, privacy: .public)")
        #endif
    }
    
    static func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        // Check for spam suppression first
        if shouldSuppressMessage(message) {
            return
        }
        
        let logger = logger(for: category)
        logger.info("\(message, privacy: .public)")
    }
    
    static func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        // Check for spam suppression first
        if shouldSuppressMessage(message) {
            return
        }
        
        let logger = logger(for: category)
        logger.warning("\(message, privacy: .public)")
    }
    
    static func error(_ message: String, category: LogCategory = .error, file: String = #file, function: String = #function, line: Int = #line) {
        // Don't suppress errors - they're important
        let logger = logger(for: category)
        logger.error("\(message, privacy: .public)")
    }
    
    static func fault(_ message: String, category: LogCategory = .error, file: String = #file, function: String = #function, line: Int = #line) {
        // Don't suppress faults - they're critical
        let logger = logger(for: category)
        logger.fault("\(message, privacy: .public)")
    }
    
    // Convenience methods for specific categories
    static func metal(_ message: String, level: LogLevel = .info) {
        switch level {
        case .debug: info(message, category: .metal)
        case .info: info(message, category: .metal)
        case .warning: warning(message, category: .metal)
        case .error: error(message, category: .metal)
        case .fault: fault(message, category: .metal)
        }
    }
    
    static func startup(_ message: String, level: LogLevel = .info) {
        switch level {
        case .debug: info(message, category: .startup)
        case .info: info(message, category: .startup)
        case .warning: warning(message, category: .startup)
        case .error: error(message, category: .error)
        case .fault: fault(message, category: .error)
        }
    }
    
    static func fileOperation(_ message: String, level: LogLevel = .info) {
        switch level {
        case .debug: info(message, category: .fileOperations)
        case .info: info(message, category: .fileOperations)
        case .warning: warning(message, category: .fileOperations)
        case .error: error(message, category: .error)
        case .fault: fault(message, category: .error)
        }
    }
    
    static func performance(_ message: String, level: LogLevel = .info) {
        switch level {
        case .debug: info(message, category: .performance)
        case .info: info(message, category: .performance)
        case .warning: warning(message, category: .performance)
        case .error: error(message, category: .error)
        case .fault: fault(message, category: .error)
        }
    }
    
    // Legacy compatibility - these will be removed after migration
    @available(*, deprecated, message: "Use Log.info instead")
    static func debug(_ message: String, category: LogCategory = .general) {
        info(message, category: category)
    }
}


