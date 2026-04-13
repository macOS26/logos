// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FH2Test",
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
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
