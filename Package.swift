// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftletModelBenchmark",
    platforms: [.macOS(.v15), .iOS(.v18)],
    dependencies: [
        .package(url: "https://github.com/KazaiMazai/SwiftletModel.git", branch: "Write-path-performance-optimization"),
        .package(url: "https://github.com/realm/realm-swift", branch: "master"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.6.4"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.0"),
    ],
    targets: [
        // CLI that renders BenchmarkResults/results.csv as a comparison table.
        .executableTarget(name: "bench-report"),
        // Obj-C base enabling runtime-parametrized XCTest cases (the Quick trick).
        .target(
            name: "ParametrizedXCTestCase",
            linkerSettings: [.linkedFramework("XCTest")]
        ),
        .testTarget(
            name: "SwiftletModelBenchmarkTests",
            dependencies: [
                "ParametrizedXCTestCase",
                .product(name: "SwiftletModel", package: "SwiftletModel"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
