// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftletModelPerformanceTestSuite",
    platforms: [.macOS(.v15), .iOS(.v18)],
    dependencies: [
        .package(url: "https://github.com/KazaiMazai/SwiftletModel.git", branch: "main"),
        .package(url: "https://github.com/realm/realm-swift", branch: "master"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.6.4"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.0"),
    ],
    targets: [
        // CLI that renders BenchmarkResults/results.csv as a comparison table.
        .executableTarget(name: "report", path: "Sources/Report"),
        // The benchmark suite — a plain executable (no XCTest): a registry of
        // cases run over each size, timed with a manual rampup loop.
        .executableTarget(
            name: "benchmarks",
            dependencies: [
                .product(name: "SwiftletModel", package: "SwiftletModel"),
                .product(name: "RealmSwift", package: "realm-swift"),
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/Benchmarks",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
