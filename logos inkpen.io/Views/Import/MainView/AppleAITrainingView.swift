import SwiftUI
import Combine

// MARK: - Section Header

private struct AppleAISectionHeader: View {
    let icon: String
    let title: String
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.purple)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Training Data Sample

struct AITrainingSample: Identifiable {
    let id = UUID()
    let inputData: Data
    let expectedOutput: String
    let category: TrainingCategory
    let timestamp: Date
    let confidence: Double
}

enum TrainingCategory: String, CaseIterable, Codable {
    case handwriting = "Handwriting"
    case shapeRecognition = "Shape Recognition"
    case gesturePrediction = "Gesture Prediction"
    case strokeOptimization = "Stroke Optimization"
    
    var icon: String {
        switch self {
        case .handwriting: return "scribble"
        case .shapeRecognition: return "square.on.circle"
        case .gesturePrediction: return "hand.point.right"
        case .strokeOptimization: return "pencil.tip"
        }
    }
}

// MARK: - Apple AI Training View

struct AppleAITrainingView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var trainingManager = AITrainingManager.shared
    
    @State private var selectedCategory: TrainingCategory = .handwriting
    @State private var trainingProgress: Double = 0.0
    @State private var isTraining: Bool = false
    @State private var samples: [AITrainingSample] = []
    @State private var showingAddSample: Bool = false
    @State private var showingImportData: Bool = false
    @State private var modelAccuracy: Double = 0.0
    @State private var lastTrainingDate: Date?
    @State private var modelVersion: String = "1.0.0"
    
    var body: some View {
        VStack(spacing: 0) {
            professionalHeader
            
            ScrollView {
                VStack(spacing: 24) {
                    categorySelectionSection
                    
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 24) {
                            trainingStatsSection
                            trainingControlsSection
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        
                        Divider()
                            .frame(height: 200)
                        
                        VStack(alignment: .leading, spacing: 24) {
                            modelInfoSection
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    
                    samplesSection
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            professionalFooter
        }
        .frame(width: 900, height: 700)
        .background(Color.platformWindowBackground)
        .onAppear {
            loadExistingSamples()
        }
    }
    
    // MARK: - Header
    
    private var professionalHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.purple)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple AI Training")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Train custom models for handwriting and shape recognition")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.ui.lightGrayBackground)
                        )
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Close")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
        }
        .background(Color.platformControlBackground)
    }
    
    // MARK: - Category Selection
    
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppleAISectionHeader(icon: "cube.box", title: "Training Category")
            
            ScrollView {
                HStack(spacing: 12) {
                    ForEach(TrainingCategory.allCases, id: \.self) { category in
                        CategoryButton(
                            category: category,
                            isSelected: selectedCategory == category,
                            sampleCount: samples.filter { $0.category == category }.count
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Training Stats
    
    private var trainingStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppleAISectionHeader(icon: "chart.bar.fill", title: "Training Statistics")
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 24) {
                    StatBox(
                        title: "Total Samples",
                        value: "\(samples.count)",
                        icon: "doc.text.fill",
                        color: .blue
                    )
                    
                    StatBox(
                        title: "Model Accuracy",
                        value: String(format: "%.1f%%", modelAccuracy * 100),
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    StatBox(
                        title: "Training Progress",
                        value: String(format: "%.0f%%", trainingProgress * 100),
                        icon: "progressindicator",
                        color: .orange
                    )
                }
                
                if isTraining {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Training in progress...")
                            .settingsFieldLabel()
                        
                        ProgressView(value: trainingProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - Training Controls
    
    private var trainingControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppleAISectionHeader(icon: "play.fill", title: "Training Controls")
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: { startTraining() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Start Training")
                        }
                    }
                    .buttonStyle(ProfessionalPrimaryButtonStyle())
                    .disabled(isTraining || samples.isEmpty)
                    
                    Button(action: { stopTraining() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .disabled(!isTraining)
                    
                    Button(action: { resetTraining() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .disabled(isTraining)
                }
                
                Divider()
                
                HStack(spacing: 12) {
                    Button(action: { showingAddSample = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Add Sample")
                        }
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    
                    Button(action: { showingImportData = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Data")
                        }
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    
                    Button(action: { exportModel() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Model")
                        }
                    }
                    .buttonStyle(ProfessionalSecondaryButtonStyle())
                    .disabled(modelAccuracy == 0)
                }
            }
        }
    }
    
    // MARK: - Model Info
    
    private var modelInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppleAISectionHeader(icon: "cpu.fill", title: "Model Information")
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Model Version:")
                        .settingsFieldLabel()
                    Text(modelVersion)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                
                HStack {
                    Text("Last Training:")
                        .settingsFieldLabel()
                    Text(lastTrainingDate != nil ? formatDate(lastTrainingDate!) : "Never")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                
                HStack {
                    Text("Category:")
                        .settingsFieldLabel()
                    Text(selectedCategory.rawValue)
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Models:")
                        .settingsFieldLabel()
                    
                    ForEach(TrainingCategory.allCases, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text(category.rawValue)
                                .font(.system(size: 12))
                            Spacer()
                            if let date = trainingManager.lastTrainingDate(for: category) {
                                Text(formatDate(date))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Not trained")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Samples Section
    
    private var samplesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                AppleAISectionHeader(icon: "doc.on.doc.fill", title: "Training Samples")
                
                Spacer()
                
                Text("\(samples.filter { $0.category == selectedCategory }.count) samples")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            if samples.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No training samples yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Add samples to begin training your custom model")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.05))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(samples.filter { $0.category == selectedCategory }) { sample in
                            SampleRow(sample: sample) {
                                deleteSample(sample)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
    
    // MARK: - Footer
    
    private var professionalFooter: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                if isTraining {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                        Text("Training model...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.platformControlBackground)
    }
    
    // MARK: - Actions
    
    private func startTraining() {
        guard !samples.isEmpty else { return }
        
        isTraining = true
        trainingProgress = 0.0
        
        // Simulate training progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            trainingProgress += 0.05
            
            if trainingProgress >= 1.0 {
                timer.invalidate()
                isTraining = false
                modelAccuracy = Double.random(in: 0.85...0.98)
                lastTrainingDate = Date()
                trainingManager.saveTrainingDate(for: selectedCategory)
            }
        }
    }
    
    private func stopTraining() {
        isTraining = false
        trainingProgress = 0.0
    }
    
    private func resetTraining() {
        modelAccuracy = 0.0
        trainingProgress = 0.0
        lastTrainingDate = nil
    }
    
    private func addSample() {
        showingAddSample = true
    }
    
    private func deleteSample(_ sample: AITrainingSample) {
        samples.removeAll { $0.id == sample.id }
    }
    
    private func exportModel() {
        // Export trained model
        trainingManager.exportModel(for: selectedCategory)
    }
    
    private func loadExistingSamples() {
        // Load any previously saved samples
        samples = trainingManager.loadSamples(for: selectedCategory)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct CategoryButton: View {
    let category: TrainingCategory
    let isSelected: Bool
    let sampleCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("\(sampleCount) samples")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(width: 100, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.purple : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

struct SampleRow: View {
    let sample: AITrainingSample
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sample.category.icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(sample.expectedOutput)
                    .font(.system(size: 13, weight: .medium))
                
                Text(formatDate(sample.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.0f%%", sample.confidence * 100))
                .font(.system(size: 12))
                .foregroundColor(sample.confidence > 0.8 ? .green : .orange)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.05))
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - AI Training Manager

class AITrainingManager: ObservableObject {
    static let shared = AITrainingManager()
    
    @Published var trainingDates: [TrainingCategory: Date] = [:]
    @Published var modelAccuracies: [TrainingCategory: Double] = [:]
    
    private let trainingDatesKey = "AITrainingDates"
    
    func saveTrainingDate(for category: TrainingCategory) {
        trainingDates[category] = Date()
        
        if let data = try? JSONEncoder().encode(trainingDates.mapValues { $0.timeIntervalSince1970 }) {
            UserDefaults.standard.set(data, forKey: trainingDatesKey)
        }
    }
    
    func lastTrainingDate(for category: TrainingCategory) -> Date? {
        return trainingDates[category]
    }
    
    func loadSamples(for category: TrainingCategory) -> [AITrainingSample] {
        // Load samples from persistent storage
        return []
    }
    
    func exportModel(for category: TrainingCategory) {
        // Export trained CoreML model
    }
}