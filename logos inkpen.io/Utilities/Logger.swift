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
    
    private static func logger(for category: LogCategory) -> Logger {
        if let existing = loggers[category] {
            return existing
        }
        
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }
    
    // Main logging methods
    static func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let logger = logger(for: category)
        logger.debug("\(message, privacy: .public)")
        #endif
    }
    
    static func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = logger(for: category)
        logger.info("\(message, privacy: .public)")
    }
    
    static func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = logger(for: category)
        logger.warning("\(message, privacy: .public)")
    }
    
    static func error(_ message: String, category: LogCategory = .error, file: String = #file, function: String = #function, line: Int = #line) {
        let logger = logger(for: category)
        logger.error("\(message, privacy: .public)")
    }
    
    static func fault(_ message: String, category: LogCategory = .error, file: String = #file, function: String = #function, line: Int = #line) {
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


