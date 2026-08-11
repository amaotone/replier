// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "replier",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ReplierCore", targets: ["ReplierCore"]),
        .executable(name: "Replier", targets: ["Replier"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(name: "ReplierCore", path: "Sources/ReplierCore"),
        .executableTarget(
            name: "Replier",
            dependencies: [
                "ReplierCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/Replier"
        ),
        .testTarget(name: "ReplierCoreTests", dependencies: ["ReplierCore"], path: "Tests/ReplierCoreTests"),
    ]
)
