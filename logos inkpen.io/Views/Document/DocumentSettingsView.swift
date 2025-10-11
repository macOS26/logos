import SwiftUI

struct DocumentSettingsView: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            professionalHeader

            ScrollView {
                VStack(spacing: 24) {
                    documentSizeSection

                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 24) {
                            displaySettingsSection
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        Divider()
                            .frame(height: 100)

                        VStack(alignment: .leading, spacing: 24) {
                            colorSettingsSection
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    displayOptionsSection

                    HStack(alignment: .top, spacing: 24) {
                        layerSelectionSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        gridSpacingSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            professionalFooter
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var professionalHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Document Settings")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Configure document properties and preferences")
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
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var documentSizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ruler")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)

                Text("Document Size")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("Width", value: $document.settings.width, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 120)
                                .onChange(of: document.settings.width) {
                                    document.onSettingsChanged()
                                }

                            Text(document.settings.unit.rawValue.capitalized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Height")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("Height", value: $document.settings.height, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 120)
                                .onChange(of: document.settings.height) {
                                    document.onSettingsChanged()
                                }

                            Text(document.settings.unit.rawValue.capitalized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                        }
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Units")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Picker("Unit", selection: $document.settings.unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: document.settings.unit) { oldUnit, newUnit in
                        let convertedWidth = UnitsConverter.convert(value: document.settings.width, from: oldUnit, to: newUnit)
                        let convertedHeight = UnitsConverter.convert(value: document.settings.height, from: oldUnit, to: newUnit)
                        document.settings.width = convertedWidth
                        document.settings.height = convertedHeight

                        let convertedGridSpacing = UnitsConverter.convert(value: document.settings.gridSpacing, from: oldUnit, to: newUnit)
                        document.settings.gridSpacing = convertedGridSpacing

                        document.onSettingsChanged()
                    }
                }
            }
        }
    }

    private var colorSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paintpalette")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)

                Text("Color Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Color Mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Picker("Color Mode", selection: $document.settings.colorMode) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.uppercased()).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }

    private var displaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)

                Text("Display Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Resolution")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("Resolution", value: $document.settings.resolution, format: .number)
                        .textFieldStyle(ProfessionalTextFieldStyle())
                        .frame(width: 120)
                        .onChange(of: document.settings.resolution) {
                            document.onSettingsChanged()
                        }

                    Text("DPI")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                }
            }
        }
    }

    private var layerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected Layer")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Picker("", selection: Binding(
                    get: {
                        if let selectedId = document.settings.selectedLayerId,
                           let layer = document.layers.first(where: { $0.id == selectedId }) {
                            return layer.id
                        } else if let firstLayer = document.layers.first {
                            return firstLayer.id
                        } else {
                            return UUID()
                        }
                    },
                    set: { newLayerId in
                        if let selectedLayer = document.layers.first(where: { $0.id == newLayerId }) {
                            document.settings.selectedLayerId = selectedLayer.id
                            document.settings.selectedLayerName = selectedLayer.name
                            document.layerIndex = document.layers.firstIndex(where: { $0.id == newLayerId }) ?? 0
                            document.onSettingsChanged()
                        }
                    }
                )) {
                    ForEach(document.layers) { layer in
                        Text(layer.name).tag(layer.id)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(document.layers.isEmpty)
        }
    }

    private var displayOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)

                Text("Display Options")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 40) {
                    HStack {
                        Text("Show Rulers")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)

                        StylusToggleButton(isOn: $document.settings.showRulers) { newValue in
                            document.showRulers = newValue
                            UserDefaults.standard.set(newValue, forKey: "showRulers")
                            document.onSettingsChanged()
                        }
                    }

                    HStack {
                        Text("Snap to Point")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)

                        StylusToggleButton(isOn: $document.settings.snapToPoint) { newValue in
                            document.snapToPoint = newValue
                            UserDefaults.standard.set(newValue, forKey: "snapToPoint")
                            document.onSettingsChanged()
                        }
                    }
                }

                HStack(spacing: 40) {
                    HStack {
                        Text("Show Grid")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)

                        StylusToggleButton(isOn: $document.settings.showGrid) { newValue in
                            document.showGrid = newValue
                            UserDefaults.standard.set(newValue, forKey: "showGrid")
                            document.onSettingsChanged()
                        }
                    }

                    HStack {
                        Text("Snap to Grid")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)

                        StylusToggleButton(isOn: $document.settings.snapToGrid) { newValue in
                            document.snapToGrid = newValue
                            UserDefaults.standard.set(newValue, forKey: "snapToGrid")
                            document.onSettingsChanged()
                        }
                    }
                }
            }
        }
    }

    private var gridSpacingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Grid Spacing")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("Grid Spacing", value: $document.settings.gridSpacing, format: .number)
                    .textFieldStyle(ProfessionalTextFieldStyle())
                    .frame(width: 120)
                    .onChange(of: document.settings.gridSpacing) {
                        document.onSettingsChanged()
                    }

                Text(document.settings.unit.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
            }
        }
    }


    private var professionalFooter: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
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
        .background(Color(NSColor.controlBackgroundColor))
    }
}
