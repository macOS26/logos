// swift-tools-version: 6.3
import PackageDescription
let package = Package(
    name: "FH2Test",
    targets: [
        .executableTarget(
            name: "FH2Test"
        ),
        .testTarget(
            name: "FH2TestTests",
            dependencies: ["FH2Test"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
