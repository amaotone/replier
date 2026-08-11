// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "repp",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ReppCore", targets: ["ReppCore"]),
        .executable(name: "Repp", targets: ["Repp"]),
    ],
    targets: [
        .target(name: "ReppCore", path: "Sources/ReppCore"),
        .executableTarget(name: "Repp", dependencies: ["ReppCore"], path: "Sources/Repp"),
        .testTarget(name: "ReppCoreTests", dependencies: ["ReppCore"], path: "Tests/ReppCoreTests"),
    ]
)
