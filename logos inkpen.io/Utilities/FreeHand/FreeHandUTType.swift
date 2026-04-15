import UniformTypeIdentifiers

extension UTType {
    static let freehandDocument = UTType(importedAs: "io.logos.logos-inkpen-io.freehand")
    /// Encapsulated PostScript — used for FreeHand EPS exports (e.g. `torfont.fh2.eps`).
    static let encapsulatedPostScript = UTType(importedAs: "com.adobe.encapsulated-postscript")
}
