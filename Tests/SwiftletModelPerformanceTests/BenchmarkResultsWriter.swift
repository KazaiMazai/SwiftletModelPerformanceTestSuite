//
//  BenchmarkResultsWriter.swift
//  SwiftletModelPerformanceTestSuite
//
//  Collects per-iteration timings recorded by BenchmarkCase and appends one
//  summary row per test to a CSV file. The output lands in `BenchmarkResults/`
//  at the repository root (derived from `#filePath`, so no configuration is
//  needed); if that location isn't writable it falls back to the temp dir.
//
//  Two files are written, routed by test class: the flat micro-benchmarks
//  (equality/sort/insert/…) go to `results.csv`, while the relational Northwind
//  workloads go to `relational.csv`. Their `size` axes mean different things
//  (row count vs. order count) and they cover different engines, so keeping
//  them apart means running one subset never clobbers the other.
//

import Foundation

enum BenchmarkResultsWriter {

    private static let lock = NSLock()
    private static var samplesByTest: [String: [Double]] = [:]   // seconds
    private static var resolvedURLs: [String: URL] = [:]         // filename → URL

    private static let header =
        "engine,indexing,access,operation,valueType,size,samples,avg_ms,min_ms,max_ms,stddev_ms"

    /// Routes a test to its output file. Relational (Northwind) suites get their
    /// own CSV; everything else lands in the shared flat-benchmark file.
    private static func fileName(for test: String) -> String {
        test.contains("Northwind") ? "relational.csv" : "results.csv"
    }

    // MARK: - Recording

    /// Records one measured iteration (in seconds) for a test identifier.
    static func record(test: String, seconds: Double) {
        lock.lock(); defer { lock.unlock() }
        samplesByTest[test, default: []].append(seconds)
    }

    /// Computes stats for a finished test and appends a CSV row. No-op if the
    /// test recorded no samples.
    static func flush(test: String) {
        lock.lock()
        let samples = samplesByTest.removeValue(forKey: test) ?? []
        lock.unlock()

        guard !samples.isEmpty, let meta = Metadata(testName: test) else { return }

        let count = Double(samples.count)
        let avg = samples.reduce(0, +) / count
        let minV = samples.min() ?? 0
        let maxV = samples.max() ?? 0
        let variance = samples.count > 1
            ? samples.reduce(0) { $0 + ($1 - avg) * ($1 - avg) } / (count - 1)
            : 0
        let stddev = variance.squareRoot()

        func ms(_ s: Double) -> String { String(format: "%.4f", s * 1_000) }
        let row = [
            meta.engine, meta.indexing, meta.access, meta.operation, meta.valueType,
            String(meta.size), String(samples.count),
            ms(avg), ms(minV), ms(maxV), ms(stddev)
        ].joined(separator: ",")

        append(row, to: fileName(for: test))
    }

    // MARK: - File output

    private static func append(_ row: String, to fileName: String) {
        lock.lock(); defer { lock.unlock() }

        let url: URL
        if let resolved = resolvedURLs[fileName] {
            url = resolved
        } else {
            url = makeFile(fileName)
            resolvedURLs[fileName] = url
            print("📊 Benchmark results → \(url.path)")
        }

        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        handle.seekToEndOfFile()
        handle.write(Data((row + "\n").utf8))
        try? handle.close()
    }

    /// Creates a fresh results file (with header) and returns its URL,
    /// preferring the repo's `BenchmarkResults/` dir, else the temp dir.
    private static func makeFile(_ fileName: String) -> URL {
        let preferred = URL(fileURLWithPath: #filePath)        // <pkg>/Tests/SwiftletModelPerformanceTests/BenchmarkResultsWriter.swift
            .deletingLastPathComponent()                       // .../SwiftletModelPerformanceTests
            .deletingLastPathComponent()                       // .../Tests
            .deletingLastPathComponent()                       // package root
            .appendingPathComponent("BenchmarkResults/\(fileName)")

        for candidate in [preferred, URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("BenchmarkResults/\(fileName)")] {
            do {
                try FileManager.default.createDirectory(
                    at: candidate.deletingLastPathComponent(), withIntermediateDirectories: true)
                try (header + "\n").write(to: candidate, atomically: true, encoding: .utf8)
                return candidate
            } catch {
                continue
            }
        }
        return preferred
    }

    // MARK: - Test-name parsing

    /// Parses an XCTest identifier such as
    /// `-[SwiftletModelPerformanceTests.SwiftletModelIndexedReadTests test_read_equality_int_1000]`
    /// (or the bare `test_read_equality_int_1000`) into export columns.
    private struct Metadata {
        let engine, indexing, access, operation, valueType: String
        let size: Int

        init?(testName: String) {
            let cleaned = testName
                .replacingOccurrences(of: "-[", with: "")
                .replacingOccurrences(of: "]", with: "")
            let parts = cleaned.split(separator: " ")
            let className = parts.first.map { String($0).split(separator: ".").last.map(String.init) ?? String($0) } ?? ""
            let method = parts.count > 1 ? String(parts[1]) : String(parts.first ?? "")

            engine = className.hasPrefix("SwiftletModel") ? "SwiftletModel"
                : className.hasPrefix("SQLiteData") ? "SQLiteData"
                : className.hasPrefix("SwiftData") ? "SwiftData"
                : className.hasPrefix("GRDB") ? "GRDB"
                : className.hasPrefix("Realm") ? "Realm" : "Unknown"
            indexing = className.contains("Unindexed") ? "unindexed"
                : className.contains("Indexed") ? "indexed" : "default"
            access = className.contains("Write") ? "write"
                : className.contains("Read") ? "read" : "unknown"

            var comps = method.split(separator: "_").map(String.init)
            if comps.first == "test" { comps.removeFirst() }   // drop "test"
            guard comps.count >= 3, let size = Int(comps.last!) else { return nil }
            self.size = size
            // comps == [access, operation, (valueType)?, size]
            operation = comps[1]
            valueType = comps.count >= 4 ? comps[2] : "-"
        }
    }
}
