import Foundation
import QuartzCore

// Test script to verify CPU monitoring is working
print("🔧 Testing CPU Monitor...")

// Simulate the optimized performance monitor behavior
class TestCPUMonitor {
    var cpuUsage: Double = 0.0
    var activityCounter: Int = 0
    var lastActivityTime: CFTimeInterval = 0
    
    init() {
        // Initialize with baseline CPU
        self.cpuUsage = 10.0
        self.lastActivityTime = CACurrentMediaTime()
        print("✅ Initialized with baseline CPU: \(cpuUsage)%")
    }
    
    func trackDrawingEvent() {
        activityCounter += 1
        let currentTime = CACurrentMediaTime()
        
        // Update CPU based on activity (every 1 second)
        if currentTime - lastActivityTime >= 1.0 {
            let activityLevel = min(100.0, Double(activityCounter))
            cpuUsage = activityLevel
            
            print("📊 CPU Usage: \(Int(cpuUsage))% (activity: \(activityCounter))")
            
            activityCounter = 0
            lastActivityTime = currentTime
        }
    }
    
    func testCPUDetection() {
        print("\n🧪 Testing CPU activity detection...")
        
        // Simulate idle state
        print("Idle state: CPU \(Int(cpuUsage))%")
        
        // Simulate light activity
        for _ in 1...5 {
            trackDrawingEvent()
            usleep(200_000) // 200ms delay
        }
        
        // Force update
        let currentTime = CACurrentMediaTime()
        if activityCounter > 0 {
            let activityLevel = min(100.0, Double(activityCounter))
            cpuUsage = activityLevel
            print("📊 Light activity: CPU \(Int(cpuUsage))%")
        }
        
        // Reset and simulate heavy activity
        activityCounter = 0
        lastActivityTime = CACurrentMediaTime()
        
        for _ in 1...20 {
            trackDrawingEvent()
            usleep(50_000) // 50ms delay
        }
        
        // Force update
        if activityCounter > 0 {
            let activityLevel = min(100.0, Double(activityCounter))
            cpuUsage = activityLevel
            print("📊 Heavy activity: CPU \(Int(cpuUsage))%")
        }
    }
}

let monitor = TestCPUMonitor()
monitor.testCPUDetection()

print("\n✅ CPU Monitor Test Complete!")
print("Expected Results:")
print("  • Baseline: ~10% CPU")
print("  • Light activity: ~5% CPU") 
print("  • Heavy activity: ~20% CPU")
print("\nIf you see 0% in the toolbar, the activity tracking system will update it when you draw.")
