import Foundation

enum LogCategory {
    case general
    case pressure
    case input
    case selection
    case zoom
    case metal
    case startup
    case shapes
}

struct Log {
    static func debug(_ message: String, category: LogCategory = .general) {
        // Read flags directly from UserDefaults to avoid touching AppState during its initialization
        let defaults = UserDefaults.standard
        let pressureEnabled = (defaults.object(forKey: "enablePressureLogging") as? Bool) ?? false
        let verboseEnabled = (defaults.object(forKey: "enableVerboseLogging") as? Bool) ?? false

        if category == .pressure {
            if pressureEnabled { print(message) }
            return
        }

        if verboseEnabled { print(message) }
    }
}


