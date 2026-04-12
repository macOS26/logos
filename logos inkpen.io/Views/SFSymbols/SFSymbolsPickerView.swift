import SwiftUI
import AppKit

/// Sheet-presented picker for importing a bundled SF Symbol as SVG vector
/// content. Uses the library loaded from `sf_symbols.lzfse` and routes the
/// chosen symbol through `VectorImportManager.importVectorFile` via a temp
/// file so it goes through the same SVG import path as a File → Open.
struct SFSymbolsPickerView: View {
    @Binding var isPresented: Bool
    let onImport: (URL) async -> Void

    @State private var query: String = ""
    @State private var allNames: [String] = []
    @State private var results: [String] = []
    @State private var loading: Bool = true

    private static let gridColumns = [GridItem(.adaptive(minimum: 72), spacing: 8)]
    private static let tileSize: CGFloat = 56
    private static let maxResults: Int = 300

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            Divider()
            resultsGrid
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 480)
        .task {
            await loadLibrary()
        }
    }

    private var header: some View {
        HStack {
            Text("SF Symbols")
                .font(.headline)
            Spacer()
            Button("Close") { isPresented = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding(10)
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search (e.g. heart, arrow, folder)", text: $query)
                .textFieldStyle(.plain)
                .onChange(of: query) { _, newValue in
                    results = filteredResults(for: newValue)
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = filteredResults(for: "")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }

    private var resultsGrid: some View {
        Group {
            if loading {
                VStack {
                    ProgressView()
                    Text("Loading \(SFSymbolsLibrary.shared.count) symbols…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                Text(query.isEmpty ? "Start typing to search." : "No symbols match \"\(query)\".")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Self.gridColumns, spacing: 8) {
                        ForEach(results, id: \.self) { name in
                            Button {
                                Task { await importSymbol(named: name) }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: name)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: Self.tileSize, height: Self.tileSize)
                                        .foregroundColor(.primary)
                                    Text(name)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: 80)
                                }
                                .padding(6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(name)
                        }
                    }
                    .padding(10)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("Tap a symbol to import")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
    }

    // MARK: - Data

    private func loadLibrary() async {
        let names = await Task.detached(priority: .userInitiated) {
            await SFSymbolsLibrary.shared.allNames()
        }.value
        allNames = names
        results = filteredResults(for: query)
        loading = false
    }

    private func filteredResults(for q: String) -> [String] {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty {
            /* Without a query, show the first N names so the grid isn't empty but
               also doesn't try to render 6000 tiles at once. */
            return Array(allNames.prefix(Self.maxResults))
        }
        let matches = allNames.filter { $0.lowercased().contains(trimmed) }
        return Array(matches.prefix(Self.maxResults))
    }

    // MARK: - Import

    private func importSymbol(named name: String) async {
        guard let svg = SFSymbolsLibrary.shared.svg(named: name) else {
            NSSound.beep()
            return
        }

        /* Round-trip through a temp file so the symbol goes through the same
           VectorImportManager SVG path as File → Open. */
        let tempDir = FileManager.default.temporaryDirectory
        let sanitized = name.replacingOccurrences(of: "/", with: "_")
        let tempURL = tempDir.appendingPathComponent("sfsymbol-\(sanitized)-\(UUID().uuidString.prefix(8)).svg")
        do {
            try svg.data(using: String.Encoding.utf8)?.write(to: tempURL)
            await onImport(tempURL)
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            NSSound.beep()
            try? FileManager.default.removeItem(at: tempURL)
        }

        isPresented = false
    }
}
