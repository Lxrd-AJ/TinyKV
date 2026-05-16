// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TinyKV",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0")
    ],
    targets: [
        .executableTarget(
            name: "TinyKV",
            dependencies: [
                .product(name: "NIO", package: "swift-nio")
            ]
        ),
        .testTarget(
            name: "TinyKVUnitTests",
            dependencies: ["TinyKV"]
        ),
        .testTarget(
            name: "TinyKVIntegrationTests",
            dependencies: ["TinyKV"]
        ),
    ]
)
