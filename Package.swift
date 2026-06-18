// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ImageHoster",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "ImageHoster", targets: ["ImageHoster"])
    ],
    targets: [
        .executableTarget(
            name: "ImageHoster",
            path: "Sources"
        )
    ]
)
