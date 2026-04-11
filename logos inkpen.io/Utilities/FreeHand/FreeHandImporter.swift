import Foundation

enum FreeHandImportError: Error {
    case notSupported
    case parseFailed(code: Int)
    case emptyOutput
    case allocationFailed
}

enum FreeHandImporter {
    static func isSupported(data: Data) -> Bool {
        return data.withUnsafeBytes { bytes -> Bool in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return false }
            return freehand_is_supported(base, data.count) != 0
        }
    }

    static func parseToSVG(data: Data) throws -> String {
        return try data.withUnsafeBytes { bytes -> String in
            guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw FreeHandImportError.notSupported
            }
            var outPtr: UnsafeMutablePointer<CChar>? = nil
            let rc = freehand_parse_to_svg(base, data.count, &outPtr)
            guard rc == 0, let cstr = outPtr else {
                if rc == 2 { throw FreeHandImportError.notSupported }
                if rc == 4 { throw FreeHandImportError.emptyOutput }
                if rc == 5 { throw FreeHandImportError.allocationFailed }
                throw FreeHandImportError.parseFailed(code: Int(rc))
            }
            defer { freehand_free_svg(cstr) }
            return String(cString: cstr)
        }
    }

    static func parseToSVG(url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return try parseToSVG(data: data)
    }
}
