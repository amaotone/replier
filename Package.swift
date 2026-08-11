// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "replier",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ReplierCore", targets: ["ReplierCore"]),
        .executable(name: "Replier", targets: ["Replier"]),
    ],
    targets: [
        .target(name: "ReplierCore", path: "Sources/ReplierCore"),
        .executableTarget(name: "Replier", dependencies: ["ReplierCore"], path: "Sources/Replier"),
        .testTarget(name: "ReplierCoreTests", dependencies: ["ReplierCore"], path: "Tests/ReplierCoreTests"),
    ]
)
