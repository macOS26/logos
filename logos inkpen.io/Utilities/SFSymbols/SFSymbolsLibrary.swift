import Foundation

final class SFSymbolsLibrary {
    static let shared = SFSymbolsLibrary()

    private var cache: [String: String]?
    private let loadLock = NSLock()

    private init() {}

    func svg(named name: String) -> String? {
        return ensureLoaded()?[name]
    }

    func allNames() -> [String] {
        return ensureLoaded()?.keys.sorted() ?? []
    }

    func search(prefix: String) -> [String] {
        guard let dict = ensureLoaded(), !prefix.isEmpty else { return [] }
        let lower = prefix.lowercased()
        return dict.keys.filter { $0.lowercased().hasPrefix(lower) }.sorted()
    }

    func search(contains query: String) -> [String] {
        guard let dict = ensureLoaded(), !query.isEmpty else { return [] }
        let lower = query.lowercased()
        return dict.keys.filter { $0.lowercased().contains(lower) }.sorted()
    }

    var count: Int {
        return ensureLoaded()?.count ?? 0
    }

    /// Release the decompressed SVG cache to free ~15-25MB.
    /// The cache will be reloaded on next access.
    func releaseCache() {
        loadLock.lock()
        cache = nil
        loadLock.unlock()
    }

    private func ensureLoaded() -> [String: String]? {
        loadLock.lock()
        defer { loadLock.unlock() }
        if let cache { return cache }
        guard let url = Bundle.main.url(forResource: "sf_symbols", withExtension: "lzfse") else {
            Log.error("SF Symbols: sf_symbols.lzfse not found in bundle", category: .error)
            return nil
        }
        do {
            let compressed = try Data(contentsOf: url) as NSData
            let decompressed = try compressed.decompressed(using: .lzfse) as Data
            guard let dict = try JSONSerialization.jsonObject(with: decompressed) as? [String: String] else {
                Log.error("SF Symbols: JSON decode produced wrong shape", category: .error)
                return nil
            }
            cache = dict
            return dict
        } catch {
            Log.error("SF Symbols: load failed: \(error)", category: .error)
            return nil
        }
    }
}
