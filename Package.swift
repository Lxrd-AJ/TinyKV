// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TinyKV",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TinyKVCommon", targets: ["TinyKVCommon"]),
        .executable(name: "TinyKVClient", targets: ["TinyKVClient"]),
        .executable(name: "TinyKVServer", targets: ["TinyKVServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0")
    ],
    targets: [
        .target(
            name: "TinyKVCommon",
            dependencies: [
                .product(name: "NIO", package: "swift-nio")
            ]
        ),
        .executableTarget(
            name: "TinyKVClient",
            dependencies: [
                "TinyKVCommon",
                .product(name: "NIO", package: "swift-nio")
            ]
        ),
        .executableTarget(
            name: "TinyKVServer",
            dependencies: [
                "TinyKVCommon",
                .product(name: "NIO", package: "swift-nio")
            ]
        ),
        .testTarget(
            name: "TinyKVUnitTests",
            dependencies: ["TinyKVServer", "TinyKVCommon", "TinyKVClient"]
        ),
        .testTarget(
            name: "TinyKVIntegrationTests",
            dependencies: ["TinyKVServer", "TinyKVCommon", "TinyKVClient"]
        ),
    ]
)
