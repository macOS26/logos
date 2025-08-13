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
        // Pressure logs can be controlled independently since they are the noisiest
        if category == .pressure {
            if AppState.shared.enablePressureLogging {
                print(message)
            }
            return
        }
        
        if AppState.shared.enableVerboseLogging {
            print(message)
        }
    }
}


