// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "typofix",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "typofix", targets: ["typofix"])
    ],
    targets: [
        .executableTarget(
            name: "typofix",
            path: "Sources/typofix"
        )
    ]
)
