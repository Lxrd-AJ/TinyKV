// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TinyKV",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "TinyKVEmbedded", targets: ["TinyKVEmbedded"]),
        .executable(name: "tkvc", targets: ["TinyKVClient"]),
        .executable(name: "tkvs", targets: ["TinyKVServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.33.0")
    ],
    targets: [
        .target(
            name: "TinyKVEmbedded",
            dependencies: [
                .product(name: "NIO", package: "swift-nio")
            ]
        ),
        .executableTarget(
            name: "TinyKVClient",
            dependencies: [
                "TinyKVEmbedded",
                .product(name: "NIO", package: "swift-nio")
            ]
        ),
        .executableTarget(
            name: "TinyKVServer",
            dependencies: [
                "TinyKVEmbedded",
                .product(name: "NIO", package: "swift-nio")
            ]
        ),
        .executableTarget(
            name: "TinyKVBenchmark",
            dependencies: [
                "TinyKVServer", 
                "TinyKVEmbedded", 
                "TinyKVClient",
                .product(name: "Benchmark", package: "package-benchmark")
            ],
            path: "Benchmarks/TinyKVBenchmark",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ),
        .testTarget(
            name: "TinyKVUnitTests",
            dependencies: ["TinyKVServer", "TinyKVEmbedded", "TinyKVClient"]
        ),
        .testTarget(
            name: "TinyKVIntegrationTests",
            dependencies: ["TinyKVServer", "TinyKVEmbedded", "TinyKVClient"]
        ),
    ]
)
