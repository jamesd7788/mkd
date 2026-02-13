// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "mkd",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "mkd",
            path: "Sources/mkd",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
