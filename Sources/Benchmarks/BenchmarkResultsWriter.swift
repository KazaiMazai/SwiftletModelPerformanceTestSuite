//
//  BenchmarkResultsWriter.swift
//  SwiftletModelPerformanceTestSuite
//
//  Collects per-iteration timings recorded by BenchmarkCase and appends one
//  summary row per case to a CSV file. The output lands in `BenchmarkResults/`
//  at the repository root (derived from `#filePath`, so no configuration is
//  needed); if that location isn't writable it falls back to the temp dir.
//
//  Two files are written, routed by the case's `BenchmarkKey.file`: the flat
//  micro-benchmarks go to `results.csv`, the relational Northwind workloads to
//  `relational.csv` — their `size` axes mean different things (row vs. order
//  count), so keeping them apart means one suite never clobbers the other.
//

import Foundation

enum BenchmarkResultsWriter {

    private static let lock = NSLock()
    private static var samplesByID: [String: [Double]] = [:]   // key.id → seconds
    private static var resolvedURLs: [String: URL] = [:]       // filename → URL

    private static let header =
        "engine,indexing,access,operation,valueType,size,samples,avg_ms,min_ms,max_ms,stddev_ms"

    // MARK: - Recording

    /// Records one measured iteration (in seconds) for a case.
    static func record(_ key: BenchmarkKey, seconds: Double) {
        lock.lock(); defer { lock.unlock() }
        samplesByID[key.id, default: []].append(seconds)
    }

    /// Computes stats for a finished case and appends a CSV row. No-op if the
    /// case recorded no samples.
    static func flush(_ key: BenchmarkKey) {
        lock.lock()
        let samples = samplesByID.removeValue(forKey: key.id) ?? []
        lock.unlock()

        guard !samples.isEmpty else { return }

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
            key.engine, key.indexing, key.access, key.operation, key.valueType,
            String(key.size), String(samples.count),
            ms(avg), ms(minV), ms(maxV), ms(stddev)
        ].joined(separator: ",")

        append(row, to: key.file)
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
        let preferred = URL(fileURLWithPath: #filePath)        // <pkg>/Sources/benchmarks/BenchmarkResultsWriter.swift
            .deletingLastPathComponent()                       // .../benchmarks
            .deletingLastPathComponent()                       // .../Sources
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
}
